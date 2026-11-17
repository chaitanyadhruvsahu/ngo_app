from rest_framework import serializers

from apps.documents.models import Document


class DocumentUploadSerializer(serializers.Serializer):
    type = serializers.ChoiceField(choices=Document.DocumentType.choices)
    file = serializers.FileField()


class DocumentSerializer(serializers.ModelSerializer):
    """Never includes `storage_key` — Phase 2 mandate, Mandate #1: no client
    ever receives a raw storage path. Content itself is only reachable via
    `DocumentDownloadView`.
    """

    class Meta:
        model = Document
        fields = [
            "id",
            "type",
            "original_filename",
            "content_type",
            "size_bytes",
            "checksum_sha256",
            "verification_status",
            "uploaded_at",
        ]
        read_only_fields = fields
