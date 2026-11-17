# Local dev session notes — 2026-09-16

> **Superseded by [phase-1-mandate.md](phase-1-mandate.md) and its
> [execution log](phase-1-mandate-execution-log.md).** Several items below (Postgres parity,
> `flutter_secure_storage` fix as a one-off, the `:3000`/`:5173` CORS mismatch) have since been
> resolved properly — the mandate documents the real fixes, including
> [ADR-0007](adr/0007-web-refresh-token-cookie.md) for the token storage decision this file
> originally just noted as a bug fix. This file is kept for the historical decision log below
> (Python version detour, Docker cask failure) that the mandate doesn't restate.

Notes from getting the app running locally on this machine (no Docker, no Postgres, no Flutter
SDK preinstalled) so the UI could be exercised end-to-end. This is **not** an ADR — it's a record
of a one-off local setup and the workarounds that setup needed.

## What's working (verified by hand)

| Area | Status | Notes |
|---|---|---|
| Backend health check | ✅ Working | `GET /api/v1/health` → `200 {"status": "ok", ...}` |
| Signup | ✅ Working | `POST /api/v1/auth/signup`; always `201`, never reveals if the email already exists |
| Email verification | ✅ Working | Token printed to server log (console email backend, see below), consumed via `/verify-email?token=...` |
| Login | ✅ Working | Returns access/refresh JWTs + role; verified via seeded admin account |
| Logout | ✅ Working (after patch) | See decision log — originally hung on web due to a `flutter_secure_storage` web bug |
| Password reset request/confirm | ⚠️ Wired up, not manually tested | Endpoints exist and are routed in the app; not click-tested this session |
| Session bootstrap / redirect-by-role (`go_router`) | ✅ Working | Admin → `/admin`, non-admin → `/onboarding`, unauthenticated → `/login` |
| Admin shell (`/admin`) | ✅ Working, but a placeholder | Just proves role-based routing; "dashboards arrive in a later phase" per its own doc comment |
| Onboarding shell (`/onboarding`) | ✅ Working, but a placeholder | Shows a static 4-step progress list; no real profile form yet |
| CORS (Flutter web ↔ Django) | ✅ Working (after fix) | Had to add the dev web port to `CORS_ALLOWED_ORIGINS` — see decision log |

## Pending / open items

- **No real email delivery.** `EMAIL_BACKEND` is Django's console backend — verification/reset
  links print to the server log instead of being emailed. Fine for dev; needs real SMTP
  credentials (or a provider like SES/SendGrid) before this is usable by anyone but a developer
  watching the log.
- **Postgres was not actually exercised.** This session ran the backend against SQLite because
  Docker Desktop couldn't be installed non-interactively (see decision log). The real
  `docker-compose.yml` + Postgres path is still untested on this machine.
- **Docker Desktop is not installed.** Needs a manual, interactive install (GUI first-run +
  sudo password) — something that can't be scripted. Whoever sets this machine up for real
  local dev needs to do that step by hand once.
- **Profile/documents, jobs, blocks/exports, notifications/i18n polish, dashboards** — all later
  phases per the repo's own README; nothing here yet beyond the two placeholder shells above.
- **Three explicitly-deferred product questions** (role hierarchy, manual account approval,
  Aadhaar/bank consent policy) — called out in the repo README as intentionally unanswered;
  `User.role` / `User.status` are modeled as extensible enums so they can be absorbed later.
- **Password reset flow** — routed and backed by real endpoints, but not manually verified this
  session (ran out of time after chasing the logout bug).
- **`FRONTEND_BASE_URL`** in `.env` still points at `http://localhost:3000`, but the Flutter web
  app actually runs on port `5173` in this setup — verification/reset links printed to the log
  need their port manually swapped when clicking through by hand (see decision log).

## Decision log

### 1. Ran the backend against SQLite instead of Postgres
**What:** Set `DATABASE_URL=sqlite:///db.sqlite3` in `backend/.env` instead of the default
Postgres URL, and dropped `psycopg[binary]` from the install (not needed without Postgres).
**Why:** Docker wasn't installed, and `brew install --cask docker` failed non-interactively —
Homebrew needs `sudo` to symlink Docker's CLI helpers, and `sudo` requires an interactive TTY
password prompt that isn't available in this environment. Rather than block on a manual install,
SQLite gets a working backend with zero extra infra, since `django-environ`'s `env.db()` already
supports `sqlite://` URLs out of the box.
**Consequence:** Nothing here has been validated against real Postgres — connection pooling,
Postgres-specific SQL, and migration behavior on Postgres are all unverified locally.

