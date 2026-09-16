# ADR-0002: Backend framework — Django + Django REST Framework

**Status:** Accepted
**Date:** 2026-09-16

## Context

The source requirements docs leave backend framework choice open. Phase 0 cannot be scaffolded
without picking one. The project will hold sensitive data from Phase 2 onward (Aadhaar numbers,
bank details) and is maintained by a small, rotating student engineering team with no dedicated
security or DevOps role.

## Decision

Django + Django REST Framework on PostgreSQL.

## Alternatives considered

- **Node.js/Express + TypeScript:** more familiar to some contributors, but ORM, auth, and
  security middleware (CSRF, password hashing, rate limiting) all have to be assembled
  piece-by-piece — more decisions, more room for a rotating team to misconfigure something
  security-relevant.
- **FastAPI:** modern, fast, good typing story, but a smaller "included battery" set and a
  thinner pattern library to copy from than Django for auth/permissions/admin.

## Consequences / trade-offs

- Django's ORM prevents raw-SQL injection by default; DRF's serializer/permission layers make
  RBAC explicit and unit-testable; Django admin doubles as a free internal DB-inspection tool.
- More opinionated/monolithic than a minimal Express app.
- Python throughput is lower than Node's at very high concurrency — irrelevant at this project's
  expected scale (tens to low hundreds of fellows across 7 blocks).
- Django's own `django.contrib.auth` app already claims the app label `auth`; our Phase 1
  authentication app is therefore named `apps/accounts` rather than `apps/auth` to avoid an
  app-label collision, while still living under the same `/backend/apps/` convention.

## Reversibility

Medium — sits behind a REST boundary the Flutter client doesn't care about, but migrating a
live app with real data would be a multi-week effort. Revisit only if scale grows an order of
magnitude or the app needs to go heavily real-time (websockets-first).
