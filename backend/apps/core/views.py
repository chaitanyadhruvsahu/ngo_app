from django.conf import settings
from django.db import DatabaseError, connection
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


class ReadinessView(APIView):
    """Load-balancer readiness without disclosing database details."""
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = []

    def get(self, request):
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
        except DatabaseError:
            return Response({"status": "unavailable"}, status=503)
        return Response({"status": "ok"})


class PublicConfigView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = []

    def get(self, request):
        response = Response({"email_auth_enabled": settings.EMAIL_AUTH_ENABLED})
        response["Cache-Control"] = "no-store"
        return response
