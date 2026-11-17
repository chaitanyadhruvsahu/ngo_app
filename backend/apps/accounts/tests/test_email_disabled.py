import os
from unittest.mock import patch

from django.core import mail
from django.core.management import call_command
from django.test import TestCase, override_settings

from apps.accounts.models import AuthToken, User


@override_settings(EMAIL_AUTH_ENABLED=False)
class EmailDisabledTests(TestCase):
    def test_all_email_flows_block_without_side_effects(self):
        for path in ("signup", "verify-email", "resend-verification",
                     "password-reset/request", "password-reset/confirm"):
            response = self.client.post(f"/api/v1/auth/{path}", {
                "email": "someone@example.org", "password": "long-password-example",
            })
            self.assertEqual(response.status_code, 503, path)
            self.assertEqual(response.json()["error"]["code"], "email_auth_disabled")
        self.assertEqual(User.objects.count(), 0)
        self.assertEqual(AuthToken.objects.count(), 0)
        self.assertEqual(len(mail.outbox), 0)

    def test_config_and_existing_account_login(self):
        self.assertFalse(self.client.get("/api/v1/config").json()["email_auth_enabled"])
        User.objects.create_user(email="pilot@example.org", password="correct-long-password", status="active")
        response = self.client.post("/api/v1/auth/login", {
            "email": "pilot@example.org", "password": "correct-long-password",
        })
        self.assertEqual(response.status_code, 200)

    def test_bootstrap_never_resets_existing_account(self):
        with patch.dict(os.environ, {
            "PILOT_ADMIN_EMAIL": "pilot-admin@example.org",
            "PILOT_ADMIN_PASSWORD": "initial-long-random-password",
        }):
            call_command("bootstrap_pilot")
            user = User.objects.get(email="pilot-admin@example.org")
            user.set_password("changed-long-password")
            user.save()
            call_command("bootstrap_pilot")
            user.refresh_from_db()
            self.assertTrue(user.check_password("changed-long-password"))
