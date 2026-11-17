# Phase 1 Mandate — Execution Log

Tracks what was actually done against [phase-1-mandate.md](phase-1-mandate.md), item by item.

## Must-have

### 1. Verify against real Postgres; CI Postgres service container

**Done.** `.github/workflows/backend-ci.yml` already runs the full suite against a real
`postgres:16-alpine` service container on every PR — that part of the mandate was already
satisfied before this pass, contrary to the local-dev notes' assumption that only SQLite had ever
been exercised.

What was newly verified: installed PostgreSQL 16 locally via `brew install postgresql@16`
(no Docker needed — the formula doesn't require the interactive sudo prompt the `docker` cask
does), created the `ngo_app`/`ngo_app` role and database matching `docker-compose.yml`'s
credentials, ran `python manage.py migrate` and the full test suite
(`python manage.py test apps`) against it directly. All 38 tests passed (later 42, after the new
cookie tests below were added), `ruff check .` clean.

### 2. Manually test password reset end-to-end

**Done.** Against the live dev server: `POST /password-reset/request` for the seeded admin
account, pulled the token from the console-logged email in the server log, `POST
/password-reset/confirm` with a new password, confirmed the old password now fails login and the
new one succeeds. Reset the seeded admin's password back to the documented `change-me-immediately`
afterward so it didn't leave the demo account in a different state than documented.

### 3. Server-side RBAC tests

**Already satisfied, no new endpoint test added.** `apps/accounts/tests/test_permissions.py`
already covers `IsAdmin`/`IsFellow` in both directions plus anonymous denial, and its own comment
explains why there's no endpoint-level test yet: *"Phase 1 introduces no role-gated endpoints of
its own"* — there is currently no Admin-only or Fellow-only URL to test against. Writing a test
against a fabricated endpoint that doesn't exist in the product would test nothing real. This item
should be re-opened the moment Phase 2 adds the first role-gated endpoint (a document or profile
route, most likely) — that PR should add the endpoint-level 403 test the mandate describes,
against a real route.

### 4. Move web token storage to httpOnly cookies

**Done, with one explicit scope-down — see ADR-0007.** Full details in
[docs/adr/0007-web-refresh-token-cookie.md](adr/0007-web-refresh-token-cookie.md). Summary:

- Backend (`apps/accounts/views.py`, `config/settings.py`): `LoginView` sets the refresh token as
  an `httpOnly`, `SameSite=Strict` cookie scoped to `/api/v1/auth` (still also returns it in the
  JSON body for native/mobile clients); `RefreshView` and `LogoutView` now read the refresh token
  from that cookie, falling back to the body. `LogoutSerializer` (now unused) was removed.
  The access token issued at login also carries a `role` claim, which simplejwt automatically
  propagates through every rotation — laid down for a possible future access-token-in-memory-only
  follow-up (see below), not consumed by the client yet.
- Flutter web (`token_storage.dart`, `api_client.dart`, `auth_repository.dart`,
  `auth_controller.dart`): the refresh token is never written to `flutter_secure_storage` when
  `kIsWeb`; `ApiClient` sends every request with `withCredentials: true`; the 401-triggered
  refresh no longer gates on "do we have a locally stored refresh token" (meaningless on web now)
  and instead just attempts the call, relying on the cookie; logout always calls the backend
  endpoint even with nothing stored locally to send, since the cookie carries what's needed.
- **Explicitly scoped down:** the access token itself is still persisted via
  `flutter_secure_storage` on web (not moved to pure in-memory as the mandate's ideal end-state
  describes). Rationale in the ADR's Alternatives section — the existing bootstrap contract
  (`AuthController`/`TokenStorage`) has real, working test coverage built around reading a
  persisted access token, and rearchitecting that to "always silently refresh on cold start" was
  judged a bigger, separately-riskier change than this pass should take under one mandate item.
  The `role` JWT claim added above exists specifically to make that follow-up cheaper later.

**Verified**, not just written:
- 4 new backend tests in `apps/accounts/tests/test_auth_flow.py`
  (`RefreshTokenCookieTests`) — login sets the cookie with correct flags, refresh works from the
  cookie alone with an empty body, refresh with neither cookie nor body is rejected, logout
  blacklists and clears the cookie. All pass against real Postgres.
- `flutter analyze`: 0 new issues (the 2 pre-existing warnings were confirmed pre-existing by
  diffing against the unmodified tree).
