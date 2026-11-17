# Hosting and operations — prototype v0.1

## Architecture and scope

Use the repository's `render.yaml` blueprint for a paid Render web service, PostgreSQL database and minute-by-minute reminder job. The root Docker image contains Flutter web and Django/Gunicorn. Both are served at one HTTPS origin, so no separate frontend domain or cross-site refresh cookie is needed. WhiteNoise serves only compiled frontend/admin assets; private uploads are served through authorized API endpoints from a private S3-compatible bucket.

This extends [ADR 0006](../adr/0006-hosting-render.md): for the first pilot, bundle the frontend into the backend deployment instead of a separate static site. Keep the current hash routes (`/#/login`). The frontend derives `/api/v1` from its host; do not compile a localhost API URL into the release.

Use Singapore as the provisional Render region, subject to the NGO approving hosting geography. This is not a statement of data-residency or legal compliance. The bucket's location/jurisdiction needs approval too.

Provider references: [Render blueprints](https://render.com/docs/blueprint-spec), [Django deployment](https://render.com/docs/deploy-django), [cron jobs](https://render.com/docs/cronjobs), [current pricing](https://render.com/pricing), and [WhiteNoise](https://whitenoise.readthedocs.io/en/stable/django.html). Check the actual quotation in each provider console before creating resources; include web, database, cron, storage, email, bandwidth and taxes. No monthly cost has been approved. The blueprint uses paid plans, not an ephemeral free database.

## Accounts and launch decisions

- NGO-owned Render account with MFA and billing; GitHub repository access granted only to this project.
- Private bucket (Cloudflare R2 or AWS S3), with bucket-scoped credentials. Public access disabled. No public development URL or public ACL. Enable the provider's available backup/version recovery safeguards and test them; a live bucket alone is not a backup.
- Transactional SMTP service and verified sender domain, including provider-required DNS records. Do not use personal email credentials. This deployment expects STARTTLS on port 587.
- Domain is optional for the prototype: the Render HTTPS hostname works. A custom domain can be added later.
- Named operations owner and support contact. Before real data: consent/retention decisions, key custodians and a witnessed recovery drill; see [key custody](../encryption-key-custody.md) and [open questions](../open-questions.md).

## Prepare the source

The working tree currently includes substantial uncommitted work from earlier phases. Review it, run tests, and create a reviewed release commit before deploying. Preserve existing work; do not reset the tree. The cloud can build only committed/pushed files, not this computer's uncommitted changes. Never commit `.env`, SQLite databases, private files, signing keys or passwords. Review `git diff --cached` and run the repository's secret checks before pushing.

Local checks from the respective directories:

```sh
# app/
flutter analyze --fatal-infos
flutter test
flutter build web --release --pwa-strategy=none

# backend/ with an isolated test database and a test FIELD_ENCRYPTION_KEY
.venv/bin/ruff check --no-cache .
.venv/bin/python manage.py test apps --noinput

# repository root
docker build -t ngo-prototype:rc1 .
```

Flutter is pinned to 3.47.4 in the release Dockerfile and Flutter CI. Review dependency security reports before a real-data launch; passing functional tests is not a security audit.

## Configure and deploy

1. Create the private bucket and SMTP sender first. Do not upload real documents yet.
2. In Render, create a Blueprint from the reviewed GitHub branch containing `render.yaml`. Review the plan costs before confirming creation. Auto-deploy is disabled intentionally.
3. Enter secrets directly into the provider dashboard/password manager, never chat or source control:

| Setting | Value / purpose |
| --- | --- |
| `DJANGO_SECRET_KEY` | Unique cryptographic random string, at least 50 characters |
| `FIELD_ENCRYPTION_KEY` | Fernet key generated once; keep an independent protected backup |
| `S3_BUCKET_NAME` | Private pilot bucket |
| `S3_ENDPOINT_URL` | HTTPS provider endpoint (R2 account endpoint, not public bucket URL) |
| `S3_REGION_NAME` | `auto` for R2; appropriate AWS region for S3 |
| `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | Bucket-scoped server credentials |
| `EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | SMTP provider settings |
| `DEFAULT_FROM_EMAIL` | Verified sender address, e.g. `support@your-ngo-domain` |

Generate production secrets privately using a password manager or Python `secrets.token_urlsafe(64)` and `cryptography.fernet.Fernet.generate_key()`. Do not reuse any test key in this repository's test instructions. Losing the field encryption key can make stored financial/identity fields unrecoverable even if the database backup exists.

The blueprint wires the database URL and shares the application/encryption secrets with the reminder service. For an AWS IAM setup instead of explicit keys, adapt the configuration deliberately; Render does not automatically supply AWS role credentials. R2 defaults are not universal S3 defaults.

After rotating a shared secret, synchronize the Blueprint and redeploy both services: cross-service environment references update on Blueprint sync, not immediately after editing a secret. Preserve old encryption keys during the documented rotation window.

4. Deploy the web service. Its pre-deploy step checks production settings, migrates the database, and creates the shared throttling cache table. Its startup repeats the configuration check. Do not bypass a failed check to get a green deployment.
5. In the service shell, run `python manage.py createsuperuser` once, interactively. Use a unique staff email and password. This creates an active admin role. Do not automatically run `seed_admin` at each deploy: it resets an existing admin password.
6. Deploy/enable the reminder cron only after migrations succeed. It runs `python manage.py deliver_notifications` every minute. Check execution logs and create a test scheduled announcement; verify recipients receive it once.
7. Open `https://YOUR-SERVICE.onrender.com/` and `/api/v1/ready`. Complete the entire [acceptance checklist](acceptance.md), including live email, uploads, browser refresh and permission denials.
8. Record URL, commit SHA, date, environment owners and acceptance evidence. Only then send the pilot invitation with the user guide.

For a custom domain set `FRONTEND_BASE_URL=https://your-domain`, and `DJANGO_ALLOWED_HOSTS=your-domain,YOUR-SERVICE.onrender.com` on the web service. Keep frontend/API on this one origin. HTTPS/proxy trust is intended for Render's trusted reverse proxy; do not expose this configuration directly behind an untrusted forwarding proxy.

## Operations and recovery

- `/api/v1/health` is liveness; `/api/v1/ready` checks the database. Neither proves SMTP or object storage works. Monitor all service errors and run a periodic authorized sample upload/email check.
- Review failures daily during the pilot. Logs must not contain tokens, Aadhaar/bank values, document bodies or credentials. Use request IDs and redacted screenshots when reporting issues.
- Watch memory, latency, database size/connections, SMTP failures and bucket usage. The minimum plans are a pilot starting point, not a tested capacity guarantee. Upgrade based on measurements.
- Enable provider-managed database backups with a retention period agreed by the NGO. Keep a separately protected export/recovery copy according to the approved policy. Verify the plan's actual backup retention, not an assumed feature.
- Recovery requires a matched database backup, private objects and field-encryption keys. Restore to an isolated environment, verify one encrypted record and one private document with authorization, and record the result before approving real data. Never test restoration by overwriting the live database.
- Keep the previous release SHA/image available. For a code-only regression, pause the reminder job if needed and redeploy the previous compatible release. A code rollback does not undo database migrations. Before schema changes, back up and review reversibility; for destructive changes plan a tested restore/forward fix.
- Key rotation must follow [key custody](../encryption-key-custody.md); never replace the sole key casually. For an incident, restrict access, preserve logs, revoke exposed credentials and involve the named NGO data owner.
- Do not delete services, buckets or databases to troubleshoot a failed deploy. Avoid demo data and production data in the same environment.

## Explicitly outside this release

Signed Android/store distribution, native download verification, offline sync, WhatsApp delivery, agreed stipend formulas and a completed consent workflow are not part of the web pilot sign-off. The public signup flow currently activates a fellow after email verification; there is no NGO-approved manual approval gate. For a restricted real-data pilot, decide and implement the required enrollment policy before launch.
