"""Upload validation — content-based, not trusting the client-supplied
`Content-Type` header alone (Phase 2 mandate, Mandate #6).

Sniffs magic bytes directly rather than depending on `python-magic`, which
needs the system `libmagic` library installed — an extra OS-level
dependency this app's CI/deploy targets shouldn't need to carry for an
an allow-list this small (images + PDF).
"""
from dataclasses import dataclass

from django.conf import settings
from django.core.files.uploadedfile import UploadedFile


class UploadValidationError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


@dataclass(frozen=True)
class _AllowedType:
    content_type: str
    magic_bytes: bytes


# Images + PDF only, per Phase 2 mandate §J. Extend this list (and only
# this list) to allow more types later.
_ALLOWED_TYPES = [
    _AllowedType("application/pdf", b"%PDF"),
    _AllowedType("image/jpeg", b"\xff\xd8\xff"),
    _AllowedType("image/png", b"\x89PNG\r\n\x1a\n"),
]


def sniff_content_type(uploaded_file: UploadedFile) -> str:
    """Returns the sniffed content type, or raises UploadValidationError if
    the file's actual bytes don't match any allowed type — regardless of
    what `uploaded_file.content_type` (client-supplied, unverified) claims.
    """
    uploaded_file.seek(0)
    header = uploaded_file.read(16)
    uploaded_file.seek(0)

    for allowed in _ALLOWED_TYPES:
        if header.startswith(allowed.magic_bytes):
            return allowed.content_type

    raise UploadValidationError(
        "unsupported_file_type",
        "This file type isn't supported. Allowed: PDF, JPEG, PNG.",
    )


def validate_size(uploaded_file: UploadedFile) -> None:
    max_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    if uploaded_file.size > max_bytes:
        raise UploadValidationError(
            "file_too_large",
            f"File exceeds the {settings.MAX_UPLOAD_SIZE_MB}MB limit.",
        )
