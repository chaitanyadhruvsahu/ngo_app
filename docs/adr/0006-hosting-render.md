# ADR-0006: Hosting — Render for backend + managed Postgres, static hosting for Flutter web, CI-built APK

**Status:** Accepted
**Date:** 2026-09-16

## Context

The team has no dedicated DevOps role and will hand the project off to a new cohort of student
engineers at the end of each semester.

## Decision

- Backend (Django) and managed PostgreSQL hosted on Render, auto-deployed from `main`.
- Flutter web build published to static hosting.
- Android APK built in CI and attached to GitHub Releases as a downloadable artifact.

## Alternatives considered

- **Raw AWS/GCP:** more powerful and cheaper at scale, but meaningfully more operational
  complexity and a bigger handover burden for a team that changes every semester.

## Consequences / trade-offs

- Predictable pricing, GitHub-integrated auto-deploy, a simple secrets UI.
- The Django app is containerized from Phase 0 (see `/backend/Dockerfile`) so a future host
  change stays cheap.

## Reversibility

Medium-high, specifically because of the Phase 0 containerization requirement above.
