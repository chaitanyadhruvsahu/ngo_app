from django.urls import path

from apps.notifications.views import AdminNotificationsView, MineView, RecipientActionView, TargetsView

urlpatterns = [
    path("admin/notifications/targets", TargetsView.as_view(), name="notification-targets"),
    path("admin/notifications", AdminNotificationsView.as_view(), name="admin-notifications"),
    path("notifications/mine", MineView.as_view(), name="notification-mine"),
    path(
        "notifications/<uuid:pk>/read", RecipientActionView.as_view(action="read"), name="notification-read"
    ),
    path(
        "notifications/<uuid:pk>/dismiss",
        RecipientActionView.as_view(action="dismiss"),
        name="notification-dismiss",
    ),
]
