from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from datetime import timezone as dt_timezone
from threading import Barrier
from unittest.mock import patch

from django.db import IntegrityError, close_old_connections, connection, transaction
from django.test import TransactionTestCase, override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import Block, FellowProfile, User
from apps.jobs.models import Job
from apps.notifications.models import Notification, NotificationRecipientState
from apps.notifications.services import deliver_due


@override_settings(JOB_REMINDER_TIME_ZONE="UTC")
class NotificationTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            email="notifier@example.org", password="test", role="admin", status="active"
        )
        self.alice = User.objects.create_user(email="alice@example.org", password="test", status="active")
        self.bob = User.objects.create_user(email="bob@example.org", password="test", status="active")
        self.block = Block.objects.get(number=3)
        for user in [self.alice, self.bob]:
            FellowProfile.objects.update_or_create(user=user, defaults={"block": self.block})
        self.now = timezone.now()

    def data(self, **kwargs):
        return {
            "type": "training",
            "title_en": "Training",
            "title_hi": "प्रशिक्षण",
            "body_en": "Meet at the centre",
            "body_hi": "केंद्र पर मिलें",
            "scheduled_time": self.now + timedelta(days=1),
            "remind_before": timedelta(days=1),
            "target_block": self.block,
            "created_by": self.admin,
            **kwargs,
        }

    def notice(self, **kwargs):
        return Notification.objects.create(**self.data(**kwargs))

    def job(self, **kwargs):
        return Job.objects.create(created_by=self.admin, assigned_to=self.alice.fellow_profile,
                                  title="Community visit", description="Meet volunteers", expected_hours=2,
                                  status="assigned", **kwargs)

    def test_job_assignment_and_deadline_alerts_are_automatic_and_idempotent(self):
        job = self.job(deadline=timezone.localdate(self.now) + timedelta(days=1))
        self.assertEqual(deliver_due(self.now), 2)
        self.assertEqual(deliver_due(self.now), 0)
        self.assertEqual(deliver_due(self.now + timedelta(days=1)), 1)
        self.assertEqual(deliver_due(self.now + timedelta(days=2)), 1)
        self.assertEqual(deliver_due(self.now + timedelta(days=5)), 0)
        self.assertEqual(NotificationRecipientState.objects.filter(
            notification__source_job=job, user=self.alice).count(), 4)
        self.assertFalse(NotificationRecipientState.objects.filter(
            notification__source_job=job, user=self.bob).exists())

    def test_submitted_and_approved_jobs_stop_future_reminders(self):
        job = self.job(deadline=timezone.localdate(self.now))
        deliver_due(self.now)
        for status in ("submitted", "approved"):
            job.status = status
            job.save()
            self.assertEqual(deliver_due(self.now + timedelta(days=1)), 0)

    def test_changed_assignee_and_deadline_cancel_stale_pending_alerts(self):
        from apps.notifications.services import sync_job_reminders
        job = self.job(deadline=timezone.localdate(self.now))
        sync_job_reminders(self.now)
        stale_ids = list(Notification.objects.values_list("id", flat=True))
        job.assigned_to = self.bob.fellow_profile
        job.assignment_revision += 1
        job.deadline += timedelta(days=5)
        job.save()
        self.assertEqual(deliver_due(self.now), 1)
        self.assertEqual(Notification.objects.filter(id__in=stale_ids, cancelled_at__isnull=False).count(), 2)
        self.assertFalse(NotificationRecipientState.objects.filter(user=self.alice).exists())

    def test_job_link_is_returned_in_recipient_updates(self):
        job = self.job()
        deliver_due(self.now)
        self.client.force_authenticate(self.alice)
        response = self.client.get("/api/v1/notifications/mine")
        self.assertEqual(response.data["results"][0]["source_job"], str(job.id))

    @override_settings(JOB_REMINDER_TIME_ZONE="Asia/Kolkata")
    def test_due_date_uses_ngo_timezone_at_midnight(self):
        now = datetime(2026, 10, 29, 18, 31, tzinfo=dt_timezone.utc)
        job = self.job(deadline=datetime(2026, 10, 30).date())
        deliver_due(now)
        self.assertTrue(Notification.objects.filter(
            source_job=job, automation_key__endswith=":today").exists())
        self.assertFalse(Notification.objects.filter(
            source_job=job, automation_key__endswith=":tomorrow").exists())

    def test_due_boundary_and_retries(self):
        notice = self.notice()
        self.assertEqual(deliver_due(self.now - timedelta(microseconds=1)), 0)
        self.assertEqual(deliver_due(self.now), 1)
        self.assertEqual(deliver_due(self.now), 0)
        self.assertEqual(notice.recipients.count(), 2)

    def test_read_and_dismiss_are_independent_idempotent_and_private(self):
        notice = self.notice()
        deliver_due(self.now)
        self.client.force_authenticate(self.alice)
        result = self.client.post(f"/api/v1/notifications/{notice.pk}/dismiss")
        self.assertEqual(result.status_code, 200)
        first = result.data["dismissed_at"]
        self.assertEqual(
            self.client.post(f"/api/v1/notifications/{notice.pk}/dismiss").data["dismissed_at"], first
        )
        bob = notice.recipients.get(user=self.bob)
        self.assertIsNone(bob.dismissed_at)
        self.assertIsNone(bob.read_at)
        self.client.force_authenticate(self.bob)
        self.assertEqual(self.client.post(f"/api/v1/notifications/{notice.pk}/read").status_code, 200)
        bob.refresh_from_db()
        self.assertIsNotNone(bob.read_at)
        self.assertIsNone(bob.dismissed_at)
        response = self.client.get("/api/v1/notifications/mine")
        mine = response.data["results"][0]
        self.assertNotIn("target_block", mine)
        self.assertNotIn("target_user", mine)
        self.assertEqual(response["Cache-Control"], "private, no-store")

    def test_rbac_and_undelivered_or_other_user_404(self):
        notice = self.notice(target_block=None, target_user=self.alice)
        for path in [
            "/api/v1/notifications/mine",
            "/api/v1/admin/notifications",
            "/api/v1/admin/notifications/targets",
        ]:
            self.assertEqual(self.client.get(path).status_code, 401)
        self.assertEqual(self.client.post(f"/api/v1/notifications/{notice.pk}/dismiss").status_code, 401)
        self.client.force_authenticate(self.bob)
        self.assertEqual(self.client.get("/api/v1/admin/notifications").status_code, 403)
        self.assertEqual(self.client.get("/api/v1/admin/notifications/targets").status_code, 403)
        self.assertEqual(self.client.post("/api/v1/admin/notifications", {}).status_code, 403)
        self.assertEqual(self.client.post(f"/api/v1/notifications/{notice.pk}/read").status_code, 404)
        self.client.force_authenticate(self.alice)
        self.assertEqual(self.client.post(f"/api/v1/notifications/{notice.pk}/dismiss").status_code, 404)
        deliver_due(self.now)
        self.client.force_authenticate(self.bob)
        self.assertEqual(self.client.post(f"/api/v1/notifications/{notice.pk}/dismiss").status_code, 404)

    def test_creation_validation_and_month_filter(self):
        self.client.force_authenticate(self.admin)
        payload = {
            **self.data(),
            "scheduled_time": self.now.isoformat(),
            "remind_before": "00:00:00",
            "target_block": str(self.block.pk),
        }
        payload.pop("created_by")
        self.assertEqual(
            self.client.post("/api/v1/admin/notifications", payload, format="json").status_code, 201
        )
        for invalid in [
            {"channel": "sms"},
            {"remind_before": "-1 00:00:00"},
            {"target_user": str(self.alice.pk)},
            {"target_block": None},
            {"title_en": ""},
        ]:
            self.assertEqual(
                self.client.post(
                    "/api/v1/admin/notifications", {**payload, **invalid}, format="json"
                ).status_code,
                400,
            )
        deliver_due(self.now)
        self.client.force_authenticate(self.alice)
        self.assertEqual(
            self.client.get("/api/v1/notifications/mine", {"month": self.now.strftime("%Y-%m")}).data[
                "count"
            ],
            1,
        )
        self.assertEqual(self.client.get("/api/v1/notifications/mine", {"month": "bad"}).status_code, 400)

    def test_english_only_announcement(self):
        self.client.force_authenticate(self.admin)
        payload = {
            "type": "event", "channel": "in_app", "title_en": "Team meeting",
            "body_en": "Meet at the library.", "scheduled_time": self.now.isoformat(),
            "target_block": str(self.block.pk),
        }
        response = self.client.post("/api/v1/admin/notifications", payload, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["title_hi"], "")
        self.assertEqual(response.data["body_hi"], "")

    def test_recipient_membership_resolved_at_delivery_and_frozen(self):
        notice = self.notice()
        profile = self.bob.fellow_profile
        profile.block = Block.objects.get(number=7)
        profile.save()
        deliver_due(self.now)
        self.assertEqual(list(notice.recipients.values_list("user_id", flat=True)), [self.alice.pk])
        profile.block = self.block
        profile.save()
        deliver_due(self.now)
        self.assertEqual(notice.recipients.count(), 1)

    def test_failed_delivery_rolls_back_and_retries(self):
        notice = self.notice()
        original_save = Notification.save

        def fail(instance, *args, **kwargs):
            if kwargs.get("update_fields") == ["delivered_at"]:
                raise RuntimeError("simulated delivery failure")
            return original_save(instance, *args, **kwargs)

        with patch.object(Notification, "save", fail), self.assertRaises(RuntimeError):
            deliver_due(self.now)
        self.assertEqual(notice.recipients.count(), 0)
        notice.refresh_from_db()
        self.assertIsNone(notice.delivered_at)
        self.assertEqual(deliver_due(self.now), 1)

    def test_database_requires_exactly_one_target(self):
        for values in [{"target_block": None}, {"target_user": self.alice}]:
            with self.assertRaises(IntegrityError), transaction.atomic():
                self.notice(**values)


class ConcurrentDeliveryTests(TransactionTestCase):
    def test_two_workers_deliver_once(self):
        if connection.vendor != "postgresql":
            self.skipTest("Concurrency guarantee requires PostgreSQL row locks")
        admin = User.objects.create_user(
            email="concurrent-admin@example.org", password="test", role="admin", status="active"
        )
        recipient = User.objects.create_user(
            email="concurrent-user@example.org", password="test", status="active"
        )
        now = timezone.now()
        notice = Notification.objects.create(
            type="event",
            title_en="Meeting",
            title_hi="बैठक",
            body_en="Details",
            body_hi="विवरण",
            target_user=recipient,
            scheduled_time=now,
            created_by=admin,
        )
        barrier = Barrier(2)

        def worker():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                return deliver_due(now)
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: worker(), range(2)))
        self.assertEqual(sum(results), 1)
        self.assertEqual(NotificationRecipientState.objects.filter(notification=notice).count(), 1)
