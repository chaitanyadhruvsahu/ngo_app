import tempfile
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

from django.contrib import admin
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework.exceptions import ValidationError
from rest_framework.test import APITestCase

from apps.accounts.models import FellowProfile, User
from apps.documents.services import storage
from apps.jobs.admin import SubmissionHistoryAdmin
from apps.jobs.models import Job, JobAccessLog, JobStatusTransition, JobSubmission, JobSubmissionPhoto
from apps.jobs.services import TRANSITIONS, Conflict, validate_transition


def photo(content=None):
    if content is None:
        stream = BytesIO()
        Image.new("RGB", (8, 8), "blue").save(stream, format="JPEG")
        content = stream.getvalue()
    return SimpleUploadedFile("evidence.jpg", content, content_type="image/jpeg")


class StateMachineTests(SimpleTestCase):
    @override_settings(JOB_GEOTAG_ENABLED=True)
    def test_optional_malformed_location_never_blocks_submission(self):
        from apps.jobs.serializers import SubmissionInputSerializer

        for fields in (
            {"geotag_lat": "28.6"},
            {"geotag_lat": "capture failed", "geotag_lng": "77.2"},
            {"geotag_lat": "91", "geotag_lng": "181"},
            {"location_consent": "unavailable", "geotag_lat": "28.6", "geotag_lng": "77.2"},
        ):
            serializer = SubmissionInputSerializer(
                data={
                    "actual_hours": "2.00",
                    "location_consent": "true",
                    "device_timestamp": "",
                    **fields,
                }
            )
            self.assertTrue(serializer.is_valid(), serializer.errors)
            self.assertIsNone(serializer.validated_data.get("geotag_lat"))
            self.assertIsNone(serializer.validated_data.get("geotag_lng"))

    def test_admin_does_not_expose_location_without_access_log(self):
        self.assertIsInstance(admin.site._registry[JobSubmission], SubmissionHistoryAdmin)
        self.assertEqual(set(admin.site._registry[JobSubmission].exclude), {"geotag_lat", "geotag_lng"})

    def test_every_pair_of_states(self):
        for source in TRANSITIONS:
            for target in TRANSITIONS:
                with self.subTest(source=source, target=target):
                    if target in TRANSITIONS[source]:
                        validate_transition(source, target, "Reason")
                    else:
                        with self.assertRaises(Conflict):
                            validate_transition(source, target, "Reason")

    def test_rejection_requires_nonblank_reason(self):
        with self.assertRaises(ValidationError):
            validate_transition("submitted", "rejected", "  ")


