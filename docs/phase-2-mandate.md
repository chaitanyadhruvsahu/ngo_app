# Phase 2 Engineering Mandate
## Fellow Profile, Documents & Volunteer Mapping

**Date:** 2026-09-16
**Status:** Active — ready to begin. Depends on Phase 1 (closed; see `phase-1-mandate.md` and its execution log)
**Issued by:** Head of Engineering
**Audience:** Engineering team

---

## A. Engineering Executive Summary

This phase turns an authenticated-but-empty account into a fully onboarded fellow: profile data, uploaded documents (Aadhaar, marksheet, bank details, photo), and self-managed volunteer records — plus read-only Admin visibility into all of it. It is also the **first phase with real role-gated endpoints**, so the server-side RBAC test debt deferred from Phase 1 gets paid here, on the first endpoint, not the third.

The central engineering theme is **data sensitivity without an approval workflow**: the NGO explicitly doesn't want document review/approval, but Aadhaar and bank data are high-sensitivity regardless of whether a human ever looks at them. That shapes almost every decision below — storage architecture, encryption, access logging, and error-response design all exist because "no approval needed" was never "handle this casually."

Major decisions: dedicated S3-compatible object storage (not local disk, not DB blobs); application-level field encryption for structured Aadhaar/bank values in addition to storage-level encryption; backend-proxied uploads (not presigned direct-to-bucket) to keep this phase simple for a small team; and a documented local-storage fallback for developers without Docker, mirroring the SQLite fallback pattern already established in Phase 1.

Biggest risk: the exact structured fields for Aadhaar/bank data were never fully specified in the source documents — see Assumptions below. Getting the schema wrong here is expensive, because encrypted columns are painful to migrate after real data exists.

---

## B. Assumptions & Open Questions

Flagging these explicitly rather than silently building around them:

1. **Assumption — structured sensitive fields exist beyond uploaded files.** The master doc's §8 calls for encryption of "database fields containing Aadhaar/bank details," which implies the profile form captures some of this as typed fields (Aadhaar number, bank account number, IFSC code, account holder name) — not just scanned document uploads. **Confirm the exact field list before schema freeze** (§7 below assumes a reasonable set; changing it after real data exists means a migration touching encrypted columns).
2. **Assumption — one active document per type, with history retained.** The master doc doesn't say whether a fellow can replace a previously uploaded document. Assuming yes: a new upload of the same type supersedes the old one (soft-deleted, not hard-overwritten), preserving an audit trail consistent with how the rest of this app treats timestamped history. Flag if the NGO actually wants strict single-upload-only or unlimited-versions-visible-to-Admin instead.
3. **Assumption — Phase 2's Admin browsing is a flat list, not block-filtered.** Block-based filtering is explicitly Phase 4 scope per the roadmap. Phase 2 gives Admin a paginated list + individual read-only detail view; `block_id` is stored on every record (already true) but no filter UI/query param ships yet.
4. **Open — data consent policy (master doc §12, item 3) is still unanswered.** Not blocking this phase's build: `consent_given_at` is modeled as a nullable field on `FellowProfile` now, per the master doc's own suggestion, so the schema doesn't need a migration once the NGO answers. Do not build a consent *flow* (checkbox, forced gate) until that answer arrives.
5. **Assumption — no malware/AV scanning on uploads in v1.** Given team size and no stated compliance requirement, MIME-type validation (not just trusting the client-supplied `Content-Type`) plus a size limit is the v1 bar. Flag as a `Could-have` to revisit if this app is ever exposed to a wider, less-trusted user base.

---

## C. Target Architecture (additions this phase)

```
Fellow (Flutter app)
   │  multipart upload / profile PATCH / volunteer CRUD
   ▼
Backend API (Django/DRF)
   │                              │
   │  DB writes (profile,         │  storage writes (documents only)
   │  volunteer, metadata)        │
   ▼                              ▼
PostgreSQL                  Object Storage (S3-compatible)
   │  encrypted columns          │  server-side encryption at rest
   │  (Aadhaar/bank fields)      │  no public bucket access — ever
   ▼
DocumentAccessLog (append-only, every read/download logged)

Admin (Flutter app, read-only for this phase)
   │  GET-only endpoints, same backend, same RBAC layer
   ▼
Same DB / storage, scoped by permission checks — never a separate data path
```

