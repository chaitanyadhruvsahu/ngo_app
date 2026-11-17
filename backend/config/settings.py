"""
Django settings for the NGO Fellow & Volunteer Management App backend.

All configuration that varies between local / staging / production comes from
environment variables — nothing environment-specific is hardcoded here.
See backend/.env.example for the full list of variables.
"""
from datetime import timedelta
from pathlib import Path

import environ
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env(
    DEBUG=(bool, False),
)
# .env is only read locally; staging/production inject real env vars directly.
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env(
    "DJANGO_SECRET_KEY",
    default="unsafe-local-dev-key-change-me-at-least-32-bytes",
)
DEBUG = env.bool("DEBUG", default=False)

ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])

GIT_SHA = env("GIT_SHA", default=env("RENDER_GIT_COMMIT", default="dev"))

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "apps.core",
    "apps.accounts",
    "apps.documents",
    "apps.volunteers",
    "apps.jobs",
    "apps.notifications",
    "apps.reporting",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "apps.core.middleware.RequestIDMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
DATABASES = {
    "default": env.db(
        "DATABASE_URL",
        default="postgres://ngo_app:ngo_app@localhost:5432/ngo_app",
    )
}

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 10}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Argon2id first: OWASP-recommended, upgrade over Django's PBKDF2 default.
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]

# ---------------------------------------------------------------------------
# Internationalization
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
JOB_REMINDER_TIME_ZONE = env("JOB_REMINDER_TIME_ZONE", default="Asia/Kolkata")
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}
# Only compiled public assets belong here, never uploads or the project root.
WHITENOISE_ROOT = env("WEB_BUILD_ROOT", default=None)
WHITENOISE_INDEX_FILE = True
WHITENOISE_MAX_AGE = 0  # Flutter's bootstrap/main filenames are not content-hashed.

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# CORS — never '*' once real accounts exist.
# ---------------------------------------------------------------------------
CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=["http://localhost:3000"])
CORS_ALLOW_CREDENTIALS = True

# ---------------------------------------------------------------------------
# DRF
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    # Fail closed: any view that doesn't declare its own permission_classes
    # requires authentication rather than defaulting to open.
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "EXCEPTION_HANDLER": "apps.core.exceptions.envelope_exception_handler",
    "DEFAULT_THROTTLE_CLASSES": (
        "rest_framework.throttling.ScopedRateThrottle",
    ),
    "DEFAULT_THROTTLE_RATES": {
        "auth-sensitive": env("THROTTLE_AUTH_SENSITIVE", default="5/min"),
        "auth-verify": env("THROTTLE_AUTH_VERIFY", default="10/min"),
    },
    "TEST_REQUEST_DEFAULT_FORMAT": "json",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env.int("JWT_ACCESS_TOKEN_MINUTES", default=15)),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env.int("JWT_REFRESH_TOKEN_DAYS", default=14)),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
}

# ---------------------------------------------------------------------------
# Refresh token cookie (web clients) — see ADR-0007.
#
# The refresh token is set as an httpOnly cookie on /login so it's never
# readable by page JS (mitigates XSS token theft). The access token is
# never cookied — it stays in the response body / in-memory on the client,
# short-lived by design. Mobile clients ignore the cookie and keep using
# the refresh_token in the JSON body via OS-level secure storage.
# ---------------------------------------------------------------------------
REFRESH_TOKEN_COOKIE_NAME = "refresh_token"
REFRESH_TOKEN_COOKIE_PATH = "/api/v1/auth"
# Secure requires HTTPS; browsers treat http://localhost as a secure context
# for this purpose, but default to False whenever DEBUG is on in case that
# dev server isn't being hit via localhost (e.g. a LAN IP).
REFRESH_TOKEN_COOKIE_SECURE = env.bool("REFRESH_TOKEN_COOKIE_SECURE", default=not DEBUG)
REFRESH_TOKEN_COOKIE_SAMESITE = "Strict"

