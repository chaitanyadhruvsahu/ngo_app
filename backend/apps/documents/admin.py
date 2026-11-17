from django.contrib import admin

from apps.documents.models import Document, DocumentAccessLog


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ["fellow_profile", "type", "superseded_at", "uploaded_at"]
    list_filter = ["type", "verification_status"]
    search_fields = ["fellow_profile__user__email", "original_filename"]
    readonly_fields = ["id", "storage_key", "checksum_sha256", "uploaded_at"]


@admin.register(DocumentAccessLog)
class DocumentAccessLogAdmin(admin.ModelAdmin):
    list_display = ["document", "accessed_by", "action", "accessed_at"]
    list_filter = ["action"]
    readonly_fields = ["id", "document", "accessed_by", "action", "accessed_at"]

    def has_add_permission(self, request):
        return False  # append-only, created by the app only

    def has_change_permission(self, request, obj=None):
        return False
