from django.core.management import call_command
from django.test import TestCase

from apps.accounts.models import User


class SeedAdminCommandTests(TestCase):
    def test_creates_active_admin_from_env(self, monkeypatch=None):
        import os

        os.environ["ADMIN_EMAIL"] = "seed-admin@example.com"
        os.environ["ADMIN_PASSWORD"] = "a-strong-admin-password-1"
        try:
            call_command("seed_admin")
        finally:
            del os.environ["ADMIN_EMAIL"]
            del os.environ["ADMIN_PASSWORD"]

        admin = User.objects.get(email="seed-admin@example.com")
        self.assertEqual(admin.role, User.Role.ADMIN)
        self.assertEqual(admin.status, User.Status.ACTIVE)
        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)
        self.assertTrue(admin.check_password("a-strong-admin-password-1"))

    def test_rerunning_updates_password_idempotently(self):
        import os

        os.environ["ADMIN_EMAIL"] = "seed-admin2@example.com"
        os.environ["ADMIN_PASSWORD"] = "first-password-1"
        try:
            call_command("seed_admin")
            os.environ["ADMIN_PASSWORD"] = "second-password-1"
            call_command("seed_admin")
        finally:
            del os.environ["ADMIN_EMAIL"]
            del os.environ["ADMIN_PASSWORD"]

        self.assertEqual(User.objects.filter(email="seed-admin2@example.com").count(), 1)
        admin = User.objects.get(email="seed-admin2@example.com")
        self.assertTrue(admin.check_password("second-password-1"))
