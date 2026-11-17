"""Application-level field encryption for structured sensitive data
(Aadhaar/bank columns — see docs/adr/0008-field-encryption.md and
docs/adr/0010-key-rotation.md).

`django-cryptography` was evaluated first but is incompatible with Django
5.1 (it imports `django.utils.baseconv`, removed in Django 4.0), so this
wraps the `cryptography` package's Fernet implementation directly instead
— one well-audited primitive, no compatibility risk from an unmaintained
wrapper package.
"""
from functools import lru_cache

from cryptography.fernet import Fernet, InvalidToken, MultiFernet
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import models


def parse_field_encryption_keys(raw: str) -> list[bytes]:
    """`FIELD_ENCRYPTION_KEY` is comma-separated: the *first* key is used
    for encryption (new writes); every key is tried for decryption, oldest
    last. This is what makes rotation possible without a big-bang
    migration — see docs/adr/0010-key-rotation.md and
    `manage.py rotate_encryption_key`.
    """
    return [key.strip().encode() for key in raw.split(",") if key.strip()]


@lru_cache(maxsize=1)
def _fernet() -> MultiFernet:
    raw = getattr(settings, "FIELD_ENCRYPTION_KEY", None)
    if not raw:
        raise ImproperlyConfigured(
            "FIELD_ENCRYPTION_KEY is not set. Required to read/write encrypted model fields "
            "(Aadhaar/bank columns) — generate one with "
            "`python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\"` "
            "and set it in .env (see .env.example)."
        )
    try:
        return MultiFernet([Fernet(key) for key in parse_field_encryption_keys(raw)])
    except (ValueError, TypeError) as exc:
        raise ImproperlyConfigured(
            "FIELD_ENCRYPTION_KEY is set but contains an invalid Fernet key "
            "(each comma-separated entry must be 32 url-safe base64-encoded bytes)."
        ) from exc


class EncryptedCharField(models.CharField):
    """A CharField that's encrypted at rest (Fernet/AES128-CBC + HMAC) and
    transparently decrypted on read. Not queryable/filterable by value —
    nothing in this app's spec requires searching by Aadhaar number or bank
    account number, so that trade-off is accepted (see ADR-0008).

    Storage overhead: Fernet tokens are ~1.5x the plaintext length plus a
    fixed ~73-byte overhead, so `max_length` here describes the *plaintext*
    contract for validation purposes; the actual column is TextField-sized
    under the hood to hold the ciphertext.
    """

    def db_type(self, connection):
        return "text"

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None or value == "":
            return value
        return _fernet().encrypt(value.encode()).decode()

    def from_db_value(self, value, expression, connection):
        if value is None or value == "":
            return value
        try:
            return _fernet().decrypt(value.encode()).decode()
        except InvalidToken:
            # Wrong/rotated key, or pre-existing plaintext data from before
            # this field was encrypted — fail loudly rather than silently
            # returning ciphertext as if it were the real value.
            raise ImproperlyConfigured(
                "Could not decrypt an encrypted field's stored value — FIELD_ENCRYPTION_KEY may "
                "have changed since this row was written."
            ) from None

    def to_python(self, value):
        return value