- `flutter test`: the 5 `auth_controller_test.dart` tests still pass unmodified (they use
  `InMemoryTokenStorage`, which isn't `kIsWeb`-gated, so the bootstrap/login/logout contract they
  cover is unaffected). `widget_smoke_test.dart` fails on a pre-existing, unrelated
  `MissingPluginException` for `shared_preferences` inside `easy_localization`'s init — confirmed
  unrelated by inspection (nothing this pass touched is on that path).
- End-to-end `curl` simulation against the live dev server, sending the same `Origin` header a
  real browser would: login → `Set-Cookie` present with `HttpOnly`/`Path=/api/v1/auth`/
  `SameSite=Strict` and no `Secure` (correct for local `DEBUG=True` http dev) → refresh with an
  empty JSON body succeeds using only the cookie, and rotates it → logout clears the cookie
  (`Set-Cookie: refresh_token=""; Max-Age=0`) and blacklists it → a subsequent refresh attempt
  with the now-stale cookie correctly returns `401`.
- The live Flutter web app was restarted against this backend; `flutter run` logged no errors on
  load (a clean start, unlike the earlier `flutter_secure_storage` corruption incident).

### 5. Account activation policy — manual approval question

**Not resolved — this is a product decision for the NGO, not something to infer or default.**
The current behavior (`apps/accounts/views.py`'s `VerifyEmailView`, per its own comment: *"Per
Assumption #4: no manual approval gate — email verification alone activates the account"*) is an
explicit, documented placeholder assumption from the original spec, not an oversight. Left open
per the mandate's own instruction to get an explicit answer first. If the eventual answer is
"NGO must approve," this becomes real engineering scope (an Admin pending-accounts queue,
`User.Status` gains a state between `PENDING_VERIFICATION`/`ACTIVE`, an approval endpoint,
notification when approved) — sizeable enough that it shouldn't be guessed at speculatively.

## Should-have

### 6. Real email delivery

**Not done — requires real credentials this session doesn't have.** Configuring `EMAIL_BACKEND`
to SMTP/SES/SendGrid needs an actual account and secret (API key or SMTP password) that has to
come from whoever owns that infra decision; fabricating placeholder credentials wouldn't be
verifiable as working and risks looking done when it isn't. The console backend remains correct
for local dev regardless of what's chosen for real delivery.

### 7. Fix `FRONTEND_BASE_URL` / CORS env mismatch

**Done, root-caused rather than patched.** The actual problem: `flutter run -d chrome` binds to a
random port unless `--web-port` is pinned, but `backend/.env.example`'s
`CORS_ALLOWED_ORIGINS`/`FRONTEND_BASE_URL` both assumed a fixed `:3000` that nothing in the
documented Flutter workflow ever produces. Rather than adding a `.env.local`-per-developer layer
(more moving parts for a problem that has a one-line fix), pinned the documented dev command to
`--web-port=5173` in both `README.md` and `app/README.md`, and updated `.env.example`'s two
affected values to `5173` to match, with a comment cross-referencing why. Out of the box, a fresh
clone now has matching ports with no manual patching required — which is what this item actually
asked for.

### 8. Permanent decision record for the storage fix

**Done — see [docs/adr/0007-web-refresh-token-cookie.md](adr/0007-web-refresh-token-cookie.md).**
Note this ADR is about the *storage scheme* (item #4 above); the unrelated `flutter_secure_storage`
`OperationError`/infinite-splash-screen bug is referenced from the ADR for context but documented
primarily via its own code comments in `AuthController._bootstrap`/`_safeClear`, since it's a
defensive-coding fix rather than an architectural decision.

## Could-have

### 9. Does the onboarding shell persist real step state?

**Confirmed: purely visual, not wired to anything.** `OnboardingShellScreen` in
`app/lib/features/onboarding/presentation/onboarding_shell_screen.dart` renders a hardcoded
`_steps` list of 4 translation keys with no read from `FellowProfile.onboarding_step` (which the
backend *does* already track and update — see `VerifyEmailView`) and no indication of which step
is actually current. Whoever builds the real onboarding forms in Phase 2 should wire this list to
that field rather than assume it already is.

### 10. Remove unused Python 3.12

**Done.** `brew uninstall python@3.12` — it was only installed while chasing an unrelated
`psycopg` wheel-availability issue that became moot once the backend moved to SQLite/Postgres
without needing that specific Python version; the working venv uses the system Python 3.14.

## Do Not Build Yet

No Phase 2 work (profile forms, document upload) was started, per the mandate.
