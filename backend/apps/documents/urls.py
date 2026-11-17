from django.urls import path

from apps.documents.views import DocumentDownloadView, DocumentListCreateView, DocumentPreviewView

urlpatterns = [
    path("", DocumentListCreateView.as_view(), name="document-list-create"),
    path("<uuid:pk>/download", DocumentDownloadView.as_view(), name="document-download"),
    path("<uuid:pk>/preview", DocumentPreviewView.as_view(), name="document-preview"),
]
