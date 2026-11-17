"""Thin seam around outbound transactional email so swapping providers
later (Resend/Postmark/SendGrid) is a one-file change, and so tests can
assert on what would have been sent without hitting a real provider.
Locally/in CI this goes through Django's console email backend; a future
phase can point EMAIL_BACKEND at a real SMTP/API-based backend without any
caller of EmailService changing.
"""
import logging
from urllib.parse import urlencode

from django.conf import settings
from django.core.mail import send_mail

from apps.accounts.models import User

logger = logging.getLogger(__name__)


class EmailService:
    @staticmethod
    def send_verification_email(user: User, raw_token: str) -> None:
        link = f"{settings.FRONTEND_BASE_URL.rstrip('/')}/#/verify-email?{urlencode({'token': raw_token})}"
        send_mail(
            subject="Verify your account",
            message=f"Confirm your email to activate your account:\n\n{link}",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
        logger.info("email_verification_sent", extra={"user_id": str(user.id)})

    @staticmethod
    def send_password_reset_email(user: User, raw_token: str) -> None:
        link = (
            f"{settings.FRONTEND_BASE_URL.rstrip('/')}/#/reset-password/confirm?"
            f"{urlencode({'token': raw_token})}"
        )
        send_mail(
            subject="Reset your password",
            message=f"Reset your password using this link:\n\n{link}",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
        logger.info("password_reset_email_sent", extra={"user_id": str(user.id)})
