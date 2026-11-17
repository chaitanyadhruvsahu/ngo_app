from unittest.mock import patch

from django.db import DatabaseError
from django.test import TestCase, override_settings
from django.urls import reverse

from apps.core.checks import production_configuration


class ReleaseTests(TestCase):
    def test_readiness_is_public(self):
        response = self.client.get(reverse("readiness-check"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_readiness_hides_database_failure(self):
        with patch("apps.core.views.connection.cursor", side_effect=DatabaseError("secret connection")):
            response = self.client.get(reverse("readiness-check"))
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"status": "unavailable"})

    @override_settings(PRODUCTION=True, SECRET_KEY="unsafe-development", ALLOWED_HOSTS=["*"],
                       FRONTEND_BASE_URL="http://localhost", STORAGE_BACKEND="local")
    def test_production_rejects_development_configuration(self):
        messages = [error.msg for error in production_configuration(None)]
        self.assertTrue(any("SECRET_KEY" in message for message in messages))
        self.assertTrue(any("ALLOWED_HOSTS" in message for message in messages))
        self.assertTrue(any("HTTPS origin" in message for message in messages))
        self.assertTrue(any("ephemeral" in message for message in messages))
