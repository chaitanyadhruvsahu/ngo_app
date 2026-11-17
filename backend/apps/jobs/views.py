import logging

from django.conf import settings
from django.db import transaction
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.block_filters import filter_block
from apps.accounts.models import User
from apps.accounts.permissions import IsAdmin, IsFellow
from apps.documents.services import storage
from apps.jobs.models import Job, JobAccessLog, JobStatusTransition, JobSubmission, JobSubmissionPhoto
from apps.jobs.serializers import (
    AdminJobDetailSerializer,
    AdminJobListSerializer,
    FellowJobDetailSerializer,
    FellowJobListSerializer,
    JobEditSerializer,
    JobInputSerializer,
    ReassignSerializer,
    ReviewSerializer,
    SubmissionInputSerializer,
)
from apps.jobs.services import Conflict, StorageUnavailable, prepare_photo, transition, validate_transition

logger = logging.getLogger(__name__)


def visible_job(request, pk, *, lock=False):
    rows = Job.objects.all()
    if request.user.role != User.Role.ADMIN:
        rows = rows.filter(assigned_to__user=request.user)
    if lock:
        rows = rows.select_for_update()
    return get_object_or_404(rows, pk=pk)


def detail(request, job, status=200):
    is_admin = request.user.role == User.Role.ADMIN
    serializer = AdminJobDetailSerializer if is_admin else FellowJobDetailSerializer
    rows = job.submissions.all()
    if not is_admin:
        rows = rows.filter(assignment_revision=job.assignment_revision)
    if rows.filter(geotag_lat__isnull=False).exists():
        JobAccessLog.objects.create(job=job, accessed_by=request.user, action="location_read")
    response = Response(serializer(job).data, status=status)
    response["Cache-Control"] = "private, no-store"
    return response


class JobPagination(PageNumberPagination):
    page_size = 25
    page_size_query_param = "page_size"
    max_page_size = 100


def list_response(request, *, mine=False):
    rows = Job.objects.select_related("assigned_to")
    if not mine:
        rows = filter_block(rows, request, "assigned_to__block")
    if mine:
        rows = rows.filter(assigned_to__user=request.user)
    elif request.query_params.get("fellow"):
        fellow_id = serializers.UUIDField().run_validation(request.query_params["fellow"])
        rows = rows.filter(assigned_to_id=fellow_id)
    if request.query_params.get("status"):
        state = serializers.ChoiceField(choices=Job.Status.values).run_validation(
            request.query_params["status"]
        )
        rows = rows.filter(status=state)
    paginator = JobPagination()
    page = paginator.paginate_queryset(rows, request)
    serializer = FellowJobListSerializer if mine else AdminJobListSerializer
    response = paginator.get_paginated_response(serializer(page, many=True).data)
    response["Cache-Control"] = "private, no-store"
    return response


class JobConfigView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            {"geotag_enabled": settings.JOB_GEOTAG_ENABLED, "max_photos": settings.JOB_MAX_PHOTOS}
        )


class JobListCreateView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        return list_response(request)

    @transaction.atomic
    def post(self, request):
        serializer = JobInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        job = Job.objects.create(created_by=request.user, **serializer.validated_data)
        JobStatusTransition.objects.create(
            job=job,
            assignment_revision=1,
            from_status=None,
            to_status=Job.Status.CREATED,
            actor=request.user,
            to_assignee=job.assigned_to,
        )
        transition(job, Job.Status.ASSIGNED, request.user)
        return detail(request, job, status=201)


class MyJobsView(APIView):
    permission_classes = [IsFellow]

    def get(self, request):
        return list_response(request, mine=True)


class JobDetailView(APIView):
    def get_permissions(self):
        return [IsAdmin()] if self.request.method == "PATCH" else [IsAuthenticated()]

    @transaction.atomic
    def get(self, request, pk):
        return detail(request, visible_job(request, pk, lock=True))

    @transaction.atomic
    def patch(self, request, pk):
        job = visible_job(request, pk, lock=True)
        serializer = JobEditSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        changes = serializer.validated_data
        if not job.can_edit and set(changes) - {"internal_note"}:
            raise Conflict("Job content is locked once work starts; internal notes may still be updated.")
        for key, value in changes.items():
            setattr(job, key, value)
        job.save()
        return detail(request, job)


class JobStartView(APIView):
    permission_classes = [IsFellow]

    @transaction.atomic
    def post(self, request, pk):
        job = visible_job(request, pk, lock=True)
        transition(job, Job.Status.IN_PROGRESS, request.user)
        return detail(request, job)


