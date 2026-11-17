"""Transactional email over HTTPS, supported on Railway's non-SMTP plans."""
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend


class EmailDeliveryError(RuntimeError):
    """Provider failure without response bodies, tokens or recipient details."""


class ResendEmailBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        sent = 0
        for message in email_messages or []:
            if not message.recipients():
                continue
            try:
                if not settings.RESEND_API_KEY:
                    raise EmailDeliveryError("Transactional email is not configured.")
                if message.attachments:
                    raise EmailDeliveryError("Transactional email attachments are unsupported.")
                payload = {
                    "from": message.from_email, "to": message.to,
                    "subject": message.subject, "text": message.body,
                }
                for field in ("cc", "bcc", "reply_to"):
                    value = getattr(message, field)
                    if value:
                        payload[field] = value
                for alternative in getattr(message, "alternatives", []):
                    if alternative[1] == "text/html":
                        payload["html"] = alternative[0]
                request = Request(
                    "https://api.resend.com/emails",
                    data=json.dumps(payload).encode(), method="POST",
                    headers={"Authorization": f"Bearer {settings.RESEND_API_KEY}",
                             "Content-Type": "application/json", "User-Agent": "NGO-App/0.1"},
                )
                with urlopen(request, timeout=settings.EMAIL_TIMEOUT) as response:
                    result = json.load(response)
                    if not 200 <= response.status < 300 or not result.get("id"):
                        raise EmailDeliveryError("Email provider did not accept the message.")
                sent += 1
            except (HTTPError, URLError, OSError, ValueError, EmailDeliveryError):
                if not self.fail_silently:
                    raise EmailDeliveryError("Email delivery failed. Please try again later.") from None
        return sent
