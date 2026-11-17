import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q


class Job(models.Model):
    class Status(models.TextChoices):
        CREATED = "created", "Created"
        ASSIGNED = "assigned", "Assigned"
        IN_PROGRESS = "in_progress", "In progress"
        SUBMITTED = "submitted", "Submitted"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="created_jobs"
    )
    assigned_to = models.ForeignKey("accounts.FellowProfile", on_delete=models.PROTECT, related_name="jobs")
    assignment_revision = models.PositiveIntegerField(default=1)
    title = models.CharField(max_length=255)
    description = models.TextField()
    expected_hours = models.DecimalField(max_digits=6, decimal_places=2)
    deadline = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.CREATED, db_index=True)
    internal_note = models.TextField(blank=True, default="")
    work_started_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [models.CheckConstraint(condition=Q(expected_hours__gt=0), name="job_positive_hours")]

    @property
    def can_edit(self):
        return self.status == self.Status.ASSIGNED and self.work_started_at is None

    @property
    def can_reassign(self):
        return self.status in (self.Status.ASSIGNED, self.Status.IN_PROGRESS, self.Status.REJECTED)


class JobStatusTransition(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    job = models.ForeignKey(Job, on_delete=models.PROTECT, related_name="transitions")
    assignment_revision = models.PositiveIntegerField()
    from_status = models.CharField(max_length=16, null=True)
    to_status = models.CharField(max_length=16)
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    reason = models.TextField(blank=True, default="")
    from_assignee = models.ForeignKey(
        "accounts.FellowProfile", on_delete=models.PROTECT, null=True, related_name="job_transitions_from"
    )
    to_assignee = models.ForeignKey(
        "accounts.FellowProfile", on_delete=models.PROTECT, related_name="job_transitions_to"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise ValueError("Job transition history cannot be changed.")
        return super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValueError("Job transition history cannot be deleted.")


class JobSubmission(models.Model):
    class ReviewStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    job = models.ForeignKey(Job, on_delete=models.PROTECT, related_name="submissions")
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="job_submissions"
    )
    assignment_revision = models.PositiveIntegerField()
    actual_hours = models.DecimalField(max_digits=6, decimal_places=2)
    submitted_at = models.DateTimeField(auto_now_add=True)
    device_timestamp = models.DateTimeField(null=True, blank=True)
    geotag_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    geotag_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, null=True, related_name="reviewed_job_submissions"
    )
    review_status = models.CharField(
        max_length=10, choices=ReviewStatus.choices, default=ReviewStatus.PENDING
    )
    review_reason = models.TextField(blank=True, default="")
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["submitted_at", "id"]
        constraints = [
            models.CheckConstraint(condition=Q(actual_hours__gt=0), name="submission_positive_hours"),
            models.UniqueConstraint(
                fields=["job"], condition=Q(review_status="pending"), name="one_pending_submission"
            ),
        ]


class JobSubmissionPhoto(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    submission = models.ForeignKey(JobSubmission, on_delete=models.PROTECT, related_name="photos")
    storage_key = models.CharField(max_length=1024)
    content_type = models.CharField(max_length=32)
    size_bytes = models.PositiveIntegerField()
    checksum_sha256 = models.CharField(max_length=64)
    # No timezone is invented for EXIF timestamps without an offset.
    exif_captured_at = models.DateTimeField(null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["uploaded_at", "id"]


class JobAccessLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    job = models.ForeignKey(Job, on_delete=models.PROTECT)
    photo = models.ForeignKey(JobSubmissionPhoto, null=True, on_delete=models.PROTECT)
    accessed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    action = models.CharField(
        max_length=24, choices=[("photo_read", "Photo read"), ("location_read", "Location read")]
    )
    accessed_at = models.DateTimeField(auto_now_add=True)
