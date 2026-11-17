# Phase 2 Mandate — Execution Log (first pass: backend data model + local storage)

Scope for this pass, agreed before starting: build the Django models/migrations, field
encryption, and the fellow-facing + Admin-facing API endpoints, using `STORAGE_BACKEND=local`
(no Docker/S3 credentials available in this environment). Flutter UI and real S3/MinIO wiring are
explicitly **not** part of this pass — see [phase-2-mandate.md](phase-2-mandate.md) §I/§O for what
that follow-up still needs.

## What was built

**New apps:** `apps.documents`, `apps.volunteers` (new). `apps.accounts` extended in place for
`FellowProfile`'s new fields and a new `Block` model, per the mandate's framing of `FellowProfile`
as "extends the existing model from Phase 1."

**Note — `Block` didn't actually exist.** The mandate's Data Architecture table lists `block` as
an "Already exists" field on `FellowProfile`. It didn't — Phase 1 only shipped `User`/`AuthToken`/
`FellowProfile`, no org-structure model. Added a minimal `Block` (id, name, created_at) so
`FellowProfile.block` has a real FK target; kept deliberately small since block-based
filtering/management is explicitly Phase 4 scope (Assumption 3) — this phase only needs the field
to exist.

**Models** (`apps/accounts/models.py`, `apps/documents/models.py`, `apps/volunteers/models.py`):
`Block`, `FellowProfile` (extended: `block`, `full_name`, `date_of_birth`, `phone_number`,
`address`, `aadhaar_number`/`bank_account_number`/`bank_ifsc` (encrypted), `bank_account_holder_name`,
`consent_given_at`, `updated_at`), `Document`, `DocumentAccessLog`, `Volunteer` — all per §G's
field tables. 3 migrations (`accounts.0002`, `accounts.0003` ordering fix, `documents.0001`,
`volunteers.0001`), applied and verified against both real Postgres and the live SQLite dev
instance.

**Field encryption (ADR-0008):** `django-cryptography` (the obvious first choice) turned out to
be incompatible with Django 5.1 — it imports `django.utils.baseconv`, removed in Django 4.0, and
hasn't been updated. Built a small custom field (`apps.core.encrypted_fields.EncryptedCharField`)
on top of the `cryptography` package's `Fernet` directly instead. `FIELD_ENCRYPTION_KEY` is a
dedicated env var (separate from `DJANGO_SECRET_KEY`), validated at startup by a Django system
check (`apps.core.checks`) rather than failing confusingly on first use.

**Storage (ADR-0009):** `STORAGE_BACKEND=local` via `FileSystemStorage`, rooted outside
`MEDIA_ROOT`/any served path. `STORAGE_BACKEND=s3` raises a clear `ImproperlyConfigured` at
startup rather than pretending to work — **the S3/R2/MinIO path itself is not built**, since no
credentials or working Docker were available here. This is the mandate's biggest deferred item —
see Not Done below.

