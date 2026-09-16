from django.conf import settings
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthCheckView(APIView):
    """Unauthenticated liveness endpoint. Deliberately returns nothing about
    internal state — no stack traces, no environment name, no DB connection
    details — per the Phase 0 mandate. Doubles as the uptime-monitor target.
    """

    permission_classes = [AllowAny]
    throttle_classes = []

    def get(self, request):
        return Response(
            {
                "status": "ok",
                "version": settings.GIT_SHA,
                "time": timezone.now().isoformat(),
            }
        )
