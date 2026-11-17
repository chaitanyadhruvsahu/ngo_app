# Backend (`/backend`)

Django + Django REST Framework on PostgreSQL (ADR-0002), JWT auth via `simplejwt` (ADR-0003).

## Local development

```bash
cp .env.example .env
docker-compose up
```

This runs Postgres and the Django dev server (auto-migrating on start) at `http://localhost:8000`.
`GET http://localhost:8000/api/v1/health` should return `{"status": "ok", ...}`.

To run dev tooling (lint/tests) against the running stack:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python manage.py test apps
ruff check .
```

Provision the first Admin account (Admin accounts are never self-registered — see
`docs/adr` / spec Assumption #5):

```bash
ADMIN_EMAIL=admin@example.org ADMIN_PASSWORD=change-me-immediately python manage.py seed_admin
# or: python manage.py createsuperuser
```

## Folder structure

```
config/            settings, root urlconf, wsgi/asgi
apps/core/         shared error envelope, base permissions, request-ID logging, health check
apps/accounts/     Phase 1 auth — User/AuthToken/FellowProfile models, signup/login/etc. endpoints
```

`apps.accounts` (not `apps.auth`) — `django.contrib.auth` already owns the app label `auth`;
see ADR-0002 for the naming rationale.

Every new backend app should follow the same `models.py` / `serializers.py` / `views.py` /
`permissions.py` / `services/` / `tests/` split used by `apps/accounts/`.

## Error envelope

Every API error response is shaped:

```json
{"error": {"code": "invalid_credentials", "message": "Invalid email or password."}}
```

See `apps/core/exceptions.py`.

## Auth endpoints (Phase 1)

| Endpoint | Method | Notes |
|---|---|---|
| `/api/v1/auth/signup` | POST | `{email, password}` — generic response either way |
| `/api/v1/auth/verify-email` | POST | `{token}` |
| `/api/v1/auth/resend-verification` | POST | `{email}` — not in the original API table but required by the Reliability mandate (account creation is decoupled from email delivery) |
| `/api/v1/auth/login` | POST | `{email, password}` → `{access_token, refresh_token, role}` |
| `/api/v1/auth/refresh` | POST | `{refresh_token}` → rotated tokens |
| `/api/v1/auth/logout` | POST | requires `Authorization: Bearer <access_token>`, `{refresh_token}` body |
| `/api/v1/auth/password-reset/request` | POST | `{email}` — always `202`, never reveals existence |
| `/api/v1/auth/password-reset/confirm` | POST | `{token, new_password}` — blacklists all outstanding refresh tokens for the user |

## Profile, documents & volunteers (Phase 2)

`apps.accounts` (profile), `apps.documents`, `apps.volunteers` — see `docs/phase-2-mandate.md`
and its execution log for the full design/decision record. Endpoints:

| Endpoint | Method | Notes |
|---|---|---|
| `/api/v1/profile/me` | GET/PATCH | Own profile only; includes decrypted Aadhaar/bank fields |
| `/api/v1/documents` | GET/POST | Own documents; POST is multipart upload |
| `/api/v1/documents/{id}/download` | GET | Streams the file; every access is logged |
| `/api/v1/volunteers` | GET/POST | Own volunteers |
| `/api/v1/volunteers/{id}` | GET/PATCH/DELETE | Own records only — 404 on someone else's ID |
| `/api/v1/admin/fellows` | GET | Admin-only, paginated, no sensitive fields |
| `/api/v1/admin/fellows/{id}` | GET | Admin-only, full detail including sensitive fields |
| `/api/v1/admin/fellows/{id}/documents` | GET | Admin-only |
| `/api/v1/admin/fellows/{id}/volunteers` | GET | Admin-only |

New env vars (see `.env.example`):

- `FIELD_ENCRYPTION_KEY` — required. Encrypts Aadhaar/bank columns at the application layer
  (ADR-0008). Generate with:
  `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`.
  Startup fails fast with a clear error if this is missing or malformed — see `apps.core.checks`.
- `STORAGE_BACKEND` — `local` (default, works out of the box, no Docker needed) or `s3` (**not
  implemented yet** — raises `ImproperlyConfigured` at startup; see ADR-0009 for what real
  object-storage support still needs).
- `DOCUMENT_STORAGE_ROOT` — optional, only used by the `local` backend. Defaults to
  `backend/document_storage/` (gitignored).
- `MAX_UPLOAD_SIZE_MB` — default `10`.

## Security notes

- Passwords hashed with Argon2id (`config/settings.py: PASSWORD_HASHERS`).
- Email verification / password reset tokens are single-use, time-limited, and stored as
  SHA-256 hashes only (`apps/accounts/services/tokens.py`).
- `auth-sensitive` (signup/login/reset) and `auth-verify` (verify/resend) DRF throttle scopes
  rate-limit by IP — see `THROTTLE_AUTH_SENSITIVE` / `THROTTLE_AUTH_VERIFY` in `.env.example`.
- `apps/core/logging_filters.py` redacts common sensitive field names from log messages as
  defense in depth, on top of never intentionally logging a password or raw token.
