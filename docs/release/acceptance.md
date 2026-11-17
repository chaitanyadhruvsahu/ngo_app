# First-pilot acceptance checklist

Unchecked items are not yet verified on the hosted environment. Record tester, date, release SHA and evidence without including secrets.

## Before public invitations

- [ ] Hosting account owner, budget and support contact approved.
- [ ] Reviewed release commit pushed; automated tests and production image build pass.
- [ ] Render blueprint accepted; migrations and cache table creation succeed.
- [ ] Public HTTPS URL opens on desktop, Android Chrome and iPhone Safari.
- [ ] Signup email reaches a real test inbox; its link works in a newly opened browser.
- [ ] Password-reset link works on a cold start; used/expired links fail safely.
- [ ] Login, reload, logout and login again behave correctly; no localhost API requests.
- [ ] Profile save, sample document upload/download and job photo submission succeed.
- [ ] Wrong file type/oversize file and interrupted upload display usable errors.
- [ ] Another fellow cannot view the first fellow's private files or admin endpoints.
- [ ] Bucket has no public access; anonymous direct file access fails.
- [ ] Admin creates/assigns a job and sees the fellow's submission.
- [ ] Scheduled announcement delivers once; cron failures are visible to operations.
- [ ] Reports and exported sample data match the test records.
- [ ] Narrow phone screen, keyboard, camera permission denial, English/Hindi and larger text checked.
- [ ] Database and files persist across a web service redeploy.
- [ ] Monitoring, backup retention, recovery procedure and previous-release rollback reviewed.
- [ ] Pilot coordinator signs off sample-data use and receives user guide.

## Additional gates before real personal data

- [ ] NGO has approved hosting geography, data collection, consent, retention/deletion and enrollment policy.
- [ ] Required consent/enrollment product changes are implemented and tested.
- [ ] Primary and backup encryption-key custodians named; key escrow access verified.
- [ ] Witnessed recovery drill restores database, private object and encrypted field in isolation.
- [ ] Production credentials are unique; demo accounts/keys absent; staff access reviewed.
- [ ] Dependency/security review and privacy review completed for the deployment.

No custodian is currently designated. These gates cannot be signed off by code changes alone.
