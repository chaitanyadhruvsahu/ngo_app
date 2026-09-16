# NGO Fellow & Volunteer Management App

Flutter (Web + Android) client, Django/DRF backend on PostgreSQL. This repo currently implements
**Phase 0 (Project Foundations)** and **Phase 1 (Authentication & Onboarding)**; later phases
(profile/documents, jobs, blocks/exports, notifications/i18n polish, dashboards) will build on
this foundation.

See `/docs/adr/` for the reasoning behind every major technical decision (framework, auth
transport, state management, i18n, hosting).

## Repo layout

```
/backend    Django + DRF API (see backend/README.md)
/app        Flutter client — Web + Android (see app/README.md)
/docs/adr   Architecture Decision Records
```

## Quick start

**Backend** (requires Docker):

```bash
cd backend
cp .env.example .env
docker-compose up
```

Verify it's up: `curl http://localhost:8000/api/v1/health`

**Flutter client** (requires the Flutter SDK):

```bash
cd app
flutter pub get
flutter run -d chrome
```

The client defaults to `http://localhost:8000/api/v1` as its API base URL (override with
`--dart-define=API_BASE_URL=...`).

Full details, including running tests/lint and provisioning the first Admin account, are in
`backend/README.md` and `app/README.md`.

## CI

- `.github/workflows/backend-ci.yml` — gitleaks secret scan, `pip-audit`, `ruff`, Django system
  check, migrations, and the full test suite, against a real Postgres service container.
- `.github/workflows/flutter-ci.yml` — `flutter analyze`, `flutter test`, `flutter build web`,
  and a debug APK build uploaded as a CI artifact.

Both run on every PR touching their respective directory; branch protection on `main` requires
them to pass.

## Translation-key convention

i18n keys are namespaced by feature area, e.g. `auth.login_button`, `common.loading`,
`onboarding.step_active`. Translation files live at `app/assets/translations/{en,hi}.json`; add
a key to both files together. See ADR-0005 and `app/README.md` for the i18n wrapper contract.

## Where things stand vs. the spec

- Phase 0 and Phase 1 scope (see the engineering spec) are implemented, including the health
  check, error envelope, JWT auth with rotation/blacklisting, Argon2id hashing, single-use
  hashed email-verification/password-reset tokens, per-IP rate limiting on auth endpoints, and
  the onboarding shell.
- Three open questions from the master requirements doc (role hierarchy, manual account
  approval, Aadhaar/bank consent policy) are deliberately **not** answered here — `User.role`
  and `User.status` are modeled as extensible enums specifically so those answers can be
  absorbed later without a schema rewrite. See the spec's Assumptions & Open Questions section.
- This scaffold was built in an environment without a local Flutter SDK — see the note at the
  top of `app/README.md` for what that means for the Flutter half specifically.
