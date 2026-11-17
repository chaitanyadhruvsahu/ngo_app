# Phase 2 Mandate — Pass 2 Execution Log

Scope for this pass, agreed before starting: Docker/S3 (#2/#3) are blocked on the user (either an
interactive `sudo` install or real R2 credentials — neither is something this environment can do
unattended). User chose to install Docker themselves while everything else proceeds in parallel.
This log covers everything except #2/#3/#8/#9, which remain genuinely blocked.

## Must-have #1 — transaction-poisoning audit

**Done — codebase is clean, no further fixes needed.** Searched for every `except IntegrityError`
and similar mid-transaction exception handling project-wide
(`grep -rn "IntegrityError" apps/ --include="*.py"`, and separately for other unique
constraints/fields that could hit the same failure mode). Result: `IntegrityError` is caught in
exactly two places, both in `apps/volunteers/views.py`, and both already had the
`transaction.atomic()` fix from Pass 1. No other instance of the pattern exists — `User.email`'s
uniqueness is enforced via a check-then-create pattern (not exception-catching) in `SignupView`,
and `Block.name`'s uniqueness has no application code path that creates one at all yet (Django
admin only). Nothing to change here.

## Must-have #4 & #5 — Flutter UI + onboarding shell wiring

**Built.** New features: `lib/features/profile`, `lib/features/documents`,
`lib/features/volunteers`, `lib/features/admin` (data/application/presentation layers each,
following the existing `auth` feature's structure). Specifically:

- **Profile** (`/profile`): fellow's own profile, full form including Aadhaar/bank fields (the
  "single authorized detail view" per the Phase 2 Definition of Done) — `block`, `email`,
  `onboarding_step` shown read-only since there's no endpoint yet for a fellow to pick a block
  (see gap note below).
