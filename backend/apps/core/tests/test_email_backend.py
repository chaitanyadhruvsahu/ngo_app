import io
import json
from unittest.mock import patch
from urllib.error import HTTPError

from django.core.mail import EmailMessage
from django.test import SimpleTestCase, override_settings

from apps.core.email_backend import EmailDeliveryError, ResendEmailBackend


@override_settings(RESEND_API_KEY="test-only-provider-key", EMAIL_TIMEOUT=15)
class ResendBackendTests(SimpleTestCase):
    def message(self):
        return EmailMessage("Verify your account", "Private link", "team@ngo.test", ["fellow@ngo.test"])

    @patch("apps.core.email_backend.urlopen")
    def test_https_delivery_and_acceptance(self, open_request):
        response = open_request.return_value.__enter__.return_value
        response.status = 200
        response.read.return_value = b'{"id":"accepted-id"}'
        self.assertEqual(ResendEmailBackend().send_messages([self.message()]), 1)
        request = open_request.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.resend.com/emails")
        self.assertEqual(json.loads(request.data)["to"], ["fellow@ngo.test"])
        self.assertEqual(open_request.call_args.kwargs["timeout"], 15)

    @patch("apps.core.email_backend.urlopen")
    def test_provider_error_never_exposes_response_body(self, open_request):
        open_request.side_effect = HTTPError(
            "https://api.resend.com/emails", 401, "private-key", {}, io.BytesIO(b"private")
        )
        with self.assertRaises(EmailDeliveryError) as error:
            ResendEmailBackend().send_messages([self.message()])
        self.assertNotIn("private", str(error.exception))
        self.assertEqual(ResendEmailBackend(fail_silently=True).send_messages([self.message()]), 0)

    @override_settings(RESEND_API_KEY="")
    @patch("apps.core.email_backend.urlopen")
    def test_missing_key_fails_without_network(self, open_request):
        with self.assertRaises(EmailDeliveryError):
            ResendEmailBackend().send_messages([self.message()])
        open_request.assert_not_called()
