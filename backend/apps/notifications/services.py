from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from django.db.models import DateTimeField, ExpressionWrapper, F
from django.utils import timezone

from apps.accounts.models import User
from apps.jobs.models import Job
from apps.notifications.models import Notification, NotificationRecipientState

ACTIVE_WORK = [Job.Status.ASSIGNED, Job.Status.IN_PROGRESS, Job.Status.REJECTED]


def sync_job_reminders(now):
    """Create each assignment/deadline alert once, including across worker retries.

    Resolve the assignee and deadline under the same job lock used by lifecycle
    changes. Never backfill old deadline stages or send daily overdue noise.
    """
    today = timezone.localdate(now, timezone=ZoneInfo(settings.JOB_REMINDER_TIME_ZONE))
    ids = Job.objects.filter(status__in=ACTIVE_WORK).values_list("id", flat=True)
    for pk in ids.iterator():
        with transaction.atomic():
            job = Job.objects.select_for_update().select_related("assigned_to__user").get(pk=pk)
            if job.status not in ACTIVE_WORK or job.assigned_to.user.status != User.Status.ACTIVE:
                continue
            stages = [("assigned", "New work, just for you", "आपको नया कार्य मिला है",
                       f'You have been assigned “{job.title}”. Open your work to get started.',
                       f'आपको “{job.title}” सौंपा गया है। शुरू करने के लिए अपना काम खोलें।')]
            if job.deadline:
                days = (job.deadline - today).days
                if days <= 1:
                    stage = "tomorrow" if days == 1 else "today" if days == 0 else "overdue"
                    titles = {"tomorrow": ("A little heads-up: due tomorrow", "कार्य कल तक पूरा करना है"),
                              "today": ("Your work is due today", "आज कार्य की अंतिम तिथि है"),
                              "overdue": ("Let’s get this work moving", "इस कार्य को आगे बढ़ाएँ")}
                    en, hi = titles[stage]
                    stages.append((stage, en, hi,
                                   f'“{job.title}” is due {job.deadline:%d %b %Y}. '
                                   'Share your progress or contact your team if you need support.',
                                   f'“{job.title}” की अंतिम तिथि {job.deadline:%d %b %Y} है। '
                                   'प्रगति साझा करें या सहायता के लिए टीम से संपर्क करें।'))
            for stage, title_en, title_hi, body_en, body_hi in stages:
                deadline_key = str(job.deadline) if stage != "assigned" else "assignment"
                key = f"job:{job.id}:{job.assignment_revision}:{deadline_key}:{stage}"
                Notification.objects.get_or_create(automation_key=key, defaults={
                    "source_job": job, "type": "deadline", "title_en": title_en, "title_hi": title_hi,
                    "body_en": body_en, "body_hi": body_hi, "target_user": job.assigned_to.user,
                    "scheduled_time": now, "created_by": job.created_by,
                })


def deliver_due(now=None):
    now = now or timezone.now()
    sync_job_reminders(now)
    due = (
        Notification.objects.filter(delivered_at__isnull=True, cancelled_at__isnull=True)
        .annotate(
            due_at=ExpressionWrapper(F("scheduled_time") - F("remind_before"), output_field=DateTimeField())
        )
        .filter(due_at__lte=now)
        .values_list("pk", flat=True)
    )
    delivered = 0
    for pk in due.iterator():
        with transaction.atomic():
            notification = Notification.objects.select_for_update().get(pk=pk)
            if notification.delivered_at is not None:
                continue
            if notification.source_job_id:
                job = Job.objects.select_for_update().get(pk=notification.source_job_id)
                expected_prefix = f"job:{job.id}:{job.assignment_revision}:"
                parts = notification.automation_key.split(":")
                stale_date = parts[-2] not in ("assignment", str(job.deadline))
                if (job.status not in ACTIVE_WORK or job.assigned_to.user_id != notification.target_user_id
                        or not notification.automation_key.startswith(expected_prefix) or stale_date):
                    notification.cancelled_at = now
                    notification.save(update_fields=["cancelled_at"])
                    continue
            users = User.objects.filter(status=User.Status.ACTIVE)
            if notification.target_user_id:
                users = users.filter(pk=notification.target_user_id)
            else:
                users = users.filter(
                    role=User.Role.FELLOW, fellow_profile__block_id=notification.target_block_id
                )
            NotificationRecipientState.objects.bulk_create(
                [
                    NotificationRecipientState(notification=notification, user_id=user_id)
                    for user_id in users.values_list("id", flat=True)
                ]
            )
            notification.delivered_at = now
            notification.save(update_fields=["delivered_at"])
            delivered += 1
    return delivered
