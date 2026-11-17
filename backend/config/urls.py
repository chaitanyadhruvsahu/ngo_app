from django.contrib import admin
from django.urls import include, path

from apps.accounts.views_profile import BlockListView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("apps.core.urls")),
    path("api/v1/", include("apps.jobs.urls")),
    path("api/v1/", include("apps.notifications.urls")),
    path("api/v1/", include("apps.reporting.urls")),
    path("api/v1/auth/", include("apps.accounts.urls")),
    path("api/v1/profile/", include("apps.accounts.urls_profile")),
    path("api/v1/admin/", include("apps.accounts.urls_admin")),
    path("api/v1/documents/", include("apps.documents.urls")),
    path("api/v1/volunteers/", include("apps.volunteers.urls")),
    # Shared reference data — not owned by any one app's feature scope.
    path("api/v1/blocks", BlockListView.as_view(), name="block-list"),
]
