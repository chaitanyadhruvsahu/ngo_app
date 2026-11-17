# Railway pilot deployment

The root Dockerfile builds Flutter web and Django into one service. Use this guide
instead of the Render blueprint for Railway. This is a release candidate: remaining
job-screen and fellow-dashboard design work has not been completed.

## Web service

Connect the private GitHub repository `chaitanyadhruvsahu/ngo_app`, select the
reviewed release branch, and keep the source root at `/`. Railway detects the
root Dockerfile. In the service dashboard configure:

- Pre-deploy command: `sh /app/deploy/release.sh`
- Start command: `sh /app/deploy/start.sh`
- Healthcheck: `/api/v1/ready`
- Healthcheck timeout: 120 seconds
- One replica initially; the server binds to Railway's injected `PORT`.

Configure these in the dashboard. Railway's current documentation deprecates
`railway.json` and `railway.toml` for new services:
https://docs.railway.com/config-as-code

Generate a public HTTPS domain and add a PostgreSQL service. Set runtime variables:

| Variable | Value |
| --- | --- |
| `DJANGO_SETTINGS_MODULE` | `config.production` |
| `DATABASE_URL` | Reference to the PostgreSQL service's private `DATABASE_URL` |
| `DJANGO_SECRET_KEY` | Unique random secret, at least 50 characters |
| `FIELD_ENCRYPTION_KEY` | New production Fernet key, independently backed up |
| `FRONTEND_BASE_URL` | `https://` followed by the generated public domain |
| `DJANGO_ALLOWED_HOSTS` | Public domain plus `healthcheck.railway.app`, comma-separated |
| `STORAGE_BACKEND` | `s3` |
| `S3_BUCKET_NAME` | Actual S3 API bucket name from bucket credentials |
| `S3_ENDPOINT_URL` | HTTPS S3 endpoint from bucket credentials |
| `S3_REGION_NAME` | Region from bucket credentials |
| `S3_ADDRESSING_STYLE` | `virtual` for current Railway buckets; confirm credentials |
| `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | Private bucket credentials |
| `EMAIL_BACKEND` | `django.core.mail.backends.smtp.EmailBackend` |
| `EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | Transactional SMTP provider credentials |
| `EMAIL_PORT` | `587` |
| `EMAIL_USE_TLS` | `True` |
| `DEFAULT_FROM_EMAIL` | Verified sender address |
| `JOB_REMINDER_TIME_ZONE` | `Asia/Kolkata` |

Never commit runtime credentials or copy local test/demo keys into production.
The production checks deliberately reject missing SMTP, private storage or database
configuration. Do not bypass these checks. Confirm outbound SMTP support on the
selected Railway plan before enabling signup.

Keep uploads in the private bucket. Container files disappear on redeploy. Backend
authorization continues to protect document/photo reads; do not expose the bucket.

## Reminders

After database migrations succeed, add a second service from the same repository
and image configuration. Override its start command to
`python manage.py deliver_notifications`, leave its healthcheck unset, and set the
cron schedule to `*/5 * * * *`. Share the database and relevant application secrets,
public URL, production settings, storage and SMTP configuration with the web service.
Do not give this service a public domain. Its command exits when delivery finishes.
Do not let the web service's start/pre-deploy commands override the cron settings.

Railway schedules use UTC and have a five-minute minimum interval. Allow a few
minutes of delivery delay. See https://docs.railway.com/cron-jobs.

## Release verification

Create the first admin once with `python manage.py createsuperuser`. Do not run
`seed_admin` on every deployment because it can reset an existing password.

Use fictional data first. Verify HTTPS, readiness, email verification and reset,
session refresh, job assignment/submission/review, reminders, private document
preview/download and unauthorized access denial. Enable database backups and
establish document backup/recovery and encryption-key custody before real-data use.
Record the deployed commit and URL. Follow `acceptance.md` for the pilot checks.

The source push does not itself prove the image builds or that Railway, SMTP and
storage work. Complete hosted acceptance before inviting fellows.
