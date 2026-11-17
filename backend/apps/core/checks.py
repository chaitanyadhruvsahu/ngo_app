"""Deploy-time system checks — fail fast on misconfiguration rather than
surfacing it as a confusing runtime error the first time a request touches
the affected code path.
"""
from urllib.parse import urlsplit

from cryptography.fernet import Fernet
from django.conf import settings
from django.core.checks import Error, register

from apps.core.encrypted_fields import parse_field_encryption_keys


@register()
def field_encryption_key_configured(app_configs, **kwargs):
    raw = getattr(settings, "FIELD_ENCRYPTION_KEY", None)
    if not raw:
        return [
            Error(
                "FIELD_ENCRYPTION_KEY is not set.",
                hint="Required for Aadhaar/bank field encryption. Generate one with "
                "`python -c \"from cryptography.fernet import Fernet; "
                'print(Fernet.generate_key().decode())"` and set it in .env — see .env.example.',
                id="core.E001",
            )
        ]
    try:
        for key in parse_field_encryption_keys(raw):
            Fernet(key)
    except (ValueError, TypeError):
        return [
            Error(
                "FIELD_ENCRYPTION_KEY is set but contains an invalid Fernet key.",
                hint="Each comma-separated entry must be 32 url-safe base64-encoded bytes "
                "— see .env.example and ADR-0010.",
                id="core.E002",
            )
        ]
    return []


@register(deploy=True)
def production_configuration(app_configs, **kwargs):
    if not getattr(settings, "PRODUCTION", False):
        return []
    problems = []
    if len(settings.SECRET_KEY) < 50 or settings.SECRET_KEY.startswith(("unsafe-", "change-me")):
        problems.append("DJANGO_SECRET_KEY must be a unique random secret of at least 50 characters.")
    if not settings.ALLOWED_HOSTS or "*" in settings.ALLOWED_HOSTS:
        problems.append("Set exact DJANGO_ALLOWED_HOSTS (or the hosting service hostname).")
    origin = urlsplit(settings.FRONTEND_BASE_URL)
    if (origin.scheme != "https" or not origin.hostname or origin.path not in ("", "/")
            or origin.fragment or origin.query or origin.username):
        problems.append("FRONTEND_BASE_URL must be the public HTTPS origin without a path or fragment.")
    if settings.DATABASES["default"]["ENGINE"] != "django.db.backends.postgresql":
        problems.append("The hosted pilot requires PostgreSQL.")
    if settings.STORAGE_BACKEND != "s3":
        problems.append("The hosted pilot requires private S3/R2 storage; local files are ephemeral.")
    if settings.S3_ENDPOINT_URL and not settings.S3_ENDPOINT_URL.startswith("https://"):
        problems.append("The hosted object-storage endpoint must use HTTPS.")
    if settings.EMAIL_BACKEND != "django.core.mail.backends.smtp.EmailBackend" or not settings.EMAIL_HOST:
        problems.append("Configure SMTP delivery before enabling signup or password recovery.")
    if settings.DEFAULT_FROM_EMAIL.endswith(".example"):
        problems.append("DEFAULT_FROM_EMAIL must use the verified sender domain.")
    return [Error(message, id=f"core.E{number:03}") for number, message in enumerate(problems, 101)]