@override_settings(STORAGE_BACKEND="local", JOB_GEOTAG_ENABLED=False)
class JobsApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = User.objects.create_user(email="jobs-admin@example.org", role="admin", status="active")
        cls.user = User.objects.create_user(email="jobs-fellow@example.org", status="active")
        cls.other = User.objects.create_user(email="jobs-other@example.org", status="active")
        cls.fellow = FellowProfile.objects.create(user=cls.user, full_name="Fellow One")
        cls.other_fellow = FellowProfile.objects.create(user=cls.other, full_name="Fellow Two")

    def setUp(self):
        self.root = tempfile.TemporaryDirectory(prefix="ngo_jobs_tests_")
        self.addCleanup(self.root.cleanup)
        settings_override = override_settings(DOCUMENT_STORAGE_ROOT=self.root.name)
        settings_override.enable()
        self.addCleanup(settings_override.disable)
        storage._storage.cache_clear()
        self.addCleanup(storage._storage.cache_clear)
        self.client.force_authenticate(self.admin)
        response = self.client.post(
            reverse("job-list"),
            {
                "assigned_to": str(self.fellow.id),
                "title": "Visit households",
                "description": "Survey local needs",
                "expected_hours": "2.50",
                "internal_note": "ADMIN ONLY",
            },
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.job_id = response.data["id"]

    def url(self, name, *args):
        return reverse(name, args=[self.job_id, *args])

    def submit(self, user=None, **fields):
        self.client.force_authenticate(user or self.user)
        return self.client.post(
            self.url("job-submit"),
            {
                "actual_hours": "3.25",
                "photos": [photo()],
                **fields,
            },
            format="multipart",
        )

    def review(self, submission_id, decision="approved", reason=""):
        self.client.force_authenticate(self.admin)
        return self.client.post(
            self.url("job-review"),
            {
                "submission_id": str(submission_id),
                "decision": decision,
                "reason": reason,
            },
        )

    def test_lifecycle_preserves_attempts_and_complete_audit(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post(self.url("job-start")).status_code, 200)
        first = self.submit()
        self.assertEqual(first.status_code, 201, first.data)
        first_id = first.data["submissions"][0]["id"]
        self.assertEqual(self.review(first_id, "rejected", "Need clearer proof").status_code, 200)
        second = self.submit(actual_hours="2.00")
        self.assertEqual(second.status_code, 201, second.data)
        approved = self.review(second.data["submissions"][-1]["id"])
        self.assertEqual(approved.data["status"], "approved")
        self.assertEqual([row["actual_hours"] for row in approved.data["submissions"]], ["3.25", "2.00"])
        self.assertEqual(JobSubmissionPhoto.objects.count(), 2)
        transitions = list(JobStatusTransition.objects.filter(job_id=self.job_id))
        self.assertEqual(
            [row.to_status for row in transitions],
            ["created", "assigned", "in_progress", "submitted", "rejected", "submitted", "approved"],
        )
        self.assertTrue(all(row.actor_id and row.created_at for row in transitions))
        self.assertEqual(transitions[4].reason, "Need clearer proof")
        self.assertEqual(self.submit().status_code, 409)
        self.assertEqual(JobSubmission.objects.count(), 2)

    def test_all_endpoints_reject_anonymous(self):
        response = self.submit()
        photo_id = response.data["submissions"][0]["photos"][0]["id"]
        self.client.force_authenticate(None)
        cases = [
            ("get", reverse("job-config")),
            ("get", reverse("job-list")),
            ("post", reverse("job-list")),
            ("get", reverse("job-mine")),
            ("get", self.url("job-detail")),
            ("patch", self.url("job-detail")),
            ("post", self.url("job-start")),
            ("post", self.url("job-submit")),
            ("post", self.url("job-review")),
            ("post", self.url("job-reassign")),
            ("get", self.url("job-photo", photo_id)),
        ]
        for method, url in cases:
            with self.subTest(method=method, url=url):
                self.assertEqual(getattr(self.client, method)(url).status_code, 401)

    def test_all_wrong_role_categories_are_forbidden(self):
        self.client.force_authenticate(self.user)
        for method, url in [
            ("get", reverse("job-list")),
            ("post", reverse("job-list")),
            ("patch", self.url("job-detail")),
            ("post", self.url("job-review")),
            ("post", self.url("job-reassign")),
        ]:
            with self.subTest(url=url, method=method):
                self.assertEqual(getattr(self.client, method)(url).status_code, 403)
        self.client.force_authenticate(self.admin)
        for method, url in [
            ("get", reverse("job-mine")),
            ("post", self.url("job-start")),
            ("post", self.url("job-submit")),
        ]:
            with self.subTest(url=url):
                self.assertEqual(getattr(self.client, method)(url).status_code, 403)

    def test_cross_fellow_reads_and_mutations_return_404(self):
        response = self.submit()
        photo_id = response.data["submissions"][0]["photos"][0]["id"]
        self.client.force_authenticate(self.other)
        for method, url in [
            ("get", self.url("job-detail")),
            ("post", self.url("job-start")),
            ("post", self.url("job-submit")),
            ("get", self.url("job-photo", photo_id)),
        ]:
            with self.subTest(url=url):
                self.assertEqual(getattr(self.client, method)(url).status_code, 404)
        self.assertEqual(self.client.get(reverse("job-mine")).data["count"], 0)

    def test_internal_notes_absent_from_all_fellow_responses(self):
        self.client.force_authenticate(self.user)
        for response in [
            self.client.get(reverse("job-mine")),
            self.client.get(self.url("job-detail")),
            self.client.post(self.url("job-start")),
            self.submit(),
        ]:
            self.assertNotIn("internal_note", str(response.data))
            self.assertNotIn("ADMIN ONLY", str(response.data))
            self.assertNotIn("storage_key", str(response.data))

    def test_rejection_missing_or_blank_reason_is_400(self):
        submission_id = self.submit().data["submissions"][0]["id"]
        self.client.force_authenticate(self.admin)
        for reason in (None, "", "   "):
            payload = {"submission_id": str(submission_id), "decision": "rejected"}
            if reason is not None:
                payload["reason"] = reason
            self.assertEqual(self.client.post(self.url("job-review"), payload).status_code, 400)
        self.assertEqual(Job.objects.get(pk=self.job_id).status, "submitted")

    def test_reassign_hides_old_evidence_and_revokes_old_owner(self):
        response = self.submit()
        submission_id = response.data["submissions"][0]["id"]
        photo_id = response.data["submissions"][0]["photos"][0]["id"]
        self.review(submission_id, "rejected", "Wrong area")
        before = JobStatusTransition.objects.count()
        response = self.client.post(
            self.url("job-reassign"),
            {
                "assigned_to": str(self.other_fellow.pk),
                "reason": "PRIVATE reassignment reason",
            },
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(JobStatusTransition.objects.count(), before + 2)
        self.assertEqual(len(response.data["submissions"]), 1)
        self.assertEqual(str(response.data["transitions"][-1]["from_assignee"]), str(self.fellow.pk))
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.get(self.url("job-detail")).status_code, 404)
        self.assertEqual(self.client.get(self.url("job-photo", photo_id)).status_code, 404)
        self.client.force_authenticate(self.other)
        detail = self.client.get(self.url("job-detail"))
        self.assertEqual(detail.data["submissions"], [])
        self.assertNotIn("PRIVATE", str(detail.data))
        self.assertNotIn(str(self.fellow.id), str(detail.data))
        self.assertEqual(self.client.get(self.url("job-photo", photo_id)).status_code, 404)
        self.assertEqual(self.submit(user=self.other).status_code, 201)

    def test_edit_lock_and_internal_note_update(self):
        self.assertEqual(self.client.patch(self.url("job-detail"), {"title": "Updated"}).status_code, 200)
        payload = {"assigned_to": str(self.other_fellow.pk)}
        self.assertEqual(self.client.patch(self.url("job-detail"), payload).status_code, 400)
        self.client.force_authenticate(self.user)
        self.client.post(self.url("job-start"))
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.patch(self.url("job-detail"), {"title": "Locked"}).status_code, 409)
        self.assertEqual(
            self.client.patch(self.url("job-detail"), {"internal_note": "Follow up"}).status_code, 200
        )

    def test_duplicate_submit_and_stale_review_are_conflicts(self):
        submission_id = self.submit().data["submissions"][0]["id"]
        self.assertEqual(self.submit().status_code, 409)
        self.assertEqual(self.review(submission_id, "rejected", "Again").status_code, 200)
        self.assertEqual(self.submit().status_code, 201)
        self.assertEqual(self.review(submission_id).status_code, 409)
        self.assertEqual(Job.objects.get(pk=self.job_id).status, "submitted")

    def test_no_reassignment_during_review_or_after_approval(self):
        submission_id = self.submit().data["submissions"][0]["id"]
        self.client.force_authenticate(self.admin)
        payload = {"assigned_to": str(self.other_fellow.pk), "reason": "Move"}
        self.assertEqual(self.client.post(self.url("job-reassign"), payload).status_code, 409)
        self.review(submission_id)
        self.assertEqual(self.client.post(self.url("job-reassign"), payload).status_code, 409)

    def test_photos_require_actual_decodable_image_and_cap(self):
        for payload in ([photo(b"%PDF-1.4")], [photo(b"\xff\xd8\xffjunk")], [], [photo() for _ in range(6)]):
            self.assertEqual(self.submit(photos=payload).status_code, 400)
        with override_settings(MAX_UPLOAD_SIZE_MB=0):
            self.assertEqual(self.submit().status_code, 400)
        self.assertEqual(JobSubmission.objects.count(), 0)

    def test_mid_upload_failure_rolls_back_rows_transition_and_files(self):
        real_write = storage.write_document
        calls = 0

        def fail_second(key, upload):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("Storage unavailable")
            return real_write(key, upload)

        with patch("apps.jobs.views.storage.write_document", side_effect=fail_second):
            response = self.submit(photos=[photo(), photo()])
        self.assertEqual(response.status_code, 503, response.data)
        self.assertEqual(JobSubmission.objects.count(), 0)
        self.assertEqual(JobSubmissionPhoto.objects.count(), 0)
        self.assertEqual(JobStatusTransition.objects.count(), 2)
        self.assertEqual(Job.objects.get(pk=self.job_id).status, "assigned")
        self.assertEqual([p for p in Path(self.root.name).rglob("*") if p.is_file()], [])

    def test_geotag_privacy_gate_and_optional_metadata_failure(self):
        response = self.submit(
            device_timestamp="capture failed", geotag_lat="28.6", geotag_lng="77.2", location_consent="true"
        )
        self.assertEqual(response.status_code, 201, response.data)
        submission = response.data["submissions"][0]
        self.assertIsNone(submission["device_timestamp"])
        self.assertIsNone(submission["geotag_lat"])
        self.assertIsNone(submission["geotag_lng"])
        self.assertEqual(JobAccessLog.objects.filter(action="location_read").count(), 0)

    @override_settings(JOB_GEOTAG_ENABLED=True)
    def test_location_requires_opt_in_and_reads_are_logged(self):
        response = self.submit(geotag_lat="28.6", geotag_lng="77.2", location_consent="false")
        first_id = response.data["submissions"][0]["id"]
        self.assertIsNone(response.data["submissions"][0]["geotag_lat"])
        self.review(first_id, "rejected", "Retry")
        response = self.submit(geotag_lat="28.6", geotag_lng="77.2", location_consent="true")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data["submissions"][-1]["geotag_lat"], "28.600000")
        before = JobAccessLog.objects.filter(action="location_read").count()
        self.client.force_authenticate(self.admin)
        self.client.get(self.url("job-detail"))
        self.assertEqual(JobAccessLog.objects.filter(action="location_read").count(), before + 1)
        self.assertNotIn("geotag", str(self.client.get(reverse("job-list")).data))

    def test_authenticated_photo_read_logs_and_strips_exif(self):
        image = Image.new("RGB", (8, 8))
        metadata = Image.Exif()
        metadata[270] = "PRIVATE metadata"
        metadata[36867] = "2026:09:20 10:20:30"
        metadata[36881] = "+05:30"
        stream = BytesIO()
        image.save(stream, format="JPEG", exif=metadata)
        response = self.submit(photos=[photo(stream.getvalue())])
        self.assertEqual(response.status_code, 201, response.data)
        data = response.data["submissions"][0]["photos"][0]
        self.assertIsNotNone(data["exif_captured_at"])
        for user in [self.user, self.admin]:
            self.client.force_authenticate(user)
            download = self.client.get(self.url("job-photo", data["id"]))
            self.assertEqual(download.status_code, 200)
            self.assertEqual(download["Cache-Control"], "private, no-store")
            stored_bytes = b"".join(download.streaming_content)
            self.assertNotIn(b"PRIVATE", stored_bytes)
            self.assertEqual(len(Image.open(BytesIO(stored_bytes)).getexif()), 0)
        self.assertEqual(JobAccessLog.objects.filter(action="photo_read").count(), 2)

    def test_list_filters_and_invalid_data(self):
        response = self.client.get(reverse("job-list"), {"fellow": str(self.fellow.pk), "status": "assigned"})
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(self.client.get(reverse("job-list"), {"fellow": "garbage"}).status_code, 400)
        self.assertEqual(self.client.get(reverse("job-list"), {"status": "garbage"}).status_code, 400)
        for hours in ("0", "-1", "NaN", "10000"):
            response = self.client.post(
                reverse("job-list"),
                {
                    "assigned_to": str(self.fellow.pk),
                    "title": "Test",
                    "description": "Test",
                    "expected_hours": hours,
                },
            )
            self.assertEqual(response.status_code, 400)
