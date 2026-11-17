import uuid

from django.db import models

from apps.accounts.models import FellowProfile, User


class Document(models.Model):
    """Metadata for an uploaded document. The actual file bytes live in
    object storage (ADR-0009) — `storage_key` is an internal path, never
    exposed to a client directly (Phase 2 mandate, Mandate #1). All reads
    go through `DocumentDownloadView`, which streams the file back after an
    ownership/role check and logs the access (`DocumentAccessLog`).
    """

    class DocumentType(models.TextChoices):
        AADHAAR = "aadhaar", "Aadhaar"
        MARKSHEET = "marksheet", "Marksheet"
        BANK_STATEMENT = "bank_statement", "Bank statement"
        PHOTO = "photo", "Photo"
        OTHER = "other", "Other"

    class VerificationStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        VERIFIED = "verified", "Verified"
        REJECTED = "rejected", "Rejected"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    fellow_profile = models.ForeignKey(FellowProfile, on_delete=models.CASCADE, related_name="documents")
    type = models.CharField(max_length=32, choices=DocumentType.choices)
    storage_key = models.CharField(max_length=512)
    original_filename = models.CharField(max_length=255)
    content_type = models.CharField(max_length=127)
    size_bytes = models.PositiveBigIntegerField()
    checksum_sha256 = models.CharField(max_length=64)
    # Nullable: room for the optional govt. Aadhaar-verification add-on
    # (Phase 2 mandate) without a future migration. Not set by anything in
    # this phase.
    verification_status = models.CharField(
        max_length=16, choices=VerificationStatus.choices, null=True, blank=True
    )
    # A new upload of the same type supersedes the old one rather than
    # overwriting it (Phase 2 mandate, Assumption 2) — soft-replace keeps
    # an audit trail. Non-superseded == "current".
    superseded_at = models.DateTimeField(null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-uploaded_at"]
        indexes = [
            models.Index(
                fields=["fellow_profile", "type", "superseded_at"],
                name="idx_doc_fellow_type_current",
            ),
        ]

    def __str__(self) -> str:
        return f"Document({self.type}, fellow={self.fellow_profile_id})"


class DocumentAccessLog(models.Model):
    """Append-only. Every document view/download is logged here — including
    Admin access, no exceptions (Phase 2 mandate, Mandate #2 / Security).
    """

    class Action(models.TextChoices):
        VIEW = "view", "View"
        DOWNLOAD = "download", "Download"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name="access_logs")
    accessed_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="document_access_logs")
    action = models.CharField(max_length=16, choices=Action.choices)
    accessed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-accessed_at"]

    def __str__(self) -> str:
        return f"DocumentAccessLog({self.action}, doc={self.document_id}, by={self.accessed_by_id})"
