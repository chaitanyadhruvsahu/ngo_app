from django.urls import path

from apps.core.views import HealthCheckView, PublicConfigView, ReadinessView

urlpatterns = [
    path("config", PublicConfigView.as_view(), name="public-config"),
    path("health", HealthCheckView.as_view(), name="health-check"),
    path("ready", ReadinessView.as_view(), name="readiness-check"),
]
