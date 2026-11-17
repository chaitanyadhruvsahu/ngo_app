# Railway pilot — 17 November 2026

Live app: https://ngoapp-pilot.up.railway.app/#/login

## Deployed release

- Project: `ngo-app`; environment: `pilot`.
- Code commit: `c4dc36f1dfa717fce08eff1a2e7f8e69b1b17681`.
- Source branch: `claude/laughing-bardeen-u2uo0f` (existing repository default).
- Web deployment after bootstrap cleanup: `1b05d58b-23b3-40f5-b3a1-c68ad818a4e9`.
- Reminder deployment: `84466f1f-4213-45b6-84ff-9b231f9cfbaf`.
- PostgreSQL runs privately with a persistent volume. Documents use a private
  Railway S3-compatible bucket. The frontend and API share one HTTPS origin.
- Both application sources are pinned to the code commit above. Pushing another
  commit does not update this pilot until its source pin is deliberately updated.

## Email and accounts

Email is intentionally disabled at the user's request. Public signup,
verification/resend and password-reset endpoints return an explicit unavailable
response. Existing active accounts can sign in normally. The login screen hides
the unavailable links and directs people to their NGO administrator.

Initial accounts: `admin@ngo-pilot.test` and `fellow@ngo-pilot.test`.
Their random passwords are in the owner's protected local file
`/Users/chaitanyasahu/.ssh/ngo_app_railway_pilot.env`. That file also contains the
encryption/recovery keys: do not distribute the entire file as a user guide.
Share only the appropriate account credentials through an agreed private channel.
No password, token or production key is committed in this document.

Initial account provisioning ran once. The web pre-deploy command is now
`sh /app/deploy/release.sh`; bootstrap email/password variables have been cleared.
Subsequent releases do not reset or re-provision these accounts.

## Verified on the hosted pilot

- Readiness and public configuration endpoints return expected results.
- Admin and fellow login, HttpOnly-cookie refresh and logout pass.
- Anonymous job access is denied; fellows cannot access the admin directory.
- Signup and email recovery are disabled server-side, without sending email.
- The actual web login screen loads and omits signup/reset links.
- Private bucket upload, preview and download return matching bytes; preview
  uses inline disposition, download uses attachment, and anonymous reads fail.
- Reminder service completed a run: `Delivered 0 notification(s).` It is scheduled
  every five minutes; no notifications were due in the initially empty database.
- One synthetic 1-pixel image named `deployment-check-no-personal-data.png` is
  retained under the pilot fellow's Other documents for deployment evidence.

Local pre-release checks: Flutter analysis and web build pass; 142 backend tests
pass with two environment-dependent skips. Native/mobile deployment is not part
of this hosted web release. Cloud end-to-end job review and recovery from backups
have not been certified by these checks.

## Operations

Readiness: `/api/v1/ready`. Application administration: `/admin/` (separate from
the frontend's `/#/admin` dashboard). Authorized staff can manually create active
users and fellow profiles there while email is unavailable. Account/password
assistance is manual; use unique passwords and do not reuse the pilot accounts
for normal NGO operations.

See `railway.md` to enable email later, and `acceptance.md`, `deployment.md` and
`../encryption-key-custody.md` for the real-data pilot and recovery checks.
