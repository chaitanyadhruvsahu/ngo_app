# Phase 4 and provisional Phase 6 contract

Frozen 2026-09-21 before paired UI work.

Blocks have UUID identity plus canonical integer `number`: 3, 7, 14, 19,
27, 29, 32. GET `/api/v1/blocks` returns only active mapped blocks, with
`id`, `number`, `name`. Old rows stay inactive/unmapped and retain all FK
references; no guess is made about where old fellows belong.

Admin lists `/admin/fellows`, `/jobs` (existing admin job GET), and new
`/admin/volunteers` accept optional `block=<number>`. `/admin/jobs` is a
compatibility alias for the existing job list. Invalid numbers return 400.
All these lists use count/next/previous/results pagination, page_size <=100.
Volunteer rows contain id, full_name, phone_number, fellow_id, fellow_name,
block_number. No household data appears in the cross-fellow summary.

GET `/admin/exports/{export_type}` returns XLSX. Exactly two types exist:
`fellow_contact_list` (Fellow ID, Name, Email, Phone, Block) and
`event_participant_list` (Volunteer ID, Name, Phone, Fellow, Block,
Participation status). Optional block filter applies to both.
There is no event registration or attendance model: the second export is
explicitly a **candidate contact roster**, with every row marked
"Candidate — attendance not recorded". Its download and UI say this.
It does not claim that a volunteer attended or registered for any event.

Only explicitly allowlisted columns are selected in SQL; Aadhaar/bank
values are never read. Spreadsheet strings use inline string cells, so
leading `=`, `+`, `-` and `@` remain text, never executable formulas.
The file is fully generated in memory, then ExportLog is persisted before
returning a response. Validation/generation failures are not logged because
no file was generated; logging failure prevents download. Network interruption
after generation still leaves the log, whose meaning is "generated", not
"client successfully saved". Responses have private, no-store caching.
GET `/admin/exports` returns only the current admin's paginated history:
id, export_type, filters, run_at. No audit write endpoint.

GET `/admin/dashboard/blocks` returns `results` of all seven canonical blocks:
block_number, fellow_count, job_count, expected_hours, approved_hours,
submission_count, approval_count. GET `/admin/dashboard/fellows/{profile_uuid}`
returns the same job measures plus fellow_id and full_name. Decimal hours are
strings. Jobs/expected hours are counted once per job; all submissions are
counted separately; only approved submissions contribute approved hours.
Job assignments use the current assignee/block; submissions use the actual
submitting fellow's current block. Reassignment does not attribute the old
fellow's work to the new one. No sums across joins to photos/transitions.
Dashboards are a provisional read-only skeleton, with no stipend formula,
payment status writes, or verification integration.

Every new endpoint is Admin-only (anonymous 401, fellow 403); unknown fellow
is 404. No extra export types or speculative reporting engine.
