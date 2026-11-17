# ADR-0007: Web refresh token storage — httpOnly cookie, not client-readable storage

**Status:** Accepted
**Date:** 2026-09-16
**Amends:** ADR-0003, specifically its "tokens stored client-side via `flutter_secure_storage`"
consequence — that statement still holds for native (Android), but no longer for web.

## Context

ADR-0003 established JWT auth (short-lived access token + rotating refresh token) so one auth
code path serves both the Flutter web build and native Android. It stated tokens would be stored
via `flutter_secure_storage` everywhere, which is real OS-level secure storage on Android
(Keystore-backed) and iOS (Keychain) — but not on web.

`flutter_secure_storage`'s web backend keeps both the AES-GCM encryption key and the encrypted
token value in plain `localStorage`. Anything that can execute JS on the page — an XSS bug, a
malicious or compromised browser extension — can read both and decrypt the token. For a
short-lived (~15 min) access token that's a bounded risk; for a 14-day refresh token, it's a
standing one. This app will gate access to Aadhaar and bank documents in a later phase, so the
credential that unlocks a new access token for 14 days is a meaningfully sensitive thing to leave
readable by page JS.

(This ADR was written after a separate, unrelated bug: a stale encryption key left over from
repeated local dev-server restarts caused `flutter_secure_storage_web` to throw an undecryptable
`OperationError`, which briefly made logout look broken. That bug is fixed independently in
`AuthController` — see `app/lib/features/auth/application/auth_controller.dart`'s `_bootstrap`/
`_safeClear` — by treating any storage failure as "no session" instead of hanging. This ADR is
about the storage *scheme* itself, not that bug.)

## Decision

On web, the refresh token is never written to any Dart/JS-readable storage. Instead:

- `POST /auth/login` sets it as an `httpOnly`, `SameSite=Strict` cookie (`Secure` in production —
  gated off `DEBUG` locally, since `http://localhost` isn't a TLS origin), scoped to the
  `/api/v1/auth` path only.
- `POST /auth/refresh` and `POST /auth/logout` accept the refresh token from that cookie,
  falling back to a `refresh_token` field in the JSON body if the cookie isn't present (see
  `_refresh_token_from_request` in `backend/apps/accounts/views.py`).
- The Flutter web client (`ApiClient`) sends every request with `withCredentials: true` so the
  browser attaches/receives the cookie automatically, and never puts a refresh token in the
  request body itself — see `TokenStorage.saveSession`/`saveTokens` gating writes on `!kIsWeb`
  (`app/lib/core/api/token_storage.dart`).
- The access token issued at login/refresh also carries a `role` claim now (set once on the
  refresh token at login; simplejwt copies refresh-token claims onto every access token derived
  from it, including after rotation) — added so a future access-token-in-memory-only redesign
  (see Consequences) doesn't need a new endpoint just to recover the user's role after a page
  reload.

Native (Android) is unaffected: `flutter_secure_storage` there is real OS-level secure storage,
so the refresh token is still persisted through it exactly as ADR-0003 described.

## Alternatives considered

- **Keep it in `flutter_secure_storage` on web, accept the risk.** Rejected — this app's whole
  reason for tokenized auth is to eventually gate sensitive documents; leaving the long-lived
  credential XSS-readable undercuts that from the start.
- **Full session-cookie auth for web (drop JWTs there entirely).** Would diverge web and mobile
  onto two different auth mechanisms, which is exactly what ADR-0003 chose JWTs to avoid. The
  hybrid here (cookie *transport* for the refresh token, still a JWT, still validated the same
  way server-side) keeps one mechanism while fixing the storage problem specifically.
- **Move the access token to memory-only too, and always silently refresh on app boot.** This is
  the more complete version of "don't persist sensitive tokens client-side," and is the natural
  next step. Not done in this pass: the existing `AuthController`/`TokenStorage` bootstrap
  contract (read a persisted access token + role, else unauthenticated) has real test coverage
  (`app/test/auth_controller_test.dart`) built around persistence, and rearchitecting it to
  "always call `/refresh` on cold start, keep the access token in memory only" is a bigger,
  riskier change than this ADR's scope. Tracked as a follow-up (mandate should-have), not
  abandoned — the `role` JWT claim above already lays the groundwork for it.

## Consequences / trade-offs

- Backend: `LoginView`/`RefreshView`/`LogoutView` now read/set/clear a cookie in addition to (or
  instead of) the JSON body fields; `CORS_ALLOW_CREDENTIALS` and specific (non-wildcard) CORS
  origins are required for the cookie to flow cross-port in dev — already true before this ADR.
- `LogoutSerializer` was removed (unused) — logout's `refresh_token` body field is now optional
  everywhere, since web never has one to send.
- Access token persistence on web is unchanged for now (see Alternatives) — it's still written to
  `flutter_secure_storage`'s web backend. That's a real, smaller residual exposure (bounded by the
  token's ~15 min lifetime) versus the refresh token's 14 days, and is the natural next increment.
- One more moving part in the auth flow (a cookie, alongside the JSON body) — but it's isolated
  to `LoginView`/`RefreshView`/`LogoutView` and the shared `ApiClient`, not spread across the app.

## Reversibility

Cheap to adjust further (e.g. finishing the access-token-in-memory-only follow-up) while only
the auth module depends on this. Would get more expensive once other Phase 2 modules start making
their own assumptions about how the session is carried.
