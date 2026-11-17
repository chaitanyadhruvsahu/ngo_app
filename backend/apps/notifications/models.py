import uuid
from datetime import timedelta

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models


class Notification(models.Model):
    class Type(models.TextChoices):
        TRAINING = "training", "Training"
        EVENT = "event", "Event"
        DEADLINE = "deadline", "Deadline"

    class Channel(models.TextChoices):
        IN_APP = "in_app", "In-app"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    type = models.CharField(max_length=16, choices=Type.choices)
    title_en = models.CharField(max_length=200)
    title_hi = models.CharField(max_length=200)
    body_en = models.TextField(max_length=4000)
    body_hi = models.TextField(max_length=4000)
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="targeted_notifications",
    )
    target_block = models.ForeignKey("accounts.Block", null=True, blank=True, on_delete=models.PROTECT)
    scheduled_time = models.DateTimeField()
    remind_before = models.DurationField(default=timedelta, validators=[MinValueValidator(timedelta())])
    channel = models.CharField(max_length=16, choices=Channel.choices, default=Channel.IN_APP)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="created_notifications"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    source_job = models.ForeignKey("jobs.Job", null=True, blank=True, on_delete=models.PROTECT)
    automation_key = models.CharField(max_length=200, null=True, blank=True, unique=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at", "id"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(target_user__isnull=False, target_block__isnull=True)
                    | models.Q(target_user__isnull=True, target_block__isnull=False)
                ),
                name="notification_exactly_one_target",
            ),
            models.CheckConstraint(
                condition=models.Q(remind_before__gte=timedelta()), name="notification_nonnegative_reminder"
            ),
            models.CheckConstraint(
                condition=models.Q(channel="in_app"), name="notification_supported_channel"
            ),
            models.CheckConstraint(
                condition=models.Q(type__in=["training", "event", "deadline"]),
                name="notification_supported_type",
            ),
        ]


class NotificationRecipientState(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    notification = models.ForeignKey(Notification, on_delete=models.PROTECT, related_name="recipients")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    read_at = models.DateTimeField(null=True, blank=True)
    dismissed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["notification", "user"], name="unique_notification_recipient")
        ]
