from django.test import SimpleTestCase

from apps.core.logging_filters import scrub


class ScrubSensitiveDataTests(SimpleTestCase):
    def test_scrubs_password_field(self):
        self.assertEqual(scrub('login failed password="hunter2"'), 'login failed password=***')

    def test_scrubs_token_field(self):
        self.assertEqual(scrub("reset token=abc123.def456"), "reset token=***")

    def test_leaves_unrelated_text_untouched(self):
        message = "user_id=42 event=login_succeeded"
        self.assertEqual(scrub(message), message)
