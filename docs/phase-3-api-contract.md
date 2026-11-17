# Phase 3 jobs API — contract v1

Frozen for parallel implementation on 2026-09-20. Base `/api/v1`; no trailing
slash on job routes. Auth uses the existing shared JWT client and error envelope.
UUIDs are strings, hours are positive decimal strings (max 9999.99), dates are
YYYY-MM-DD, timestamps ISO 8601 UTC. Lists use `{count,next,previous,results}`,
25/page (max 100), `page`/`page_size`. Order is newest first.

## Decisions resolving mandate ambiguities

The mandate says five states but enumerates six and requests REASSIGNED.
Persisted states: created, assigned, in_progress, submitted, approved, rejected.
`reassigned` is an audit-only intermediate state. Create records null→created
and created→assigned. Reassign records old→reassigned→assigned atomically.
Allowed: assigned→in_progress/submitted; in_progress→submitted;
submitted→approved/rejected; rejected→in_progress/submitted.
Reassign allowed from assigned/in_progress/rejected, never submitted/approved.
Title/description/hours/deadline may be edited only while assigned and before
any work has started or been submitted. Admin-only internal_note may be patched
at any time. Assignment changes use the dedicated endpoint.

Assignment revisions preserve full Admin history while a fellow receives only
the current assignment's submissions/transitions. After reassignment the former
fellow gets 404, and the new fellow cannot read earlier fellows' evidence or notes.
Audit rows record old/new assignees and revision for attribution.

## Endpoints

| Method/path | Role | Input/result |
|---|---|---|
| GET /jobs/config | Admin/Fellow | `{geotag_enabled:false,max_photos:5}` |
| GET /jobs | Admin | Paginated jobs; optional `fellow` UUID and `status` |
| POST /jobs | Admin | `{assigned_to,title,description,expected_hours,deadline?,internal_note?}` → detail, 201 |
| GET /jobs/mine | Fellow | Paginated own jobs; optional `status` |
| GET /jobs/{id} | Admin/current Fellow | detail |
| PATCH /jobs/{id} | Admin | allowed edit fields above → detail |
| POST /jobs/{id}/start | Fellow | empty body → detail |
| POST /jobs/{id}/submissions | Fellow | multipart `actual_hours`, repeated `photos` (1–5 JPEG/PNG), optional `device_timestamp`, `geotag_lat`, `geotag_lng`, `location_consent` → detail, 201 |
| POST /jobs/{id}/review | Admin | `{submission_id,decision:"approved" or "rejected",reason?}` → detail; rejection requires nonblank reason |
| POST /jobs/{id}/reassign | Admin | `{assigned_to,reason}` (nonblank) → detail |
| GET /jobs/{id}/photos/{photo_id} | Admin/current submitting Fellow | authenticated image bytes, private/no-store; access logged |

Job list/detail common fields: `id,created_by,assigned_to,assigned_to_name,title,
description,expected_hours,deadline,status,created_at,updated_at`.
Admin alone also receives `internal_note`. Detail additionally includes
`submissions,transitions,can_edit,can_reassign`.

Submission: `id,submitted_by,actual_hours,submitted_at,device_timestamp,
geotag_lat,geotag_lng,reviewed_by,review_status,review_reason,reviewed_at,photos`.
Photo: `id,content_type,size_bytes,checksum_sha256,exif_captured_at,uploaded_at`.
Photo paths/keys are never serialized; derive the authenticated route above.
Transition: `id,from_status,to_status,actor,reason,from_assignee,to_assignee,
created_at`. Fellow output excludes admin reassignment reasons.

401 anonymous; 403 wrong role; 404 invisible object; 400 invalid input; 409
invalid/stale lifecycle operation; 503 storage unavailable. Review requires the
pending latest submission ID to prevent a stale screen reviewing a new attempt.
Mutations lock the job row within a database transaction.

## Capture and privacy

Mobile uses image_picker `ImageSource.camera`, one photo per capture; no gallery
path. Web camera selection cannot establish trustworthy camera provenance and
is explicitly labeled as browser evidence. Neither EXIF nor client timestamps
prove authenticity: they are untrusted supporting signals for manual review.
Server decodes images, extracts best-effort EXIF capture time and strips metadata
(including GPS) before storing. No PDF evidence. Optional metadata failures do
not block submission. Geotags persist only when server JOB_GEOTAG_ENABLED is
true AND the fellow opts in on that submission; default is disabled. Location
detail reads and all photo reads are access logged. No location in list responses.

Client disables mutations during requests and refreshes detail after success;
invalid transitions remain enforced server-side. Authenticated multipart retries
must recreate consumed FormData. Backend stores each resubmission separately.
