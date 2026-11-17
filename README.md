# NGO Fellow & Volunteer Management App

Flutter (Web + Android) client with a Django/DRF backend on PostgreSQL. The repository now
implements Phases 0–3: foundations, authentication/onboarding, profiles/documents/volunteers,
and the audited jobs lifecycle from assignment through evidence review, with notifications
and reporting added in later phases. See the [prototype release handover](docs/release/README.md)
for current deployment scope, instructions, user guide and launch gates.

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
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

The web client defaults to `/api/v1` on its own origin for the bundled deployment.
Local split-server development must supply the API URL as above.

Full details, including running tests/lint and provisioning the first Admin account, are in
`backend/README.md` and `app/README.md`.

## CI

- `.github/workflows/backend-ci.yml` — gitleaks secret scan, `pip-audit`, `ruff`, Django system
  check, migrations, and the full test suite, against a real Postgres service container.
- `.github/workflows/flutter-ci.yml` — `flutter analyze`, `flutter test`, `flutter build web`,
  and a debug APK build uploaded as a CI artifact.

Both run on every PR touching their respective directory. Configure branch protection on
`main` to require them; remote branch-protection settings have not been verified locally.

## Translation-key convention

i18n keys are namespaced by feature area, e.g. `auth.login_button`, `common.loading`,
`onboarding.step_active`. Translation files live at `app/assets/translations/{en,hi}.json`; add
a key to both files together. See ADR-0005 and `app/README.md` for the i18n wrapper contract.

## Phase 3 jobs lifecycle

- Admins can create, edit, assign, reassign, filter, and review jobs. Reassignments require a
  reason and are retained in append-only history.
- Fellows can start assigned work and submit actual hours with 1–5 photos. Android uses native
  camera capture; the web build explicitly labels browser-selected evidence as unverifiable.
- Approvals and reasoned rejections are tied to a specific submission. Resubmissions never
  overwrite older evidence or decisions.
- Optional location capture is disabled by default, requires fellow opt-in when enabled, and can
  never block submission. Location reads are audited.
- Evidence is private and backend-proxied. Local development may use filesystem storage; shared
  environments use S3-compatible storage (S3/R2/MinIO).

The frozen contract is in `docs/phase-3-api-contract.md`; delivery evidence and residual limits
are in `docs/phase-3-execution-log.md`. Product/policy decisions still awaiting the NGO are kept
in one place: `docs/open-questions.md`.