Key architectural rule: **the client never talks to object storage directly.** Every document read or write is brokered through the backend so access control, logging, and encryption stay server-side and testable — this is non-negotiable given §8 of the master doc.

---

## D. Objective & Scope

**Objective:** A fellow can fully complete onboarding — profile, documents, volunteers — and an Admin can find and view any fellow's complete record, read-only.

**In scope:**
- Full fellow profile fields (structured data, not just documents)
- Document upload (Aadhaar, marksheet, bank statement, photo, other) with encrypted, access-controlled storage
- Volunteer mapping by the fellow, with validation and duplicate detection
- Admin: paginated fellow list, read-only profile/document/volunteer detail views
- Access logging for document reads
- Paying off the Phase 1 RBAC test debt on these new endpoints

**Explicitly out of scope (do not build yet):**
- Document approval/review workflow (per master doc §5.1 — upload alone is sufficient)
- Block-based filtering in the Admin UI (Phase 4)
- Government Aadhaar verification integration (optional, budget-gated, later phase)
- Consent *flow* UI (schema field only, per Assumption 4 above)
- Any job/task functionality (Phase 3)

---

## E. Engineering Mandates (non-negotiable)

1. No client ever receives a raw, permanent storage URL for a document — only short-lived, backend-issued access, and only after a server-side ownership/role check.
2. Every document read is logged (`DocumentAccessLog`) — no exceptions, including Admin reads.
3. Aadhaar and bank-related structured fields are encrypted at the application layer, not just relying on storage/disk encryption.
4. Every new endpoint that distinguishes Fellow vs. Admin access ships with an automated 403/404 test in the same PR — this phase does not get to defer that debt again.
5. Cross-fellow access attempts (Fellow A requesting Fellow B's document/profile/volunteer by ID) return `404`, not `403` — don't confirm to an unauthorized caller that a given ID exists.
6. Uploads are validated by actual file content/MIME sniffing, not the client-supplied `Content-Type` header alone.

---

## F. Technology Decisions

### Decision 1 — Object storage provider

**Context:** Documents need dedicated object storage, accessed only via the backend, per the master doc.
**Recommendation:** S3-compatible storage via `django-storages`, provisioned on **Cloudflare R2** rather than raw AWS S3.
**Rationale:** R2 has no egress fees — relevant because Admin will repeatedly view/download fellow documents, and recurring egress charges compound over the life of a budget-constrained NGO project. R2's S3-compatible API means `django-storages`'s `S3Boto3Storage` backend works unmodified, and local dev can run against MinIO (a self-hosted S3-compatible emulator) with zero code branching between environments.
**Alternatives considered:** AWS S3 (mature, but egress costs are the wrong shape for this project's budget); GCS (no meaningful advantage here); local disk (rejected outright — doesn't meet the "dedicated object storage" requirement, complicates backup/DR, ties storage lifecycle to server lifecycle).
**Trade-offs:** R2 has a shorter operational track record than S3; mitigated by the S3-compatible abstraction making a future provider swap a config change, not a rewrite.
**Reversibility:** High.
**Trigger to reconsider:** Demonstrated R2 reliability issues, or the NGO's hosting consolidating onto a cloud provider where native storage becomes operationally simpler.

### Decision 2 — Field-level encryption for structured sensitive data

**Context:** Master doc §8 wants encryption for "database fields containing Aadhaar/bank details" — a threat model broader than disk theft (a leaked DB credential, an overly broad query, an admin-panel misconfiguration).
**Recommendation:** Encrypt Aadhaar number, bank account number, and IFSC code at the application layer (e.g. `django-cryptography`'s encrypted field types, or a pgcrypto-backed column), in addition to the object storage provider's server-side encryption for uploaded file contents.
**Rationale:** Disk-level encryption alone doesn't protect against a leaked credential or a query that returns more than intended — the actual realistic risk for a small team's app. Column-level encryption means a full table dump still doesn't expose these values in plaintext.
**Alternatives considered:** Rely solely on Postgres disk encryption (rejected — doesn't cover the credential/query-misuse threat model); third-party tokenization/vault service (rejected for v1 — real infra cost for a small team; revisit if this scales beyond the current NGO or a compliance requirement appears).
**Trade-offs:** Encrypted columns can't be queried/filtered directly (`WHERE aadhaar_number = ...` won't work) — acceptable, since nothing in the spec requires searching by these values.
**Reversibility:** Medium — migrating encrypted↔plaintext later touches every existing row. Decide before real data is entered, not after.
**Trigger to reconsider:** None needed — implement now.

### Decision 3 — Upload path: backend-proxied, not presigned direct-to-bucket

**Context:** Uploads could go client → backend → storage, or client could get a presigned URL and upload directly to the bucket.
**Recommendation:** Backend-proxied for v1 (client uploads to the backend; backend validates, then writes to storage).
**Rationale:** Simpler to reason about and secure for a small, rotating team — validation, encryption metadata, and the DB record all happen in one code path with no second round-trip to confirm completion. "Boring, proven" over a more scalable but more complex two-phase flow this phase doesn't need yet.
**Trade-offs:** More bandwidth through the backend server than a direct-upload flow. Acceptable at this scale (a fellowship program, not a mass-market app).
**Reversibility:** Medium — revisiting this means adding a presigned-URL flow and a completion-confirmation endpoint later, which is additive, not a rewrite.
**Trigger to reconsider:** Upload volume or backend bandwidth becomes a measurable cost/performance problem.

---

## G. Data Architecture

### `FellowProfile` (extends the existing model from Phase 1)

| Field | Type | Notes |
|---|---|---|
| `user` | FK → User, one-to-one | Already exists |
| `block` | FK → Block | Already exists |
| `full_name` | text | |
| `date_of_birth` | date | |
| `phone_number` | text, normalized | Validated on write |
| `address` | text | |
| `aadhaar_number` | encrypted text | Decision 2 |
| `bank_account_number` | encrypted text | Decision 2 |
| `bank_ifsc` | encrypted text | Decision 2 |
| `bank_account_holder_name` | text | Not encrypted — a name alone isn't the sensitive part; the account number/IFSC pairing is |
| `onboarding_step` | enum | Already exists (currently not read by the frontend shell — see carried-forward item from Phase 1) |
| `consent_given_at` | nullable timestamp | Assumption 4 — schema-ready, no flow yet |
| `created_at` / `updated_at` | timestamp | |

### `Document`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `fellow_profile` | FK | |
| `type` | enum: `aadhaar`, `marksheet`, `bank_statement`, `photo`, `other` | |
| `storage_key` | text | Object storage path — never exposed to the client directly |
| `original_filename` | text | |
| `content_type` | text | Server-verified, not trusted from the client |
| `size_bytes` | integer | |
| `checksum_sha256` | text | Integrity check, and cheap fraud-signal groundwork for Phase 3 |
| `verification_status` | nullable enum | Already anticipated in the master doc's schema — room for the optional govt. Aadhaar-verification add-on without a future migration |
| `superseded_at` | nullable timestamp | Assumption 2 — soft-replace, not hard overwrite |
| `uploaded_at` | timestamp | |

### `DocumentAccessLog`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `document` | FK | |
| `accessed_by` | FK → User | |
| `action` | enum: `view`, `download` | |
| `accessed_at` | timestamp | |

### `Volunteer`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `fellow_profile` | FK | |
| `full_name` | text | |
| `phone_number` | text | Normalized via a phone-number library before storage |
| `phone_number_raw` | text | As entered, kept for reference |
| `relationship_to_fellow` | text, optional | |
| `household_details` | text/JSON | |
| `created_at` / `updated_at` | timestamp | |

**Constraint:** unique on (`fellow_profile`, `phone_number` normalized) to block exact duplicates within one fellow's list. Cross-fellow duplicate phone numbers are **flagged for Admin review**, not blocked — the same person could legitimately appear under more than one fellow in edge cases.

**Migrations:** additive only this phase (new columns, new tables) — no destructive changes to Phase 1's `User`/`FellowProfile` shape.

**Backup:** documents live in object storage (provider handles durability/versioning per Decision 1); DB backup strategy is whatever's already standard for the Postgres instance — no new requirement introduced here beyond ensuring encrypted-field backups are still restorable with the same encryption key (see Infrastructure, key management).

---

## H. API / Interface Contracts

All endpoints require a valid access token; anonymous requests get `401`.

**Fellow-facing:**
| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/profile/me` | Own profile only |
| PATCH | `/api/v1/profile/me` | Partial update, field-level validation errors |
| POST | `/api/v1/documents` | Multipart upload; server validates type/size/MIME before storage write |
| GET | `/api/v1/documents` | Own documents only, excludes superseded ones by default |
| GET | `/api/v1/documents/{id}/download` | Ownership check → logs access → returns short-lived access, not a permanent URL |
| POST | `/api/v1/volunteers` | Validates + dedup-checks before create |
| GET | `/api/v1/volunteers` | Own volunteers only |
| PATCH/DELETE | `/api/v1/volunteers/{id}` | Own records only — `404` on someone else's ID |

**Admin-facing (read-only this phase):**
| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/admin/fellows` | Paginated, no block filter yet (Phase 4) |
| GET | `/api/v1/admin/fellows/{id}` | Full profile detail |
| GET | `/api/v1/admin/fellows/{id}/documents` | List; download still goes through the same `/documents/{id}/download` endpoint with an Admin-scoped permission check |
| GET | `/api/v1/admin/fellows/{id}/volunteers` | Read-only list |

**Error handling conventions:**
- `400` — validation errors, field-level messages via serializer errors
- `401` — no/invalid token
- `403` — authenticated but wrong role for this endpoint category (e.g., Fellow hitting `/admin/*`)
- `404` — authenticated, correct role, but the specific record isn't theirs (Mandate #5 — never `403` here, to avoid confirming existence)

**Idempotency:** re-uploading the same document type is a valid, expected action (Assumption 2) — not an idempotency violation. Volunteer creation is not idempotent by request design; duplicate-phone detection (§G) is the intended safety net instead of a client-supplied idempotency key.

---

## I. Infrastructure

- New env vars: `STORAGE_BACKEND` (`s3` | `local`), `STORAGE_BUCKET_NAME`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_ENDPOINT_URL`, `STORAGE_REGION`, `FIELD_ENCRYPTION_KEY`, `MAX_UPLOAD_SIZE_MB`.
- **Local dev fallback, mirroring the Phase 1 SQLite pattern:** `STORAGE_BACKEND=local` switches to Django's `FileSystemStorage` so developers without Docker/MinIO can still work end-to-end, exactly like the SQLite-vs-Postgres fallback already established. `STORAGE_BACKEND=s3` (against MinIO locally, R2 in staging/prod) is what CI and any "real" verification pass must use — same two-track pattern as Phase 1, and CI should enforce the `s3` path the same way it already enforces Postgres.
- **Local dev with MinIO:** add a `minio` service to `docker-compose.yml` for developers who do have Docker working, so local dev can exercise the real S3-compatible path without R2 credentials.
- **Secrets:** storage credentials and `FIELD_ENCRYPTION_KEY` are environment/secrets-store only, never committed. Explicitly document a backup/escrow procedure for `FIELD_ENCRYPTION_KEY` — losing it means the Aadhaar/bank columns become permanently unreadable, which is effectively a data-loss event.
- **CI:** unit/integration tests run against Django's in-memory/local storage override (fast, hermetic, no network dependency); a separate, less-frequent job can smoke-test against real MinIO or a staging R2 bucket if the team wants that extra confidence.

---

## J. Security

- RBAC: every endpoint in §H that distinguishes Fellow vs. Admin ships with the 403/404 test pair from Mandate #4 — this is the item explicitly deferred from Phase 1.
- Access logging: every document view/download writes a `DocumentAccessLog` row, including Admin access — no carve-out.
- Encryption: object storage server-side encryption (Decision 1) + application-level field encryption for Aadhaar/bank columns (Decision 2).
- Upload validation: server-side MIME sniffing (not trusting the client's `Content-Type`), an explicit file-type allow-list (images + PDF for now), and a size cap via `MAX_UPLOAD_SIZE_MB`.
- Least privilege: the storage credentials used by the backend are scoped to only this app's bucket/prefix — not account-wide keys.
- No bulk export of Aadhaar/bank fields from any endpoint in this phase (exports are Phase 4 scope anyway, but worth stating now since it constrains how document/profile serializers are written).

---

## K. Reliability

Failure modes to design around, not just the happy path:

- **Storage write fails mid-upload:** the `Document` DB row is only created after the storage write is confirmed successful — no orphaned metadata pointing at a file that doesn't exist. Return a clear, retryable error to the client.
- **Encryption key misconfigured/rotated without a migration plan:** treat as a deploy-blocking check, not a runtime surprise — validate `FIELD_ENCRYPTION_KEY` is present and matches at startup.
- **Duplicate volunteer submissions from flaky connectivity:** the unique constraint (§G) makes a retried identical submission a safe no-op/clear conflict response, not a silent duplicate.
- **Admin viewing a fellow's document that was superseded mid-session:** always resolve to the current, non-superseded document unless a specific historical version is explicitly requested (not exposed in v1 — history is retained for audit, not yet surfaced in the UI).

---

## L. Testing

- **Unit:** field encryption round-trips correctly (write encrypted, read back plaintext); phone-number normalization; duplicate-detection logic.
- **Integration:** full upload → list → download flow, including the access-log side effect; full profile update flow; full volunteer CRUD flow.
- **Security/RBAC (the paid-off debt):** Fellow → Admin-only endpoint → `403`; Fellow → another fellow's document/profile/volunteer by ID → `404`; anonymous → any endpoint → `401`.
- **Contract:** verify no serializer anywhere in this phase accidentally includes raw storage keys/URLs or unencrypted Aadhaar/bank values in a response body — a explicit test asserting these fields never appear in any list/detail response.
- **Regression:** re-run the Phase 1 cookie/RBAC tests to confirm nothing here breaks the existing auth contract.

---

## M. Observability

- Structured logs on upload attempts (success/failure, type, size) and on every document access.
- Metric: document count by type/status, upload failure rate, average upload latency.
- Alert: spike in upload failures (likely signals a storage-provider issue) or in `403`/`404` rates on the new endpoints (could signal either a client bug or a probing attempt).

---

## N. Developer Experience

- New apps: `apps/profiles`, `apps/documents`, `apps/volunteers` (or extend `apps/accounts` if the team prefers fewer, larger apps — either is fine, just be consistent with the existing Phase 1 structure).
- README addition: document both storage paths (`local` for no-Docker dev, `s3`/MinIO for the real path), matching how the Postgres/SQLite split is already documented.
- Local dev should not silently regress to a broken state if `FIELD_ENCRYPTION_KEY` is unset — fail fast with a clear message pointing at `.env.example`.

---

## O. Definition of Done — Phase 2

- [ ] Fellow can complete profile, upload all document types, and map volunteers end-to-end
- [ ] Admin can browse the fellow list and view (read-only) any fellow's full profile, documents, and volunteers
- [ ] Every Fellow/Admin-distinguishing endpoint has an automated 403/404 test — Phase 1's deferred RBAC debt is closed
- [ ] Aadhaar/bank structured fields are encrypted at the application layer, verified by a round-trip test
- [ ] Every document view/download produces a `DocumentAccessLog` row
- [ ] No endpoint response includes a raw storage URL/key or a decrypted Aadhaar/bank value outside the single authorized detail view
- [ ] Local dev works both with and without Docker (the `local`/`s3` storage split), documented in the README
- [ ] `FIELD_ENCRYPTION_KEY` backup/escrow procedure documented
- [ ] Onboarding shell wired to the real `onboarding_step` field (carried forward from Phase 1)

---

## P. Execution Log

See [phase-2-mandate-execution-log.md](phase-2-mandate-execution-log.md) for what was actually
built against this mandate, scoped to the "backend data model + local storage first" first pass
(Flutter UI and real S3/MinIO deferred to a follow-up).
