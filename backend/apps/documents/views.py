from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import FellowProfile
from apps.accounts.permissions import IsAdmin, IsFellow
from apps.core.exceptions import error_response
from apps.documents.models import Document, DocumentAccessLog
from apps.documents.serializers import DocumentSerializer, DocumentUploadSerializer
from apps.documents.services import storage
from apps.documents.services.validation import UploadValidationError, sniff_content_type, validate_size


class DocumentListCreateView(APIView):
    """Own documents only. A new upload of an existing type supersedes the
    previous one rather than overwriting it (Phase 2 mandate, Assumption 2).
    """

    permission_classes = [IsFellow]
    parser_classes = [MultiPartParser]

    def get(self, request):
        documents = Document.objects.filter(
            fellow_profile=request.user.fellow_profile, superseded_at__isnull=True
        )
        return Response(DocumentSerializer(documents, many=True).data)

    def post(self, request):
        serializer = DocumentUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        uploaded_file = serializer.validated_data["file"]
        document_type = serializer.validated_data["type"]

        try:
            validate_size(uploaded_file)
            content_type = sniff_content_type(uploaded_file)
        except UploadValidationError as exc:
            return error_response(exc.code, exc.message, status.HTTP_400_BAD_REQUEST)

        fellow_profile = request.user.fellow_profile
        storage_key = storage.build_storage_key(fellow_profile.id, document_type, uploaded_file.name)

        # Storage write happens before the DB row is created — no orphaned
        # metadata pointing at a file that was never actually written
        # (Phase 2 mandate, Reliability).
        try:
            checksum = storage.write_document(storage_key, uploaded_file)
        except OSError:
            return error_response(
                "upload_failed", "Could not store the file. Please try again.", status.HTTP_502_BAD_GATEWAY
            )

        previous_current = Document.objects.filter(
            fellow_profile=fellow_profile, type=document_type, superseded_at__isnull=True
        )
        previous_current.update(superseded_at=timezone.now())

        document = Document.objects.create(
            fellow_profile=fellow_profile,
            type=document_type,
            storage_key=storage_key,
            original_filename=uploaded_file.name,
            content_type=content_type,
            size_bytes=uploaded_file.size,
            checksum_sha256=checksum,
        )
        return Response(DocumentSerializer(document).data, status=status.HTTP_201_CREATED)


class DocumentDownloadView(APIView):
    """Fellow can download their own; Admin can download anyone's
    (read-only visibility, Phase 2 mandate §D). Every access is logged,
    including Admin's (Mandate #2 — no exceptions). A document that exists
    but isn't the caller's returns 404, never 403 (Mandate #5).
    """

    permission_classes = [IsAuthenticated]
    as_attachment = True
    access_action = DocumentAccessLog.Action.DOWNLOAD

    def get(self, request, pk):
        document = get_object_or_404(Document, pk=pk)
        is_owner = document.fellow_profile.user_id == request.user.id
        is_admin = request.user.role == request.user.Role.ADMIN
        if not (is_owner or is_admin):
            raise Http404

        try:
            file_handle = storage.open_document(document.storage_key)
        except FileNotFoundError:
            # Do not expose whether metadata or the private object disappeared.
            raise Http404 from None
        except OSError:
            return error_response(
                "download_failed",
                "Could not retrieve the file. Please try again.",
                status.HTTP_502_BAD_GATEWAY,
            )
        DocumentAccessLog.objects.create(
            document=document, accessed_by=request.user, action=self.access_action
        )
        response = FileResponse(
            file_handle,
            content_type=document.content_type,
            as_attachment=self.as_attachment,
            filename=document.original_filename,
        )
        response["Cache-Control"] = "private, no-store"
        response["X-Content-Type-Options"] = "nosniff"
        return response


class DocumentPreviewView(DocumentDownloadView):
    """Same private-file authorization as downloads, separately audited as a view."""

    as_attachment = False
    access_action = DocumentAccessLog.Action.VIEW


class AdminFellowDocumentListView(APIView):
    """Read-only, Admin-only. Lists a specific fellow's current (non-superseded)
    documents; downloads still go through `DocumentDownloadView` above with
    the same Admin-scoped permission check.
    """

    permission_classes = [IsAdmin]

    def get(self, request, fellow_id):
        fellow_profile = get_object_or_404(FellowProfile, pk=fellow_id)
        documents = Document.objects.filter(fellow_profile=fellow_profile, superseded_at__isnull=True)
        return Response(DocumentSerializer(documents, many=True).data)