- **Documents** (`/documents`): type dropdown + `file_picker`-driven upload (PDF/JPEG/PNG,
  matching the backend's allow-list), list of current (non-superseded) documents, download.
  Download uses a small conditional-import "save file" seam
  (`lib/features/documents/services/save_file.dart`) since the actual save mechanism is
  fundamentally different on web (Blob + synthetic anchor click, via `dart:html`) vs. native
  (filesystem write) — only the web path is implemented; native throws `UnsupportedError`
  explicitly rather than silently no-op-ing, since this app has only ever been verified on web
  (see app/README.md's existing note on that).
- **Volunteers** (`/volunteers`, `/volunteers/new`, `/volunteers/:id`): list, add, edit, delete
  with a confirmation dialog.
- **Admin** (`/admin` — replaces the old placeholder `AdminShellScreen`, which is deleted;
  `/admin/fellows/:fellowId`): paginated fellow list, and a read-only detail screen showing
  profile (including sensitive fields — the *other* authorized detail view), documents (with
  download, reusing the same `DocumentRepository`/backend endpoint Admin's permission check
  already allows), and volunteers.
- **Onboarding shell** (Must-have #5): no longer a static, unwired 4-step list. Now reads
  `profileControllerProvider`, marks steps done/current based on the real
  `FellowProfile.onboarding_step` value, and links out to `/profile`, `/documents`, `/volunteers`.
- **Routing** (`app.dart`): added role-gating for the new route prefixes — fellow-only routes
  (`/onboarding`, `/profile`, `/documents`, `/volunteers`) redirect an Admin to `/admin`; the
  Admin-only prefix check was broadened from an exact `== '/admin'` match to
  `startsWith('/admin')` so the new `/admin/fellows/:id` sub-route is covered too (the Pass 1
  check would have let a Fellow through to it, since it never matched exactly).
- **i18n**: every new string added to both `en.json` and `hi.json` together, per the project's own
  convention (`README.md`'s translation-key section).
- **New dependency**: `file_picker` (cross-platform file selection, works on web) and `intl`
  (pinned to `^0.20.3` — `easy_localization`'s own transitive constraint forced this over the
  originally-tried `^0.19.0`).

**Verified:**
- `flutter analyze --fatal-infos` (what CI actually runs): clean — 0 errors, the 2 pre-existing
  warnings confirmed unrelated (same ones present on the unmodified tree), the 2 new `dart:html`
  info-lints suppressed with a file-scoped `ignore_for_file` and a comment explaining why (that
  file is only ever compiled in for web via the conditional export — this is the standard pattern
  for this exact situation, not a blanket suppression).
- `flutter test`: the 5 pre-existing `auth_controller_test.dart` tests still pass unmodified — no
  regression. `widget_smoke_test.dart`'s pre-existing `shared_preferences` plugin gap (see Phase 1
  execution log) is untouched by anything in this pass.
- Every new API call's path and JSON field names were cross-checked directly against the actual
  Django `urls.py`/serializer field lists (not assumed) — e.g. `/admin/fellows` has no trailing
  slash, `/volunteers/{id}` has no trailing slash, `/documents/` (list/upload) and
  `/documents/{id}/download` do/don't respectively — matching Django's `APPEND_SLASH` behavior
  exactly as it actually is per each `urls.py`, not a guess.
- The live Flutter web app was restarted against the running backend; `flutter run`'s log shows a
  clean launch with no runtime errors. Navigating directly to a new route (`/profile`, while
  logged out) correctly redirected to `/login` with no crash, confirming the new redirect logic
  at least executes without error.

**Not verified — a real, named limitation, not glossed over:** this environment has no working
browser automation (no screen-recording permission for screenshots — see Phase 1's session notes
— and both JS-execution-from-AppleScript and OS-level keystroke automation were tried and denied
by macOS permissions). That means **no actual click-through of the new screens happened** — form
submission, validation messages, the file-picker dialog, and the visual layout are all unverified
beyond static analysis and careful contract-matching against the tested backend. This is the
single biggest reason to actually open the app and try it before calling this pass done.

## Should-have #6 — MultiFernet key rotation

**Done.** `apps.core.encrypted_fields._fernet()` now returns a `cryptography.fernet.MultiFernet`
built from a comma-separated `FIELD_ENCRYPTION_KEY` (first key encrypts, every key is tried to
decrypt) instead of a single `Fernet`. Added `apps.accounts.management.commands.rotate_encryption_key`
— re-saves every `FellowProfile` row, which forces re-encryption under the new primary key. Full
3-step rotation procedure documented in [ADR-0010](adr/0010-key-rotation.md) and in
`.env.example`'s comment. `apps.core.checks` updated to validate every key in the list, not just
treat the whole string as one key. 3 new tests
(`apps/accounts/tests/test_key_rotation.py`) prove: an old key alone can still read what it wrote;
a new-primary-plus-old-key config can still decrypt old rows; and running the rotate command
actually changes the raw on-disk ciphertext (not a no-op) while keeping the value readable — and
that the old key *can't* read it anymore once fully dropped. Single-key configs (no comma) are
unaffected — `MultiFernet` with one key behaves identically to using that `Fernet` directly, so
every row written under Pass 1's original scheme is unaffected.

## Should-have #11 — psycopg version bump

**Done.** `psycopg[binary]` bumped from the Python-3.14-incompatible `3.2.3` (flagged as a known
gap in the Pass 1 execution log) to `3.3.5`. `pip-audit -r requirements.txt` now actually runs
locally (it couldn't before — the pinned version had no installable wheel). Running it surfaced
**22 known CVEs across pinned `Django` (5.1.4), `djangorestframework` (3.15.2), and
`djangorestframework-simplejwt` (5.3.1)** — genuinely new information, not something this bump
caused. **Not acted on** — bumping Django/DRF major/minor versions is a much larger, riskier
undertaking (compatibility testing across the whole app) than "bump one patch-adjacent dependency
so a security scanner can run," and wasn't part of what was asked. Flagging it here as a real,
separate finding that needs its own decision, not silently fixing or silently ignoring it.

## Full backend regression check

`python manage.py test apps` (against real Postgres): 81 tests, all passing (78 from Pass 1 + 3
new rotation tests). `ruff check .`: clean.

## Not done — still genuinely blocked, not silently skipped

- **Real `s3`/R2/MinIO storage backend** (Must-have #2) — waiting on Docker (user is installing
  it) or R2 credentials.
- **Docker resolution itself** (Must-have #3) — in progress, on the user's machine, not something
  this environment can do.
- **`docker-compose.yml` MinIO service** (Should-have #8) — blocked on the same root cause as #2/#3.
- **CI job against the real `s3` backend** (Should-have #9) — blocked on #2 existing first.
- **Presigned download URLs** (Could-have #10) — blocked on #2; streaming through the backend
  (Pass 1's approach) remains what's actually running.
- **`FIELD_ENCRYPTION_KEY` backup/escrow procedure** (Should-have #7) — this is an ops/ownership
  decision for the NGO, not an engineering task; still unwritten, still needs an answer from
  someone with the authority to make it.

## New gap surfaced by this pass, not previously flagged

**Fellows can't select a `block`.** There's no endpoint to list available `Block`s, so the profile
form shows `block` read-only rather than as a picker. This wasn't called out in either mandate
explicitly (the mandate's Assumption 3 treats block *filtering* as Phase 4 scope, but doesn't
address block *assignment* at all) — flagging it now since it's a real product question: is block
assignment something a fellow picks at onboarding, or something an Admin assigns after the fact?
Needs an answer before it's built either way.
