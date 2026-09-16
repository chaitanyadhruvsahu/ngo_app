from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase


class HealthCheckTests(APITestCase):
    def test_health_check_returns_ok_without_auth(self):
        response = self.client.get(reverse("health-check"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], "ok")
        self.assertIn("version", response.data)
        self.assertIn("time", response.data)

    def test_health_check_never_leaks_internal_state(self):
        response = self.client.get(reverse("health-check"))
        body_keys = set(response.data.keys())
        self.assertEqual(body_keys, {"status", "version", "time"})
