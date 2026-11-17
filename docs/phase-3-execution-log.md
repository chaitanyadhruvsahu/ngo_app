# Phase 3 execution log

Implementation started from the user-provided Phase 3 mandate on 2026-09-20 and was completed
against `/Users/chaitanyasahu/ngo_app`. Existing uncommitted Phase 2 work was preserved.

## Delivered

- Froze the jobs API before UI work in `phase-3-api-contract.md`.
- Added the complete Admin → Fellow → Admin workflow: create/assign, start, submit actual hours
  and 1–5 photos, approve, reject with mandatory reason, resubmit, and reasoned reassignment.
- Persisted append-only submissions and status transitions. Reviews carry the submission ID to
  reject stale decisions; all mutations lock the job row.
- Scoped fellow reads to the current assignment revision. A former assignee receives 404 after
  reassignment and a new assignee cannot see the former fellow's evidence or rejection reason.
- Kept `internal_note` Admin-only in API serializers and UI.
- Validated actual image bytes, bounded upload size/pixel count, extracted best-effort EXIF capture
  time, then re-encoded images to strip EXIF/GPS before private storage.
- Added native Android camera capture. Web evidence selection is clearly labeled as browser
  evidence and does not claim proof of live capture.
- Added optional opt-in location capture behind `JOB_GEOTAG_ENABLED=False`. Missing, denied, or
  malformed location is discarded and never blocks work; coordinate reads create access logs.
- Upgraded to Django 5.2.17 and generalized private storage to local or S3-compatible
  S3/R2/MinIO. Added MinIO-backed CI/integration coverage and operator/key-custody runbooks.
- Added English/Hindi job copy, block display in Admin views, normalized API/storage failures,
  multipart retry rebuilding, and token-refresh recursion protection.

## Verification evidence

- Browser acceptance (release web build + disposable local API): Admin created and assigned
  “Village health survey”; Asha started it, submitted 3.25 hours and one browser-evidence image;
  Admin viewed the immutable submission/history and approved it.
- Flutter: all 16 tests pass; `flutter analyze` reports no issues; release web build succeeds.
- Backend: Ruff, Django system checks, and migration drift checks pass. All 109 tests pass; one
  additional credentialed real-S3 test is intentionally skipped in the default suite.
- Infrastructure: a real MinIO-compatible run passed all 3 storage integration tests; `pip-audit`
  reported no known vulnerabilities in the pinned backend dependencies.

## Residual acceptance items

- This Mac has no Android SDK and the repository has no iOS runner. Native camera permission and
  capture must be smoke-tested on an Android device/CI APK before production release. Browser
  evidence is only a web fallback and is labeled accordingly.
- Production R2/S3 credentials were not available. The implementation was exercised against
  MinIO; deployment must run the documented credentialed smoke test.
- The NGO must name the long-term encryption-key custodian and perform a recovery drill.
- Android process death while the camera app is open currently requires the fellow to retake the
  photo; automatic pending-capture recovery is intentionally deferred to avoid stale evidence
  crossing accounts or jobs.
