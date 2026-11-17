"""Private backend-proxied storage shared by documents and job photos.

The application persists opaque keys, never public URLs. Backend failures are
OSError so callers can roll back metadata and clean up earlier batch writes.
"""
import hashlib
import uuid
from functools import lru_cache
from pathlib import PurePosixPath

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.core.files.storage import FileSystemStorage
from django.core.files.uploadedfile import UploadedFile


class S3Storage:
    def __init__(self):
        self.bucket = settings.S3_BUCKET_NAME
        self.client = boto3.client(
            "s3", endpoint_url=settings.S3_ENDPOINT_URL or None,
            region_name=settings.S3_REGION_NAME,
            aws_access_key_id=settings.S3_ACCESS_KEY_ID or None,
            aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY or None,
            config=Config(
                signature_version="s3v4", s3={"addressing_style": settings.S3_ADDRESSING_STYLE},
                connect_timeout=5, read_timeout=30, retries={"mode": "standard", "max_attempts": 2},
                request_checksum_calculation="when_required",
                response_checksum_validation="when_required",
            ),
        )

    def save(self, key, content):
        # Conditional creation protects append-only history from accidental overwrites.
        self.client.put_object(Bucket=self.bucket, Key=key, Body=content, IfNoneMatch="*")
        return key

    def open(self, key, mode="rb"):
        return self.client.get_object(Bucket=self.bucket, Key=key)["Body"]

    def delete(self, key):
        self.client.delete_object(Bucket=self.bucket, Key=key)


@lru_cache(maxsize=1)
def _storage():
    if settings.STORAGE_BACKEND == "local":
        return FileSystemStorage(location=str(settings.DOCUMENT_STORAGE_ROOT))
    if settings.STORAGE_BACKEND == "s3":
        return S3Storage()
    raise ImproperlyConfigured("Unknown STORAGE_BACKEND")


def build_storage_key(fellow_profile_id, document_type: str, filename: str) -> str:
    filename = PurePosixPath(filename.replace("\\", "/")).name
    return f"{fellow_profile_id}/{document_type}/{uuid.uuid4()}-{filename}"


def write_document(storage_key: str, uploaded_file: UploadedFile) -> str:
    """Write bytes before creating metadata; return their SHA-256 checksum."""
    digest = hashlib.sha256()
    uploaded_file.seek(0)
    for chunk in uploaded_file.chunks():
        digest.update(chunk)
    uploaded_file.seek(0)
    try:
        saved_key = _storage().save(storage_key, uploaded_file)
        if saved_key != storage_key:
            _storage().delete(saved_key)
            raise OSError("Storage key collision")
    except (BotoCoreError, ClientError) as exc:
        raise OSError("Could not store file") from exc
    return digest.hexdigest()


def open_document(storage_key: str):
    try:
        return _storage().open(storage_key, "rb")
    except ClientError as exc:
        if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
            raise FileNotFoundError("Stored file missing") from exc
        raise OSError("Could not read stored file") from exc
    except BotoCoreError as exc:
        raise OSError("Could not read stored file") from exc


def delete_document(storage_key: str):
    """Remove an uncommitted upload during rollback; missing keys are harmless."""
    try:
        _storage().delete(storage_key)
    except (BotoCoreError, ClientError) as exc:
        raise OSError("Could not remove stored file") from exc