# ---------------------------------------------------------------------------
# Auth token (email verification / password reset) policy
# ---------------------------------------------------------------------------
EMAIL_VERIFICATION_TOKEN_TTL_HOURS = env.int("EMAIL_VERIFICATION_TOKEN_TTL_HOURS", default=24)
PASSWORD_RESET_TOKEN_TTL_HOURS = env.int("PASSWORD_RESET_TOKEN_TTL_HOURS", default=1)

FRONTEND_BASE_URL = env("FRONTEND_BASE_URL", default="http://localhost:3000")

# ---------------------------------------------------------------------------
# Field encryption (Aadhaar/bank columns) — see ADR-0008.
# No default: apps.core.checks fails startup with a clear message if unset,
# rather than letting a missing key surface as a confusing error the first
# time an encrypted field is touched.
# ---------------------------------------------------------------------------
FIELD_ENCRYPTION_KEY = env("FIELD_ENCRYPTION_KEY", default=None)

# ---------------------------------------------------------------------------
# Private storage shared by documents and job photos — see ADR-0009.
# ---------------------------------------------------------------------------
STORAGE_BACKEND = env("STORAGE_BACKEND", default="local")
DOCUMENT_STORAGE_ROOT = Path(env("DOCUMENT_STORAGE_ROOT", default=str(BASE_DIR / "document_storage")))
S3_BUCKET_NAME = env("S3_BUCKET_NAME", default="")
S3_ENDPOINT_URL = env("S3_ENDPOINT_URL", default="")
S3_REGION_NAME = env("S3_REGION_NAME", default="us-east-1")
S3_ACCESS_KEY_ID = env("S3_ACCESS_KEY_ID", default="")
S3_SECRET_ACCESS_KEY = env("S3_SECRET_ACCESS_KEY", default="")
S3_ADDRESSING_STYLE = env("S3_ADDRESSING_STYLE", default="path")
if STORAGE_BACKEND not in {"local", "s3"}:
    raise ImproperlyConfigured(f"Unknown STORAGE_BACKEND '{STORAGE_BACKEND}' — expected 'local' or 's3'.")
if STORAGE_BACKEND == "s3" and not S3_BUCKET_NAME:
    raise ImproperlyConfigured("S3_BUCKET_NAME is required for STORAGE_BACKEND=s3")
if bool(S3_ACCESS_KEY_ID) != bool(S3_SECRET_ACCESS_KEY):
    raise ImproperlyConfigured("Set both S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY, or use IAM credentials")

MAX_UPLOAD_SIZE_MB = env.int("MAX_UPLOAD_SIZE_MB", default=10)

# Enable only after NGO privacy sign-off; each submission also needs opt-in.
JOB_GEOTAG_ENABLED = env.bool("JOB_GEOTAG_ENABLED", default=False)
JOB_MAX_PHOTOS = 5

# ---------------------------------------------------------------------------
# Email
# ---------------------------------------------------------------------------
EMAIL_BACKEND = env(
    "EMAIL_BACKEND",
    default="django.core.mail.backends.console.EmailBackend",
)
EMAIL_HOST = env("EMAIL_HOST", default="")
EMAIL_PORT = env.int("EMAIL_PORT", default=587)
EMAIL_HOST_USER = env("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default="")
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS", default=True)
EMAIL_TIMEOUT = 15
RESEND_API_KEY = env("RESEND_API_KEY", default="")
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="no-reply@ngo-app.example")

# ---------------------------------------------------------------------------
# Logging — structured JSON from day one.
# ---------------------------------------------------------------------------
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {
        "scrub_sensitive": {
            "()": "apps.core.logging_filters.ScrubSensitiveDataFilter",
        },
    },
    "formatters": {
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(levelname)s %(name)s %(message)s %(request_id)s",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json",
            "filters": ["scrub_sensitive"],
        },
    },
    "root": {
        "handlers": ["console"],
        "level": env("LOG_LEVEL", default="INFO"),
    },
    "loggers": {
        "django": {"handlers": ["console"], "level": env("LOG_LEVEL", default="INFO"), "propagate": False},
        "apps": {"handlers": ["console"], "level": env("LOG_LEVEL", default="INFO"), "propagate": False},
    },
}
