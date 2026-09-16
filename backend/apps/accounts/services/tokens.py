"""Generation, hashing, and validation of the single-use tokens used for
email verification and password reset. The raw token is only ever held in
memory long enough to email it — only its hash is persisted (spec mandate:
"never store or log a raw, usable token").
"""
import hashlib
import secrets
from dataclasses import dataclass

from django.conf import settings
from django.utils import timezone

from apps.accounts.models import AuthToken, User

_TTL_HOURS = {
    AuthToken.Purpose.EMAIL_VERIFY: lambda: settings.EMAIL_VERIFICATION_TOKEN_TTL_HOURS,
    AuthToken.Purpose.PASSWORD_RESET: lambda: settings.PASSWORD_RESET_TOKEN_TTL_HOURS,
}


def _hash_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class IssuedToken:
    raw_token: str
    record: AuthToken


def issue_token(user: User, purpose: str) -> IssuedToken:
    """Invalidate any outstanding token of this purpose for the user, then
    issue a fresh one. Returns the raw token (to email) alongside the
    persisted (hashed) record.
    """
    now = timezone.now()
    AuthToken.objects.filter(user=user, purpose=purpose, used_at__isnull=True).update(used_at=now)

    raw_token = secrets.token_urlsafe(32)
    ttl_hours = _TTL_HOURS[purpose]()
    record = AuthToken.objects.create(
        user=user,
        purpose=purpose,
        token_hash=_hash_token(raw_token),
        expires_at=now + timezone.timedelta(hours=ttl_hours),
    )
    return IssuedToken(raw_token=raw_token, record=record)


def consume_token(raw_token: str, purpose: str) -> AuthToken | None:
    """Looks up a token by its hash for the given purpose and marks it used
    if — and only if — it is currently valid (not expired, not already
    used). Returns None for any invalid/expired/reused/unknown token so
    callers can give a single generic error regardless of which case hit.
    """
    token_hash = _hash_token(raw_token)
    try:
        record = AuthToken.objects.select_related("user").get(
            token_hash=token_hash, purpose=purpose
        )
    except AuthToken.DoesNotExist:
        return None

    now = timezone.now()
    if record.used_at is not None or record.expires_at < now:
        return None

    record.used_at = now
    record.save(update_fields=["used_at"])
    return record
