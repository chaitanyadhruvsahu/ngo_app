import hashlib
import os
import tempfile
import uuid
from unittest import skipUnless
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import urlopen

from botocore.exceptions import ClientError, EndpointConnectionError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings

from apps.documents.services import storage


class LocalStorageTests(SimpleTestCase):
    def test_round_trip_delete_and_collision_preserves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            with override_settings(STORAGE_BACKEND="local", DOCUMENT_STORAGE_ROOT=directory):
                storage._storage.cache_clear()
                self.addCleanup(storage._storage.cache_clear)
                key = storage.build_storage_key(uuid.uuid4(), "photo", "proof.jpg")
                checksum = storage.write_document(key, SimpleUploadedFile("proof.jpg", b"proof"))
                self.assertEqual(checksum, hashlib.sha256(b"proof").hexdigest())
                with self.assertRaises(OSError):
                    storage.write_document(key, SimpleUploadedFile("proof.jpg", b"replacement"))
                with storage.open_document(key) as stream:
                    self.assertEqual(stream.read(), b"proof")
                storage.delete_document(key)
                storage.delete_document(key)
                with self.assertRaises(FileNotFoundError):
                    storage.open_document(key)

    def test_provider_failures_are_normalized(self):
        with patch.object(storage, "_storage") as backend:
            backend.return_value.save.side_effect = EndpointConnectionError(endpoint_url="http://storage")
            with self.assertRaises(OSError):
                storage.write_document("key", SimpleUploadedFile("proof.jpg", b"proof"))
            backend.return_value.open.side_effect = ClientError(
                {"Error": {"Code": "NoSuchKey"}}, "GetObject"
            )
            with self.assertRaises(FileNotFoundError):
                storage.open_document("missing")
            backend.return_value.delete.side_effect = ClientError(
                {"Error": {"Code": "AccessDenied"}}, "DeleteObject"
            )
            with self.assertRaises(OSError):
                storage.delete_document("key")


@skipUnless(os.environ.get("RUN_S3_INTEGRATION") == "1", "Requires a real MinIO endpoint")
class S3IntegrationTests(SimpleTestCase):
    """Real network requests: unique disposable bucket, no mocks or production data."""

    def test_private_documents_and_photos_round_trip(self):
        bucket = f"ngo-storage-test-{uuid.uuid4().hex}"
        with override_settings(STORAGE_BACKEND="s3", S3_BUCKET_NAME=bucket):
            storage._storage.cache_clear()
            backend = storage._storage()
            backend.client.create_bucket(Bucket=bucket)
            keys = []
            try:
                for category in ("aadhaar", "job-photos"):
                    key = storage.build_storage_key(uuid.uuid4(), category, "proof.jpg")
                    keys.append(key)
                    checksum = storage.write_document(key, SimpleUploadedFile("proof.jpg", b"test proof"))
                    self.assertEqual(checksum, hashlib.sha256(b"test proof").hexdigest())
                    with storage.open_document(key) as stream:
                        self.assertEqual(stream.read(), b"test proof")
                    # Append-only storage must not silently replace existing bytes.
                    with self.assertRaises(OSError):
                        storage.write_document(key, SimpleUploadedFile("proof.jpg", b"replacement"))
                    with storage.open_document(key) as stream:
                        self.assertEqual(stream.read(), b"test proof")
                    url = f"{backend.client.meta.endpoint_url}/{bucket}/{key}"
                    with self.assertRaises(HTTPError) as denied:
                        urlopen(url, timeout=5)
                    self.assertEqual(denied.exception.code, 403)
                    storage.delete_document(key)
                    storage.delete_document(key)
                    with self.assertRaises(FileNotFoundError):
                        storage.open_document(key)
            finally:
                for key in keys:
                    backend.delete(key)
                backend.client.delete_bucket(Bucket=bucket)
                storage._storage.cache_clear()
