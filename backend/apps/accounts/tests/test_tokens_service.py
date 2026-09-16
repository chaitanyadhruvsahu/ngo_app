from django.test import TestCase
from freezegun import freeze_time

from apps.accounts.models import AuthToken, User
from apps.accounts.services.tokens import consume_token, issue_token


class TokenServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="tokens@example.com", password="a-strong-password-1")

    def test_issue_token_persists_only_the_hash(self):
        issued = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)
        self.assertNotEqual(issued.record.token_hash, issued.raw_token)
        self.assertTrue(len(issued.raw_token) > 20)

    def test_consume_token_succeeds_exactly_once(self):
        issued = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)

        record = consume_token(issued.raw_token, AuthToken.Purpose.EMAIL_VERIFY)
        self.assertIsNotNone(record)
        self.assertEqual(record.user_id, self.user.id)

        # Reusing the same (now-used) token must fail.
        reused = consume_token(issued.raw_token, AuthToken.Purpose.EMAIL_VERIFY)
        self.assertIsNone(reused)

    def test_consume_token_fails_for_unknown_token(self):
        self.assertIsNone(consume_token("not-a-real-token", AuthToken.Purpose.EMAIL_VERIFY))

    def test_consume_token_fails_for_wrong_purpose(self):
        issued = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)
        self.assertIsNone(consume_token(issued.raw_token, AuthToken.Purpose.PASSWORD_RESET))

    def test_expired_token_cannot_be_consumed(self):
        with freeze_time("2026-01-01 00:00:00"):
            issued = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)

        with freeze_time("2026-01-02 01:00:00"):  # well past the 24h TTL
            self.assertIsNone(consume_token(issued.raw_token, AuthToken.Purpose.EMAIL_VERIFY))

    def test_issuing_a_new_token_invalidates_prior_outstanding_ones(self):
        first = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)
        issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)

        self.assertIsNone(consume_token(first.raw_token, AuthToken.Purpose.EMAIL_VERIFY))

    def test_password_reset_token_does_not_collide_with_email_verify(self):
        verify = issue_token(self.user, AuthToken.Purpose.EMAIL_VERIFY)
        reset = issue_token(self.user, AuthToken.Purpose.PASSWORD_RESET)

        self.assertIsNotNone(consume_token(verify.raw_token, AuthToken.Purpose.EMAIL_VERIFY))
        self.assertIsNotNone(consume_token(reset.raw_token, AuthToken.Purpose.PASSWORD_RESET))