class JobSubmissionView(APIView):
    permission_classes = [IsFellow]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        # Scope before validating files, so another fellow gets no existence signal.
        visible_job(request, pk)
        serializer = SubmissionInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        photos = request.FILES.getlist("photos")
        if not 1 <= len(photos) <= settings.JOB_MAX_PHOTOS:
            raise serializers.ValidationError(f"Attach between 1 and {settings.JOB_MAX_PHOTOS} photos.")
        prepared = [prepare_photo(photo) for photo in photos]
        written_keys = []
        try:
            with transaction.atomic():
                job = visible_job(request, pk, lock=True)
                validate_transition(job.status, Job.Status.SUBMITTED)
                submission = JobSubmission.objects.create(
                    job=job,
                    submitted_by=request.user,
                    assignment_revision=job.assignment_revision,
                    **serializer.validated_data,
                )
                for upload, captured_at in prepared:
                    key = storage.build_storage_key(
                        job.assigned_to_id, f"jobs/{job.id}/{submission.id}", "photo.jpg"
                    )
                    checksum = storage.write_document(key, upload)
                    # Only successful writes belong to this request. Storage backends
                    # use atomic object writes; adding the key beforehand could delete
                    # a pre-existing object if an astronomically unlikely key collision
                    # caused the conditional write to fail.
                    written_keys.append(key)
                    JobSubmissionPhoto.objects.create(
                        submission=submission,
                        storage_key=key,
                        checksum_sha256=checksum,
                        content_type="image/jpeg",
                        size_bytes=upload.size,
                        exif_captured_at=captured_at,
                    )
                transition(job, Job.Status.SUBMITTED, request.user)
                response = detail(request, job, status=201)
            return response
        except Exception as exc:
            for key in written_keys:
                try:
                    storage.delete_document(key)
                except OSError:
                    logger.exception("job_evidence_cleanup_failed", extra={"storage_key": key})
            if isinstance(exc, OSError):
                raise StorageUnavailable() from exc
            raise


class JobReviewView(APIView):
    permission_classes = [IsAdmin]

    @transaction.atomic
    def post(self, request, pk):
        job = visible_job(request, pk, lock=True)
        serializer = ReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if job.status != Job.Status.SUBMITTED:
            raise Conflict()
        submission = job.submissions.filter(
            pk=data["submission_id"], review_status="pending", assignment_revision=job.assignment_revision
        ).first()
        if submission is None:
            raise Conflict("This submission is no longer pending. Refresh before reviewing.")
        submission.review_status = data["decision"]
        submission.review_reason = data["reason"]
        submission.reviewed_by = request.user
        submission.reviewed_at = timezone.now()
        submission.save(update_fields=["review_status", "review_reason", "reviewed_by", "reviewed_at"])
        transition(job, data["decision"], request.user, data["reason"])
        logger.info(
            "job_review",
            extra={
                "job_id": str(job.id),
                "decision": data["decision"],
                "review_latency_seconds": (submission.reviewed_at - submission.submitted_at).total_seconds(),
                "actual_hours": str(submission.actual_hours),
                "expected_hours": str(job.expected_hours),
            },
        )
        return detail(request, job)


class JobReassignView(APIView):
    permission_classes = [IsAdmin]

    @transaction.atomic
    def post(self, request, pk):
        job = visible_job(request, pk, lock=True)
        serializer = ReassignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_fellow = serializer.validated_data["assigned_to"]
        reason = serializer.validated_data["reason"]
        if not job.can_reassign:
            raise Conflict()
        if new_fellow.pk == job.assigned_to_id:
            raise serializers.ValidationError("Choose a different fellow.")
        old_fellow = job.assigned_to
        transition(job, "reassigned", request.user, reason)
        job.assigned_to = new_fellow
        job.assignment_revision += 1
        transition(job, Job.Status.ASSIGNED, request.user, reason, from_assignee=old_fellow)
        return detail(request, job)


class JobPhotoView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def get(self, request, pk, photo_id):
        job = visible_job(request, pk, lock=True)
        photo = get_object_or_404(
            JobSubmissionPhoto.objects.select_related("submission"), pk=photo_id, submission__job=job
        )
        if request.user.role != User.Role.ADMIN and (
            photo.submission.submitted_by_id != request.user.id
            or photo.submission.assignment_revision != job.assignment_revision
        ):
            raise Http404
        try:
            handle = storage.open_document(photo.storage_key)
        except OSError as exc:
            raise StorageUnavailable() from exc
        JobAccessLog.objects.create(job=job, photo=photo, accessed_by=request.user, action="photo_read")
        response = FileResponse(handle, content_type=photo.content_type)
        response["Cache-Control"] = "private, no-store"
        response["X-Content-Type-Options"] = "nosniff"
        return response
