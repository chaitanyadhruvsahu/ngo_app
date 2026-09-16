from django.test import TestCase
from django.utils import timezone

from apps.accounts.models import AuthToken, FellowProfile, User


class UserModelTests(TestCase):
    def test_create_user_defaults_to_fellow_pending_verification(self):
        user = User.objects.create_user(email="fellow@example.com", password="a-strong-password-1")
        self.assertEqual(user.role, User.Role.FELLOW)
        self.assertEqual(user.status, User.Status.PENDING_VERIFICATION)
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_create_superuser_defaults_to_admin_active(self):
        admin = User.objects.create_superuser(email="admin@example.com", password="a-strong-password-1")
        self.assertEqual(admin.role, User.Role.ADMIN)
        self.assertEqual(admin.status, User.Status.ACTIVE)
        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)

    def test_email_is_always_lowercased(self):
        user = User.objects.create_user(email="MixedCase@Example.com", password="a-strong-password-1")
        self.assertEqual(user.email, "mixedcase@example.com")

    def test_disabled_user_is_not_active(self):
        user = User.objects.create_user(email="disabled@example.com", password="a-strong-password-1")
        user.status = User.Status.DISABLED
        user.save(update_fields=["status"])
        self.assertFalse(user.is_active)

    def test_active_user_is_active(self):
        user = User.objects.create_user(email="active@example.com", password="a-strong-password-1")
        user.status = User.Status.ACTIVE
        user.save(update_fields=["status"])
        self.assertTrue(user.is_active)

    def test_password_is_hashed_not_plaintext(self):
        user = User.objects.create_user(email="hash@example.com", password="a-strong-password-1")
        self.assertNotEqual(user.password, "a-strong-password-1")
        self.assertTrue(user.check_password("a-strong-password-1"))


class FellowProfileModelTests(TestCase):
    def test_default_onboarding_step_is_account_created(self):
        user = User.objects.create_user(email="fellow2@example.com", password="a-strong-password-1")
        profile = FellowProfile.objects.create(user=user)
        self.assertEqual(profile.onboarding_step, FellowProfile.OnboardingStep.ACCOUNT_CREATED)


class AuthTokenModelTests(TestCase):
    def test_is_used_reflects_used_at(self):
        user = User.objects.create_user(email="tok@example.com", password="a-strong-password-1")
        token = AuthToken.objects.create(
            user=user,
            purpose=AuthToken.Purpose.EMAIL_VERIFY,
            token_hash="abc123",
            expires_at=timezone.now() + timezone.timedelta(hours=1),
        )
        self.assertFalse(token.is_used)
        token.used_at = timezone.now()
        token.save(update_fields=["used_at"])
        self.assertTrue(token.is_used)
