"""HTTPS, shared throttling, and fail-closed configuration for the hosted pilot."""
from config.settings import *  # noqa: F403
from config.settings import env

DEBUG = False
PRODUCTION = True
render_host = env("RAILWAY_PUBLIC_DOMAIN", default="") or env("RENDER_EXTERNAL_HOSTNAME", default="")
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=[render_host] if render_host else [])
FRONTEND_BASE_URL = (env("FRONTEND_BASE_URL", default="") or (
    f"https://{render_host}" if render_host else ""
)).rstrip("/")
CSRF_TRUSTED_ORIGINS = [FRONTEND_BASE_URL] if FRONTEND_BASE_URL else []
CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = True
# Railway probes the container directly over HTTP. Only public readiness is
# exempt; account, document and application routes continue to require HTTPS.
SECURE_REDIRECT_EXEMPT = [r"^api/v1/ready$"]
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
REFRESH_TOKEN_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 3600
# Scope HSTS to the pilot host; don't enrol an NGO's whole domain in preload.
SECURE_HSTS_INCLUDE_SUBDOMAINS = False
SECURE_HSTS_PRELOAD = False
SECURE_REFERRER_POLICY = "same-origin"

# Shared between Gunicorn processes without adding a separate Redis service.
# `createcachetable` runs with migrations before the web deployment.
CACHES = {"default": {
    "BACKEND": "django.core.cache.backends.db.DatabaseCache",
    "LOCATION": "ngo_cache",
    "TIMEOUT": 300,
    "OPTIONS": {"MAX_ENTRIES": 10000},
}}
