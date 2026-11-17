import tempfile
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import FellowProfile, User
from apps.documents.models import Document, DocumentAccessLog
from apps.documents.services import storage as storage_service

_PDF_BYTES = b"%PDF-1.4\n%mock pdf content for tests\n"
_TMP_STORAGE_ROOT = tempfile.mkdtemp(prefix="ngo_app_test_documents_")


@override_settings(DOCUMENT_STORAGE_ROOT=_TMP_STORAGE_ROOT)
class DocumentApiTests(APITestCase):
    """Covers Phase 2 Mandate #4 (403/404 test pair) and #2 (access logging,
    no exceptions) for every documents endpoint.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        storage_service._storage.cache_clear()

    def setUp(self):
        self.fellow_user = User.objects.create_user(
            email="fellow-doc@example.com", password="correct-horse-battery-1", status=User.Status.ACTIVE
        )
        self.fellow_profile = FellowProfile.objects.create(user=self.fellow_user)

        self.other_fellow_user = User.objects.create_user(
            email="other-fellow-doc@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        self.other_fellow_profile = FellowProfile.objects.create(user=self.other_fellow_user)

        self.admin_user = User.objects.create_user(
            email="admin-doc@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
            role=User.Role.ADMIN,
        )

    def _upload(self, user, doc_type="aadhaar", content=_PDF_BYTES):
        self.client.force_authenticate(user=user)
        upload = SimpleUploadedFile("test.pdf", content, content_type="application/pdf")
        response = self.client.post(
            reverse("document-list-create"), {"type": doc_type, "file": upload}, format="multipart"
        )
        self.client.force_authenticate(user=None)
        return response

    # --- upload / validation ---

    def test_upload_and_list_own_documents(self):
        response = self._upload(self.fellow_user)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertNotIn("storage_key", response.data)  # Mandate #1

        self.client.force_authenticate(user=self.fellow_user)
        list_response = self.client.get(reverse("document-list-create"))
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_response.data), 1)

    def test_upload_rejects_disguised_file_type(self):
        # .pdf extension claimed, but the bytes aren't a PDF — content
        # sniffing must catch this regardless of filename/Content-Type
        # (Mandate #6).
        response = self._upload(self.fellow_user, content=b"not actually a pdf")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"]["code"], "unsupported_file_type")

    def test_upload_rejects_oversized_file(self):
        with override_settings(MAX_UPLOAD_SIZE_MB=0):
            response = self._upload(self.fellow_user)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"]["code"], "file_too_large")

    def test_reupload_supersedes_previous_document_of_same_type(self):
        first = self._upload(self.fellow_user)
        second = self._upload(self.fellow_user)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)

        first_doc = Document.objects.get(id=first.data["id"])
        first_doc.refresh_from_db()
        self.assertIsNotNone(first_doc.superseded_at)

        self.client.force_authenticate(user=self.fellow_user)
        list_response = self.client.get(reverse("document-list-create"))
        self.assertEqual(len(list_response.data), 1)  # superseded one excluded
        self.assertEqual(list_response.data[0]["id"], second.data["id"])

    # --- RBAC: Fellow vs Admin (Mandate #4) ---

    def test_admin_cannot_upload_documents(self):
        response = self._upload(self.admin_user)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_list_documents(self):
        response = self.client.get(reverse("document-list-create"))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_fellow_cannot_access_admin_fellow_document_list(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("admin-fellow-documents", args=[self.other_fellow_profile.id]))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_list_any_fellows_documents(self):
        self._upload(self.fellow_user)
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("admin-fellow-documents", args=[self.fellow_profile.id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    # --- ownership: 404 not 403 (Mandate #5) ---

    def test_fellow_downloading_another_fellows_document_gets_404(self):
        upload_response = self._upload(self.fellow_user)
        document_id = upload_response.data["id"]

        self.client.force_authenticate(user=self.other_fellow_user)
        response = self.client.get(reverse("document-download", args=[document_id]))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_downloading_nonexistent_document_gets_404(self):
        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(
            reverse("document-download", args=["00000000-0000-0000-0000-000000000000"])
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # --- download + access logging (Mandate #2 — no exceptions, including Admin) ---

    def test_owner_can_download_and_access_is_logged(self):
        upload_response = self._upload(self.fellow_user)
        document_id = upload_response.data["id"]

        self.client.force_authenticate(user=self.fellow_user)
        response = self.client.get(reverse("document-download", args=[document_id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(b"".join(response.streaming_content), _PDF_BYTES)

        log = DocumentAccessLog.objects.get(document_id=document_id)
        self.assertEqual(log.accessed_by, self.fellow_user)
        self.assertEqual(log.action, DocumentAccessLog.Action.DOWNLOAD)

    def test_admin_download_is_also_logged(self):
        upload_response = self._upload(self.fellow_user)
        document_id = upload_response.data["id"]

        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(reverse("document-download", args=[document_id]))
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        log = DocumentAccessLog.objects.get(document_id=document_id, accessed_by=self.admin_user)
        self.assertEqual(log.action, DocumentAccessLog.Action.DOWNLOAD)

    def test_missing_private_object_returns_404_without_false_access_log(self):
        document_id = self._upload(self.fellow_user).data["id"]
        self.client.force_authenticate(user=self.fellow_user)
        with patch("apps.documents.views.storage.open_document", side_effect=FileNotFoundError):
            response = self.client.get(reverse("document-download", args=[document_id]))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertFalse(DocumentAccessLog.objects.filter(document_id=document_id).exists())

    def test_storage_read_failure_returns_normalized_502(self):
        document_id = self._upload(self.fellow_user).data["id"]
        self.client.force_authenticate(user=self.fellow_user)
        with patch("apps.documents.views.storage.open_document", side_effect=OSError):
            response = self.client.get(reverse("document-download", args=[document_id]))
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertEqual(response.data["error"]["code"], "download_failed")
        self.assertFalse(DocumentAccessLog.objects.filter(document_id=document_id).exists())
