from urllib.parse import parse_qs, urlparse

from django.core import mail
from django.core.cache import cache
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import AuthToken, FellowProfile, User
from apps.accounts.services.tokens import issue_token


def _extract_token_from_email(message) -> str:
    link = message.body.strip().splitlines()[-1]
    query = parse_qs(urlparse(link).query)
    return query["token"][0]


class SignupVerifyLoginRefreshLogoutFlowTests(APITestCase):
    def setUp(self):
        cache.clear()

    def test_full_flow(self):
        # 1. Sign up.
        signup_response = self.client.post(
            reverse("auth-signup"),
            {"email": "newfellow@example.com", "password": "correct-horse-battery-1"},
        )
        self.assertEqual(signup_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(mail.outbox), 1)

        user = User.objects.get(email="newfellow@example.com")
        self.assertEqual(user.status, User.Status.PENDING_VERIFICATION)
        self.assertTrue(FellowProfile.objects.filter(user=user).exists())

        # Cannot log in before verifying.
        premature_login = self.client.post(
            reverse("auth-login"),
            {"email": "newfellow@example.com", "password": "correct-horse-battery-1"},
        )
        self.assertEqual(premature_login.status_code, status.HTTP_401_UNAUTHORIZED)

        # 2. Verify email.
        token = _extract_token_from_email(mail.outbox[0])
        verify_response = self.client.post(reverse("auth-verify-email"), {"token": token})
        self.assertEqual(verify_response.status_code, status.HTTP_200_OK)

        user.refresh_from_db()
        self.assertEqual(user.status, User.Status.ACTIVE)
        self.assertEqual(
            user.fellow_profile.onboarding_step, FellowProfile.OnboardingStep.EMAIL_VERIFIED
        )

        # A used verification token cannot be replayed.
        replay_response = self.client.post(reverse("auth-verify-email"), {"token": token})
        self.assertEqual(replay_response.status_code, status.HTTP_400_BAD_REQUEST)

        # 3. Log in.
        login_response = self.client.post(
            reverse("auth-login"),
            {"email": "newfellow@example.com", "password": "correct-horse-battery-1"},
        )
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertEqual(login_response.data["role"], "fellow")
        access_token = login_response.data["access_token"]
        refresh_token = login_response.data["refresh_token"]
        self.assertTrue(access_token)
        self.assertTrue(refresh_token)

        # 4. Refresh.
        refresh_response = self.client.post(reverse("auth-refresh"), {"refresh_token": refresh_token})
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        new_access_token = refresh_response.data["access_token"]
        new_refresh_token = refresh_response.data["refresh_token"]
        self.assertTrue(new_access_token)
        self.assertTrue(new_refresh_token)
        self.assertNotEqual(new_refresh_token, refresh_token)

        # 5. Logout with the rotated refresh token.
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {new_access_token}")
        logout_response = self.client.post(reverse("auth-logout"), {"refresh_token": new_refresh_token})
        self.assertEqual(logout_response.status_code, status.HTTP_204_NO_CONTENT)

        # The blacklisted refresh token can no longer be used.
        post_logout_refresh = self.client.post(
            reverse("auth-refresh"), {"refresh_token": new_refresh_token}
        )
        self.assertEqual(post_logout_refresh.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_with_wrong_password_is_generic_401(self):
        User.objects.create_user(
            email="known@example.com", password="correct-horse-battery-1", status=User.Status.ACTIVE
        )
        response = self.client.post(
            reverse("auth-login"), {"email": "known@example.com", "password": "wrong-password"}
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(response.data["error"]["code"], "invalid_credentials")

    def test_login_with_unknown_email_is_identical_generic_401(self):
        known_response = self.client.post(
            reverse("auth-login"), {"email": "ghost@example.com", "password": "whatever-1234"}
        )
        self.assertEqual(known_response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(known_response.data["error"]["code"], "invalid_credentials")

    def test_signup_with_already_registered_email_returns_same_generic_response(self):
        User.objects.create_user(email="taken@example.com", password="correct-horse-battery-1")

        response = self.client.post(
            reverse("auth-signup"), {"email": "taken@example.com", "password": "another-password-1"}
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # No second account created, and no email sent for the existing address.
        self.assertEqual(User.objects.filter(email="taken@example.com").count(), 1)
        self.assertEqual(len(mail.outbox), 0)


class PasswordResetFlowTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(
            email="reset@example.com", password="original-password-1", status=User.Status.ACTIVE
        )

    def test_password_reset_flow_invalidates_outstanding_refresh_tokens(self):
        login_response = self.client.post(
            reverse("auth-login"), {"email": "reset@example.com", "password": "original-password-1"}
        )
        old_refresh_token = login_response.data["refresh_token"]

        request_response = self.client.post(
            reverse("auth-password-reset-request"), {"email": "reset@example.com"}
        )
        self.assertEqual(request_response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(len(mail.outbox), 1)

        token = _extract_token_from_email(mail.outbox[0])
        confirm_response = self.client.post(
            reverse("auth-password-reset-confirm"),
            {"token": token, "new_password": "brand-new-password-1"},
        )
        self.assertEqual(confirm_response.status_code, status.HTTP_200_OK)

        # Old password no longer works, new one does.
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("brand-new-password-1"))
        self.assertFalse(self.user.check_password("original-password-1"))

        # The refresh token issued before the reset is now blacklisted.
        refresh_attempt = self.client.post(
            reverse("auth-refresh"), {"refresh_token": old_refresh_token}
        )
        self.assertEqual(refresh_attempt.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_password_reset_request_is_generic_for_unknown_email(self):
        response = self.client.post(
            reverse("auth-password-reset-request"), {"email": "unknown@example.com"}
        )
        self.assertEqual(response.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(len(mail.outbox), 0)

    def test_reused_reset_token_is_rejected(self):
        issued = issue_token(self.user, AuthToken.Purpose.PASSWORD_RESET)
        first = self.client.post(
            reverse("auth-password-reset-confirm"),
            {"token": issued.raw_token, "new_password": "brand-new-password-1"},
        )
        self.assertEqual(first.status_code, status.HTTP_200_OK)

        second = self.client.post(
            reverse("auth-password-reset-confirm"),
            {"token": issued.raw_token, "new_password": "another-password-2"},
        )
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(second.data["error"]["code"], "invalid_token")
