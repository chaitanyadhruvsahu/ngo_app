from django.core.cache import cache
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User


class RateLimitTests(APITestCase):
    def setUp(self):
        cache.clear()

    def test_login_endpoint_is_rate_limited_per_ip(self):
        User.objects.create_user(
            email="ratelimit@example.com", password="correct-horse-battery-1", status=User.Status.ACTIVE
        )
        url = reverse("auth-login")
        payload = {"email": "ratelimit@example.com", "password": "wrong-password"}

        # THROTTLE_AUTH_SENSITIVE defaults to 5/min in settings.
        for _ in range(5):
            response = self.client.post(url, payload)
            self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

        throttled_response = self.client.post(url, payload)
        self.assertEqual(throttled_response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_signup_endpoint_is_rate_limited_per_ip(self):
        url = reverse("auth-signup")

        for i in range(5):
            response = self.client.post(url, {"email": f"user{i}@example.com", "password": "x" * 12})
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        throttled_response = self.client.post(
            url, {"email": "one-too-many@example.com", "password": "x" * 12}
        )
        self.assertEqual(throttled_response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)


class InjectionRegressionTests(APITestCase):
    """The ORM already parameterizes every query, so these are a guard
    against a future raw-query mistake rather than a real vulnerability
    today.
    """

    def setUp(self):
        cache.clear()

    def test_sql_injection_style_email_is_safely_rejected(self):
        response = self.client.post(
            reverse("auth-login"),
            {"email": "' OR '1'='1", "password": "irrelevant"},
        )
        # Fails EmailField validation — never reaches a query at all.
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"]["code"], "invalid")

    def test_sql_injection_style_password_does_not_bypass_auth(self):
        User.objects.create_user(
            email="injection-target@example.com",
            password="correct-horse-battery-1",
            status=User.Status.ACTIVE,
        )
        response = self.client.post(
            reverse("auth-login"),
            {"email": "injection-target@example.com", "password": "' OR '1'='1"},
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
