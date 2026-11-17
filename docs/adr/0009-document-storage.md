# ADR-0009: Document storage — backend-proxied, local-first this phase

**Status:** Accepted; amended by Phase 3 Workstream D below (historical rationale retained)
**Date:** 2026-09-16

## Amendment — 2026-09-21

`STORAGE_BACKEND=s3` now uses a boto3 adapter in the same storage seam as local
documents and job photos. It provides private writes, authenticated streaming
reads, SHA-256 checksums, conditional creation, and rollback deletion; provider
failures are normalised to `OSError`. No client receives an object URL. MinIO
source-build compose services and a real S3 CI smoke test are included. See
[storage operations](../storage-operations.md) for provisioning and cutover.
Production R2 credentials and deployment remain pending. The original text below
describes the Phase 2 decision at the time, not current implementation status.

## Context

Phase 2 needs dedicated storage for uploaded documents (Aadhaar, marksheet, bank statement,
photo), accessed only through the backend — never a client-visible public URL (Phase 2 mandate,
Mandate #1). The mandate's own Decision 1 recommends Cloudflare R2 (S3-compatible, no egress
fees) for the real deployment, with a local `STORAGE_BACKEND=local` fallback for developers
without Docker — mirroring the SQLite-vs-Postgres split already established in Phase 1
(see `docs/local-dev-session-notes.md`).

This pass had no object storage credentials (R2 or otherwise) and no working Docker install on
the dev machine used to build this phase (see the Phase 1 execution log for why Docker couldn't
be installed there), so only the `local` path could actually be built *and verified* here.

## Decision

`STORAGE_BACKEND` env var selects the backend. `local` (the only one implemented) uses Django's
`FileSystemStorage`, rooted at `DOCUMENT_STORAGE_ROOT` (defaults to `backend/document_storage/`,
gitignored) — outside `MEDIA_ROOT`/`STATIC_ROOT`, so nothing here is ever served by Django's
static/media URL machinery. `STORAGE_BACKEND=s3` raises `ImproperlyConfigured` at startup with a
message pointing at this gap, rather than silently misbehaving if someone sets it before the R2
path exists.

Every document read/write is brokered through the backend regardless of which storage backend is
active (Phase 2 mandate's non-negotiable architectural rule): uploads go through
`DocumentListCreateView.post` (validated, then written), downloads through
`DocumentDownloadView.get` (ownership/role check, then streamed back via Django's `FileResponse`,
logged to `DocumentAccessLog` on every access — Mandate #2, no exceptions including Admin). No
storage key or path is ever included in an API response (`DocumentSerializer` excludes
`storage_key` entirely).

Even without S3 presigning, this satisfies Mandate #1 ("no client ever receives a raw, permanent
storage URL") — the *mechanism* differs (backend streams bytes vs. issuing a short-lived
presigned URL) but the guarantee (no client-visible permanent URL, access gated server-side) is
the same either way.

## Alternatives considered

- **Build the `s3` backend against MinIO now, without real R2 credentials:** considered, but
  Docker wasn't available in this environment to run MinIO (see Context), and building an S3
  backend that's never actually been run against a real S3-compatible endpoint here would be
  unverified code presented as done. Deferred rather than faked.
- **Local disk as the *permanent* answer, not just a dev fallback:** rejected outright, per the
  mandate — ties storage lifecycle to server lifecycle, no real backup/DR story, doesn't meet
  "dedicated object storage."
- **Presigned direct-to-bucket uploads:** the mandate's own Decision 3 already rejects this for
  v1 in favor of backend-proxied uploads — not revisited here.

## Consequences / trade-offs

- **This ADR is explicitly partial.** The mandate's Decision 1 (R2 over S3, no egress fees) and
  the MinIO local-dev-with-Docker path are recorded here as the intended direction, but neither
  is implemented or verified — only `local`/`FileSystemStorage` is. Whoever picks this up next
  needs real R2 (or chosen provider) credentials and either a working Docker install or another
  way to run MinIO locally to build and verify the `s3` backend — see
  [phase-2-mandate-execution-log.md](../phase-2-mandate-execution-log.md).
- Until `s3` exists, there's no real backup/DR story for uploaded files beyond whatever backs up
  the server's filesystem — acceptable for continued local development, not for any real
  deployment with actual fellow documents.
- `DOCUMENT_STORAGE_ROOT` and the `local` backend work identically under SQLite or Postgres —
  storage backend and database backend are independent axes, deliberately, so either can be
  swapped without the other caring.

## Reversibility

High for the backend swap itself — `apps.documents.services.storage` is the single seam every
view goes through; adding an `s3` implementation there and switching `STORAGE_BACKEND` doesn't
touch views/serializers/models. Not reversible without pain: any files already written under
`local` would need an explicit migration step (copy into the bucket, update... actually
`storage_key` format would need to stay path-like and compatible, or a one-time backfill script)
before cutting over — not a concern yet since no real fellow data exists under `local` today.