**Upload validation (Mandate #6):** content-based MIME sniffing via magic bytes
(`apps.documents.services.validation`) rather than `python-magic` — that needs the system
`libmagic` library, an extra OS dependency this app's small, fixed allow-list (PDF, JPEG, PNG)
doesn't justify. Confirmed a mismatched-extension upload (`.pdf` claimed, non-PDF bytes) is
rejected regardless of client-supplied `Content-Type`.

**Endpoints (§H):** all of them — `/profile/me` (GET/PATCH), `/documents` (GET/POST),
`/documents/{id}/download`, `/volunteers` (GET/POST), `/volunteers/{id}` (GET/PATCH/DELETE),
`/admin/fellows` (paginated list), `/admin/fellows/{id}`, `/admin/fellows/{id}/documents`,
`/admin/fellows/{id}/volunteers`.

**Mandate #1 (no raw storage URLs to clients):** `DocumentSerializer` excludes `storage_key`
entirely; downloads stream through `DocumentDownloadView` (Django `FileResponse`) after an
ownership/role check — satisfies the guarantee even without S3 presigning (see ADR-0009).

**Mandate #2 (access logging, no exceptions):** every `DocumentDownloadView` hit writes a
`DocumentAccessLog` row, including Admin's — tested explicitly for both roles.

**Mandate #4 (RBAC 403/404 test pair, paid off on the first endpoint, not deferred again):**
36 new tests across `apps/documents/tests/test_documents_api.py`,
`apps/volunteers/tests/test_volunteers_api.py`, `apps/accounts/tests/test_profile_api.py` — every
endpoint that distinguishes Fellow/Admin has both a 403 (wrong role) and, where ownership applies,
a 404 (right role, someone else's record) test, plus 401 (anonymous) coverage. Full suite: 78
tests, all passing against real Postgres, `ruff check .` clean.

**Mandate #5 (404 not 403 for cross-fellow access):** implemented via `Http404` raised directly
in `DocumentDownloadView`/`VolunteerDetailView` rather than a permission class returning 403 —
verified by dedicated tests (`test_fellow_downloading_another_fellows_document_gets_404`, the
volunteer equivalents for read/update/delete).

**§L Testing — the "sensitive fields never leak outside the single authorized detail view"
contract:** `FellowProfileListSerializer` (used by `GET /admin/fellows`) is a separate,
deliberately narrower serializer from `FellowProfileDetailSerializer` (used by `GET /profile/me`
and `GET /admin/fellows/{id}`) — the former has no `aadhaar_number`/`bank_account_number`/
`bank_ifsc` fields at all, not just omitted-by-permission. Verified by
`test_admin_can_list_fellows_without_sensitive_fields`, which asserts those keys are entirely
absent from list responses. `DocumentSerializer` similarly never includes `storage_key`.

**Field encryption round-trip test (§L):** `apps/accounts/tests/test_encrypted_fields.py` —
write→read round-trips correctly through the ORM, *and* a raw SQL query confirms the actual
column value on disk doesn't contain the plaintext (not just that the ORM-level abstraction
claims to encrypt it).

**A real Postgres-specific bug found and fixed:** the volunteer duplicate-detection path
(`IntegrityError` → `409`) initially poisoned the entire test transaction on Postgres — once a
query fails inside a transaction, Postgres refuses every subsequent query until rollback, which
broke even unrelated cleanup code after the caught exception. Fixed by wrapping the `save()` call
in `transaction.atomic()` so the failure is contained to its own savepoint. This wouldn't have
surfaced against SQLite, which doesn't have this behavior — a concrete case where the Phase 1
decision to actually verify against real Postgres (not just SQLite) paid for itself immediately.

## Not done — deferred, not silently skipped

- **`s3`/R2/MinIO storage backend.** The mandate's actual target architecture. Needs real
  provider credentials and either a working Docker install (for MinIO) or direct R2 access to
  build *and verify* — building it blind, untested, would be worse than deferring it honestly.
  See ADR-0009.
- **Flutter UI** for any of this — profile form, document upload screen, volunteer list/CRUD,
  Admin fellow browsing. Explicitly out of scope for this pass per the agreed-upon scope.
- **`docker-compose.yml` MinIO service** (§I) — blocked on the same Docker unavailability as the
  `s3` backend itself.
- **`FIELD_ENCRYPTION_KEY` backup/escrow procedure** (Definition of Done item) — flagged in
  ADR-0008 as a real gap, not written. This is a process/ops decision (where does the NGO actually
  store this secret long-term?) more than an engineering one.
- **Onboarding shell wired to real `onboarding_step`** (carried forward from Phase 1) — not
  touched; it's a Flutter change, out of scope for this backend-only pass.
- **Observability (§M)** — structured upload-attempt logs exist implicitly via the app's existing
  JSON logging (every view logs through the same request/response cycle Phase 1 set up), but no
  dedicated metrics/alerting was added — that's infra work (a metrics backend, alert rules) this
  local-only pass has no target to wire up to.
- **`docker-compose.yml`/CI real S3 smoke test job** (§I) — CI runs against `STORAGE_BACKEND=local`
  only (added `FIELD_ENCRYPTION_KEY`/`STORAGE_BACKEND` to `backend-ci.yml`'s env); a separate
  MinIO/staging-R2 smoke job is future work once the `s3` backend itself exists.

## Known pre-existing gap, unrelated to this phase's changes

`pip-audit -r requirements.txt` fails locally under Python 3.14 (this venv) — `requirements.txt`
pins `psycopg[binary]==3.2.3`, which has no wheel for 3.14 yet. Not introduced by this phase (same
issue surfaced when first setting up the Phase 1 venv); CI runs Python 3.12, where this pin
resolves fine, so `pip-audit` in CI is unaffected. Worth a version bump at some point regardless.
