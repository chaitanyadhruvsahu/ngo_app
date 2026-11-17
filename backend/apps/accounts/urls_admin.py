"""Admin-facing, read-only endpoints (Phase 2 mandate §H). Lives in
apps.accounts since `/admin/fellows` is the root resource, but imports
views from apps.documents / apps.volunteers for the nested list endpoints
— those apps already depend on apps.accounts at the model level (FKs to
FellowProfile), so this is a one-directional addition, not a new cycle.
"""
from django.urls import path

from apps.accounts.views_admin import AdminFellowDetailView, AdminFellowListView
from apps.documents.views import AdminFellowDocumentListView
from apps.volunteers.views import AdminFellowVolunteerListView

urlpatterns = [
    path("fellows", AdminFellowListView.as_view(), name="admin-fellow-list"),
    path("fellows/<uuid:fellow_id>", AdminFellowDetailView.as_view(), name="admin-fellow-detail"),
    path(
        "fellows/<uuid:fellow_id>/documents",
        AdminFellowDocumentListView.as_view(),
        name="admin-fellow-documents",
    ),
    path(
        "fellows/<uuid:fellow_id>/volunteers",
        AdminFellowVolunteerListView.as_view(),
        name="admin-fellow-volunteers",
    ),
]
