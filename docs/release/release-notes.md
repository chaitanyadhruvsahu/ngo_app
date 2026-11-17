# Prototype v0.1 release candidate — 11 October 2026

## What is included

The existing app includes fellow authentication/onboarding, profile and private document management, volunteer records, assigned jobs with photo evidence and admin review, notifications and reporting. Recent usability work introduced labeled task cards, responsive layouts, clearer uploads and one completion badge instead of completed-step history.

This release-preparation pass adds:

- A same-origin Flutter web + Django production image and Render blueprint.
- A corrected Python virtual-environment layout so the container's non-root user can import installed packages.
- HTTPS redirect, secure cookies, exact-host checks and short, host-scoped HSTS.
- Shared database-backed throttling cache and pre-deploy migrations/cache creation.
- Database readiness endpoint and a scheduled reminder service definition.
- Fail-closed production checks against development secrets, SQLite, ephemeral upload storage and missing SMTP configuration.
- Correct hash-route email links and preservation of their tokens during authentication bootstrap.
- A keyboard-friendly scrolling password-reset form and safe handling when it is closed during a request.
- Same-origin API defaults for web; explicit API override for split-server development.
- Pinned Flutter release tooling, web artifact upload and container build CI.
- Precompressed web assets (main JavaScript approximately 3.7 MB to 1.0 MB gzip).
- Deployment, operations, user and acceptance documentation.

## Verification completed locally

| Check | Result |
| --- | --- |
| Backend suite on SQLite | 130 tests; pass, 2 environment-dependent skips |
| Backend suite on PostgreSQL 16 | 130 tests; pass, 1 live S3 integration skip |
| Backend Ruff | Pass |
| Migration consistency | No missing migrations |
| Python dependency audit | No known vulnerabilities reported at scan time |
| Flutter analysis | Pass |
| Flutter tests | 28 pass, including email deep-link cold starts |
| Flutter release web build | Pass |
| Render blueprint published JSON Schema validation | Pass; account-side acceptance still required |
| Production release script on isolated PostgreSQL | Checks, migrations and cache-table creation pass |
| Gunicorn + WhiteNoise production-mode smoke | HTTP redirects to HTTPS; trusted-proxy HTTPS root serves web with 200; readiness 200 |

The production configuration check reports two intentional warnings: HSTS is not applied to all subdomains and is not preloaded. This avoids changing the security policy of an NGO's entire domain during the pilot. SMTP and S3 endpoints in the local production smoke test are placeholders, not evidence of live provider connectivity.

## Still to verify before shipping

- Full production container build and provider-side blueprint acceptance.
- Actual hosted SMTP delivery and private S3/R2 upload/download/anonymous denial.
- Hosted end-to-end workflow, phone browsers, backup/recovery and launch sign-off.
- Reviewed release commit and remote publication. All existing uncommitted work is preserved; no release has been pushed by this preparation pass.

This is not a claim of public deployment, app-store readiness, completed penetration testing or legal compliance. See [acceptance](acceptance.md) for the release gates. Signed native Android delivery remains separate. No real-data launch is approved while key custody and NGO policy remain unresolved.