### 2. Installed Python 3.12 via Homebrew, then abandoned it in favor of the system Python 3.14
**What:** First tried `python3 -m venv` with the system Python 3.14 (worked, but no
`psycopg[binary]` wheel exists yet for 3.14). Installed `python@3.12` via brew as a fix, but its
`pyexpat` module was broken (`Symbol not found: _XML_SetAllocTrackerActivationThreshold` — a
mismatch between the Homebrew bottle's expected `libexpat` and the version actually on this
machine), which broke `plistlib`, which broke `platform.mac_ver()`, which broke `pip` itself
(newer pip uses `truststore` for SSL and needs `mac_ver()` to resolve platform tags).
**Why the fix:** Since SQLite is being used instead of Postgres (see #1), `psycopg` isn't needed
at all — so the actual blocker for using system Python 3.14 disappeared once decision #1 was
made. Went back to the system Python 3.14 venv with `psycopg[binary]` stripped from
`requirements.txt` for this session's install.
**Consequence:** `python@3.12` is still installed via brew on this machine but unused; safe to
`brew uninstall python@3.12` if no longer needed. The venv here runs Python 3.14, not the
Python version implied by any CI config — don't assume CI parity from this local venv.

### 3. Docker Desktop install left incomplete
**What:** `brew install --cask docker` fetched and started installing Docker Desktop, then failed
at the step that symlinks `docker-credential-osxkeychain` into `/usr/local/bin` because it
needs `sudo` and no TTY was available for the password prompt. Homebrew rolled back the App
install after the failure.
**Why not retried:** Fixing this requires a human to run the install interactively (enter their
password when prompted, and on first launch approve Docker's system-level permissions in the
macOS UI) — not something that can be done from an automated shell.
**Consequence:** the real `docker-compose up` path (Postgres + auto-migrating Django) is still
unverified on this machine. Whoever needs the "real" setup should run `brew install --cask
docker`, open Docker.app once to finish setup, then follow the README's normal Quick Start.

### 4. Added `http://localhost:5173` to `CORS_ALLOWED_ORIGINS`
**What:** `backend/.env`'s `CORS_ALLOWED_ORIGINS` defaulted to `http://localhost:3000` only. The
Flutter web app was launched on port `5173` (port `3000`'s sibling, `5000`, was already taken by
macOS's AirPlay Receiver, and `flutter run` defaults elsewhere) causing "Could not reach the
server" in the login screen.
**Why:** `django-cors-headers` blocks cross-origin requests by default; the deployed default in
`.env.example` assumes a `:3000` dev frontend, which the actual Flutter web dev server doesn't
use here.
**Consequence:** `CORS_ALLOWED_ORIGINS` in this local `.env` now reads
`http://localhost:3000,http://localhost:5173` — a local-only change, not committed anywhere
that matters, but worth knowing if `.env` gets copied elsewhere. `FRONTEND_BASE_URL` (used to
build the links inside verification/reset emails) was left at `:3000` — not fixed, just noted
above under "Pending" — so those printed links need manual port-swapping when clicked by hand.

### 5. Patched `AuthController` to survive corrupted browser storage
**What:** Logging out appeared to do nothing, and refreshing the page afterward left the app
stuck on the splash screen's loading spinner forever. The Flutter dev-server logs showed a
repeating `RethrownDartError: OperationError` on every reload. Traced to
`flutter_secure_storage_web`: on web it keeps both the AES-GCM encryption key *and* the encrypted
token blobs in `localStorage`. Restarting the Flutter dev process several times while getting it
running left the key and the encrypted values out of sync, so every read triggered a WebCrypto
`decrypt()` failure.
That exception was unhandled in `AuthController._bootstrap()`, so `AuthState.status` never left
its default `AuthStatus.unknown` — and `go_router`'s redirect logic keeps anything in the
`unknown` state parked on `/splash` forever. `logout()`'s `finally` block called
`_tokenStorage.clear()` directly, which could itself throw partway through deleting the three
stored keys, leaving a half-cleared, still-broken session.
**Why this fix (not just "clear your browser storage"):** clearing `localStorage` by hand fixes
the *symptom* once, but the underlying failure mode — any decrypt error permanently wedging the
app on the splash screen — was a real bug independent of how the storage got corrupted (it could
just as easily happen from a browser extension, a private-browsing quirk, or a future package
upgrade). Wrapping the read/clear calls in `try`/`catch` and treating any failure as "no session"
is a general fix, not a one-off.
**Files changed:** `app/lib/features/auth/application/auth_controller.dart` —
  - `_bootstrap()`: wraps the token/role reads in `try`/`catch`; on failure, best-effort clears
    storage and sets `AuthStatus.unauthenticated` instead of leaving `status` at `unknown`.
  - `logout()`: reads the refresh token defensively (a failed read no longer blocks the
    server-side logout call from being *attempted*), and clearing storage now goes through the
    new `_safeClear()` helper instead of calling `_tokenStorage.clear()` directly.
  - `forceLogout()` (used when a token refresh fails server-side): also routed through
    `_safeClear()` for the same reason.
  - New private helper `_safeClear()`: swallows any exception from `_tokenStorage.clear()` —
    the session is being treated as logged out either way, so a partial/failed clear shouldn't
    block reaching `AuthStatus.unauthenticated`.
**Consequence:** none of this touches `TokenStorage`'s web implementation itself (the actual
key/blob desync bug lives in the third-party `flutter_secure_storage_web` package) — it only
stops that failure mode from hanging the app. If it recurs, the app now degrades to "logged out,
please log in again" instead of an infinite spinner.

### 6. Installed Flutter and (attempted) Docker via Homebrew cask, with explicit user sign-off
**What:** Neither Flutter nor Docker Desktop was present on this machine. Asked before installing
anything (`AskUserQuestion`), given the size/time cost and that Docker's install needs an
interactive sudo prompt; user chose "install everything." Installed `flutter` (cask, succeeded)
and attempted `docker` (cask, failed per decision #3).
**Why ask first:** installing ~1GB+ of tooling system-wide is a meaningfully sized, only
partially reversible action or worth confirming rather than assuming.
