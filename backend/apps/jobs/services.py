"""Small explicit lifecycle; callers hold a job row lock within atomic()."""

import logging
import warnings
from datetime import datetime
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework.exceptions import APIException, ValidationError

from apps.documents.services.validation import UploadValidationError, sniff_content_type, validate_size
from apps.jobs.models import Job, JobStatusTransition

logger = logging.getLogger(__name__)
TRANSITIONS = {
    "created": {"assigned"},
    "assigned": {"in_progress", "submitted", "reassigned"},
    "in_progress": {"submitted", "reassigned"},
    "submitted": {"approved", "rejected"},
    "rejected": {"in_progress", "submitted", "reassigned"},
    "reassigned": {"assigned"},
    "approved": set(),
}


class Conflict(APIException):
    status_code = 409
    default_code = "invalid_transition"
    default_detail = (
        "This job changed or the action is not allowed in its current state. Refresh and try again."
    )


class StorageUnavailable(APIException):
    status_code = 503
    default_code = "storage_unavailable"
    default_detail = "Could not store or retrieve evidence. Please try again."


def validate_transition(source, target, reason=""):
    if target not in TRANSITIONS.get(source, set()):
        raise Conflict()
    if target == Job.Status.REJECTED and not reason.strip():
        raise ValidationError({"reason": "A rejection reason is required."})


def transition(job, target, actor, reason="", *, from_assignee=None):
    validate_transition(job.status, target, reason)
    previous = job.status
    JobStatusTransition.objects.create(
        job=job,
        assignment_revision=job.assignment_revision,
        from_status=previous,
        to_status=target,
        actor=actor,
        reason=reason,
        from_assignee=from_assignee or job.assigned_to,
        to_assignee=job.assigned_to,
    )
    job.status = target
    if target in (Job.Status.IN_PROGRESS, Job.Status.SUBMITTED) and job.work_started_at is None:
        job.work_started_at = timezone.now()
    job.save()
    logger.info("job_transition", extra={"job_id": str(job.id), "from_status": previous, "to_status": target})


def prepare_photo(upload):
    """Validate real image data, extract optional time, strip all EXIF/GPS."""
    try:
        validate_size(upload)
        content_type = sniff_content_type(upload)
    except UploadValidationError as exc:
        raise ValidationError(exc.message) from exc
    if content_type not in ("image/jpeg", "image/png"):
        raise ValidationError("Evidence must be a JPEG or PNG photo.")
    captured_at = None
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            upload.seek(0)
            with Image.open(upload) as image:
                if image.width * image.height > 25_000_000:
                    raise ValidationError("Photo exceeds the 25 megapixel limit.")
                image.load()
                try:
                    exif = image.getexif()
                    metadata = dict(exif)
                    if 34665 in exif:
                        metadata.update(exif.get_ifd(34665))
                    stamp, offset = metadata.get(36867), metadata.get(36881)
                    if stamp and offset:
                        captured_at = datetime.strptime(f"{stamp}{offset}", "%Y:%m:%d %H:%M:%S%z")
                except (ValueError, TypeError, KeyError, OSError, AttributeError):
                    pass  # Optional metadata never gates valid evidence.
                try:
                    oriented = ImageOps.exif_transpose(image)
                except (ValueError, TypeError, KeyError, OSError):
                    oriented = image.copy()
                # New image drops info dictionaries, EXIF GPS, comments and XMP.
                pixels = oriented.convert("RGB")
                clean = Image.new("RGB", pixels.size)
                clean.paste(pixels)
                output = BytesIO()
                clean.save(output, format="JPEG", quality=90)
    except (
        UnidentifiedImageError,
        OSError,
        ValueError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as exc:
        raise ValidationError("The photo cannot be decoded safely. Capture another photo.") from exc
    sanitized = SimpleUploadedFile("evidence.jpg", output.getvalue(), content_type="image/jpeg")
    try:
        validate_size(sanitized)
    except UploadValidationError as exc:
        raise ValidationError(exc.message) from exc
    return sanitized, captured_at
