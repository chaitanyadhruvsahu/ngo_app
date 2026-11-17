from django.urls import path

from apps.jobs.views import JobListCreateView
from apps.reporting.views import (
    AdminVolunteerListView,
    BlockDashboardView,
    ExportHistoryView,
    ExportView,
    FellowDashboardView,
)

urlpatterns = [
    path("admin/jobs", JobListCreateView.as_view(), name="admin-jobs"),
    path("admin/volunteers", AdminVolunteerListView.as_view(), name="admin-volunteers"),
    path("admin/exports", ExportHistoryView.as_view(), name="export-history"),
    path("admin/exports/<str:export_type>", ExportView.as_view(), name="export-file"),
    path("admin/dashboard/blocks", BlockDashboardView.as_view(), name="dashboard-blocks"),
    path("admin/dashboard/fellows/<uuid:fellow_id>", FellowDashboardView.as_view(), name="dashboard-fellow"),
]
