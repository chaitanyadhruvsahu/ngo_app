# ADR-0003: Auth transport — JWT (access + refresh), not session cookies

**Status:** Accepted
**Date:** 2026-09-16

## Context

The same client codebase (ADR-0001) has to authenticate from a browser tab and from a native
Android process. Native apps don't participate in cookie-based session flows the way a browser
does.

## Decision

Use `djangorestframework-simplejwt`: short-lived access tokens (~15 min) and rotating refresh
tokens (~14 days) with server-side blacklisting on logout and on password reset.

## Alternatives considered

- **Django session + cookie auth:** simpler for the web build alone, but would still need a
  separate token-based path for Android — two auth mechanisms instead of one.

## Consequences / trade-offs

- Requires a blacklist table (`rest_framework_simplejwt.token_blacklist`) and slightly more
  backend bookkeeping for "log out everywhere."
- One auth code path serves both platforms.
- Tokens stored client-side via `flutter_secure_storage`, never in plain `SharedPreferences`.

## Reversibility

Medium-low once client storage/refresh logic is built around it — this is why it's decided
correctly now, in Phase 1, rather than deferred.
