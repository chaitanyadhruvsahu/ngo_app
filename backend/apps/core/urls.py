from django.urls import path

from apps.core.views import HealthCheckView, ReadinessView

urlpatterns = [
    path("health", HealthCheckView.as_view(), name="health-check"),
    path("ready", ReadinessView.as_view(), name="readiness-check"),
]
