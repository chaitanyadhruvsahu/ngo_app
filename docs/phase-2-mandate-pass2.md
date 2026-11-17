# Phase 2 Mandate — Pass 2: Storage, Flutter UI & Close-Out

**Date:** 2026-09-16
**Status:** Active
**Depends on:** Pass 1 (backend data model + local storage) — closed, see its execution log
**Audience:** Engineering team

---

## 1. Review of Pass 1

Strong execution: all Phase 2 endpoints shipped, the RBAC test debt from Phase 1 was genuinely paid off (not deferred again), and two things stand out as better than the mandate strictly asked for —

- **Sensitive fields kept out of list responses via a separate, narrower serializer class**, not permission-based filtering on a shared one. That's a materially more robust pattern than most teams reach for.
- **The encryption round-trip test checked the raw column on disk**, not just that the ORM claims to decrypt correctly — that's testing the actual guarantee, not the abstraction's promise.

One correction to the record: the original mandate's Data Architecture table listed `block` as "Already exists" on `FellowProfile`. It didn't — Phase 1 never shipped a `Block` model. The team caught this and built a correctly minimal one rather than pulling Phase 4's block-management scope forward. Noted here so it doesn't get treated as a discrepancy later; it was my error, correctly handled.

The Postgres-specific transaction-poisoning bug (an uncaught `IntegrityError` breaking every subsequent query in the same transaction) is worth generalizing, not treating as a one-off fix — see Must-have #1.

---

## 2. Must-have

1. **Audit the codebase for the same transaction-poisoning pattern.** The fix — wrapping `save()` in `transaction.atomic()` so an `IntegrityError` doesn't poison the surrounding transaction — was applied where it was caught. Search for every other `try/except IntegrityError` (or similar mid-transaction exception handling) and confirm each is scoped to its own savepoint. This class of bug is easy to reintroduce anywhere else duplicate-detection or unique-constraint handling exists.
2. **Build and verify the real `s3` storage backend** against MinIO or a Cloudflare R2 test bucket. `local` was always the no-Docker fallback, not the destination — this is the actual target architecture from the original mandate, still unbuilt.
3. **Resolve Docker, one way or another.** It has now blocked progress twice — Phase 1's Postgres verification, and now MinIO here. Either get a proper interactive install done on a machine that can do it, or make an explicit decision to depend on direct R2 credentials for local dev going forward instead of Docker.
4. **Build the Flutter UI for everything this pass's backend already supports:** profile form, document upload screen, volunteer list/CRUD, and Admin fellow browsing (list, detail, documents, volunteers — all read-only for Admin). The backend is now a full phase ahead of the UI — close that gap before anything else starts.
5. **Wire the onboarding shell to the real `onboarding_step` field** (carried forward from Phase 1) — small, and belongs naturally alongside this pass's other Flutter work.

## 3. Should-have

6. **Switch to `MultiFernet` instead of a single `Fernet` key** in `EncryptedCharField`, before more real Aadhaar/bank data accumulates. `MultiFernet` supports multiple keys, so a future key rotation can re-encrypt data with the newest key without a big-bang migration or downtime. Cheap now, painful once real records exist under a single key.
7. **Write the `FIELD_ENCRYPTION_KEY` backup/escrow procedure**, flagged as a real gap in ADR-0008. This needs an answer from the NGO/professor on who holds this long-term — the same open question as "who owns the codebase/hosting after the student team's involvement ends." Escalate it as a decision, not an engineering task.
8. **Add the `docker-compose.yml` MinIO service**, once Docker itself is resolved (#3) — currently blocked on the same root cause.
9. **Add a CI job against the real `s3` backend** (MinIO or a staging R2 bucket), once #2 exists. Current CI only proves the `local` fallback works, not the actual target path.

## 4. Could-have

10. **Presigned, short-lived GET URLs for downloads**, once the `s3` backend lands, instead of streaming every byte through the Django app server. This doesn't reopen Mandate #1 from the original spec ("no raw, permanent storage URL") — a presigned URL with a short expiry is neither raw nor permanent — and it's a purely additive reduction in backend bandwidth.
11. **Bump `psycopg[binary]` past 3.2.3** so `pip-audit` runs cleanly under Python 3.14 locally, not just under CI's 3.12. Not urgent since CI is unaffected, but worth closing so local security scanning isn't silently broken for whoever's on this machine next.

## 5. Do Not Build Yet

- **Phase 3 (job management).** Phase 2 isn't functionally complete until fellows can actually onboard through a real UI against real storage. Starting Phase 3 now would split a small team's attention across two unfinished fronts — finish Must-haves #2 and #4 first.
- **Observability/metrics/alerting.** Correctly deferred in Pass 1 — there's no hosting/infra target to wire alerts to yet. Revisit once a production hosting decision is made, likely alongside Phase 1's still-open production-readiness items (cookie `Secure` flag, `DEBUG=False`).

---

## 6. Updated Definition of Done — Phase 2

- [x] Data model, migrations, field encryption, and all API endpoints (Pass 1)
- [x] RBAC 403/404 test debt from Phase 1 closed
- [x] Sensitive fields verified absent from list serializers, not just permission-filtered
- [ ] Real `s3` storage backend built and verified (not `local`)
- [ ] Docker resolved, or an explicit decision made to stop depending on it for local dev
- [ ] Flutter UI shipped for profile, documents, volunteers, and Admin browsing
- [ ] Onboarding shell wired to real `onboarding_step`
- [ ] `MultiFernet` key-rotation support in place
- [ ] `FIELD_ENCRYPTION_KEY` backup/escrow procedure documented and owned
- [ ] `docker-compose.yml` MinIO service added
- [ ] CI smoke-tests the real `s3` backend, not just `local`

---

## 7. Execution Log

See [phase-2-mandate-pass2-execution-log.md](phase-2-mandate-pass2-execution-log.md).
