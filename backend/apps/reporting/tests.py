from io import BytesIO
from unittest.mock import patch
from xml.etree import ElementTree
from zipfile import ZipFile

from django.core.exceptions import ValidationError
from django.db import IntegrityError, connection, transaction
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APITestCase

from apps.accounts.models import Block, FellowProfile, User
from apps.jobs.models import Job, JobSubmission
from apps.reporting.models import ExportLog
from apps.volunteers.models import Volunteer


def cells(content):
    with ZipFile(BytesIO(content)) as archive:
        sheet = ElementTree.fromstring(archive.read("xl/worksheets/sheet1.xml"))
    ns = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    assert not sheet.findall(".//s:f", ns)
    return [
        [cell.text or "" for cell in row.findall("s:c/s:is/s:t", ns)]
        for row in sheet.findall("s:sheetData/s:row", ns)
    ]


class ReportingTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            email="reports-admin@example.com", role="admin", status="active"
        )
        self.fellows = []
        for number in (3, 7):
            block = Block.objects.get(number=number)
            user = User.objects.create_user(email=f"fellow{number}@example.com", status="active")
            fellow = FellowProfile.objects.create(
                user=user,
                block=block,
                full_name=f"Fellow {number}",
                phone_number=f"+9198765432{number:02d}",
                aadhaar_number="sensitive-aadhaar",
                bank_account_number="sensitive-bank",
            )
            Volunteer.objects.create(
                fellow_profile=fellow,
                full_name=f"=Volunteer {number}",
                phone_number=f"+9187654321{number:02d}",
            )
            self.fellows.append(fellow)
        self.client.force_authenticate(self.admin)

    def test_canonical_constraints_and_legacy_visibility(self):
        legacy = Block.objects.create(name="North Block")
        with self.assertRaises(ValidationError):
            Block.objects.create(number=99)
        with self.assertRaises(IntegrityError), transaction.atomic():
            Block.objects.filter(pk=legacy.pk).update(number=99)
        with self.assertRaises(IntegrityError), transaction.atomic():
            Block.objects.filter(pk=legacy.pk).update(is_active=True)
        response = self.client.get("/api/v1/blocks")
        self.assertEqual([row["number"] for row in response.data], [3, 7, 14, 19, 27, 29, 32])
        self.client.force_authenticate(self.fellows[0].user)
        self.assertEqual(self.client.patch("/api/v1/profile/me", {"block": str(legacy.pk)}).status_code, 400)

    def test_rbac_all_new_endpoints(self):
        paths = [
            "admin/volunteers",
            "admin/exports",
            "admin/exports/fellow_contact_list",
            "admin/exports/event_participant_list",
            "admin/dashboard/blocks",
            f"admin/dashboard/fellows/{self.fellows[0].pk}",
            "admin/jobs",
        ]
        for user, expected in ((None, 401), (self.fellows[0].user, 403)):
            self.client.force_authenticate(user)
            for path in paths:
                with self.subTest(path=path, user=user):
                    self.assertEqual(self.client.get(f"/api/v1/{path}").status_code, expected)
        self.assertFalse(ExportLog.objects.exists())

    def test_block_filters_existing_and_new_lists(self):
        for fellow in self.fellows:
            Job.objects.create(
                created_by=self.admin,
                assigned_to=fellow,
                title=f"Job {fellow.block.number}",
                expected_hours=2,
            )
        for path in ("admin/fellows", "jobs", "admin/jobs", "admin/volunteers"):
            response = self.client.get(f"/api/v1/{path}?block=3")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data["count"], 1)
            self.assertEqual(self.client.get(f"/api/v1/{path}?block=99").status_code, 400)
        self.assertEqual(self.client.get("/api/v1/admin/volunteers").data["count"], 2)

    def test_contact_export_columns_filter_and_no_sensitive_sql(self):
        with CaptureQueriesContext(connection) as queries:
            response = self.client.get("/api/v1/admin/exports/fellow_contact_list?block=3")
        self.assertEqual(response.status_code, 200)
        rows = cells(response.content)
        self.assertEqual(rows[0], ["Fellow ID", "Name", "Email", "Phone", "Block"])
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][1:], ["Fellow 3", "fellow3@example.com", "+919876543203", "3"])
        sql = " ".join(q["sql"] for q in queries).lower()
        for field in ("aadhaar", "bank_account", "bank_ifsc"):
            self.assertNotIn(field, sql)
        log = ExportLog.objects.get()
        self.assertEqual(log.filters, {"block": 3})
        self.assertEqual(log.run_by, self.admin)
        self.assertEqual(response["Cache-Control"], "private, no-store")

    def test_event_roster_honest_status_and_literal_formula(self):
        response = self.client.get("/api/v1/admin/exports/event_participant_list?block=7")
        rows = cells(response.content)
        self.assertEqual(
            rows[0], ["Volunteer ID", "Name", "Phone", "Fellow", "Block", "Participation status"]
        )
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][1], "=Volunteer 7")
        self.assertEqual(rows[1][-1], "Candidate — attendance not recorded")

    def test_validation_and_generation_failures_do_not_log(self):
        for path in ("fellow_contact_list?block=9", "unknown"):
            self.assertEqual(self.client.get(f"/api/v1/admin/exports/{path}").status_code, 400)
        with patch("apps.reporting.views.workbook", side_effect=RuntimeError("generation failed")):
            with self.assertRaises(RuntimeError):
                self.client.get("/api/v1/admin/exports/fellow_contact_list")
        self.assertFalse(ExportLog.objects.exists())

    def test_log_failure_prevents_file_response(self):
        with patch(
            "apps.reporting.views.ExportLog.objects.create", side_effect=RuntimeError("audit unavailable")
        ):
            with self.assertRaises(RuntimeError):
                self.client.get("/api/v1/admin/exports/fellow_contact_list")

    def test_history_is_only_requesting_admin(self):
        other = User.objects.create_user(email="other-admin@example.com", role="admin")
        ExportLog.objects.create(run_by=other, export_type="fellow_contact_list")
        self.client.get("/api/v1/admin/exports/fellow_contact_list")
        response = self.client.get("/api/v1/admin/exports")
        self.assertEqual(response.data["count"], 1)

    def test_aggregates_do_not_duplicate_hours_for_resubmission_or_reassignment(self):
        original, current = self.fellows
        job = Job.objects.create(
            created_by=self.admin, assigned_to=current, title="Reassigned", expected_hours=5
        )
        JobSubmission.objects.create(
            job=job,
            submitted_by=original.user,
            assignment_revision=1,
            actual_hours=3,
            review_status="rejected",
        )
        JobSubmission.objects.create(
            job=job,
            submitted_by=current.user,
            assignment_revision=2,
            actual_hours=4,
            review_status="rejected",
        )
        JobSubmission.objects.create(
            job=job,
            submitted_by=current.user,
            assignment_revision=2,
            actual_hours=6,
            review_status="approved",
        )
        result = self.client.get(f"/api/v1/admin/dashboard/fellows/{current.pk}").data
        self.assertEqual(result["job_count"], 1)
        self.assertEqual(result["expected_hours"], "5.00")
        self.assertEqual(result["approved_hours"], "6.00")
        self.assertEqual(result["submission_count"], 2)
        self.assertEqual(result["approval_count"], 1)
        blocks = self.client.get("/api/v1/admin/dashboard/blocks").data["results"]
        self.assertEqual(len(blocks), 7)
        self.assertEqual(blocks[0]["submission_count"], 1)
        self.assertEqual(blocks[0]["job_count"], 0)
        self.assertEqual(blocks[1]["approved_hours"], "6.00")

    def test_unknown_fellow_is_404(self):
        self.assertEqual(
            self.client.get(
                "/api/v1/admin/dashboard/fellows/00000000-0000-0000-0000-000000000000"
            ).status_code,
            404,
        )
