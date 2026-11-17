# Phase 2 Mandate — Pass 3 (Revised): CVE Triage, Block Assignment & Storage Unblock

**Date:** 2026-09-16
**Status:** Active — supersedes the prior Pass 3 mandate's Must-have #1 (UI QA), now closed
**Depends on:** Pass 2 (Flutter UI + MultiFernet rotation), manual QA pass (now complete)
**Audience:** Engineering team

---

## 1. Status Update

Manual click-through QA of the Pass 2 screens is done — closing the item flagged as the single biggest gap in that pass's execution log. (This mandate assumes the QA pass found no blocking issues; if it surfaced specific bugs, fold those in as their own tracked items rather than losing them in this document.)

With that closed, the most consequential remaining item is the CVE triage — so this revision does the actual triage, not just a process outline, since a real answer is far more useful to the team than a checklist for finding one.

---

## 2. CVE Triage — In Depth

### Django (pinned 5.1.4)

**The real issue isn't the patch level — it's that the whole branch is dead.** Django 5.1 was a standard (non-LTS) release with a 16-month support window and reached end-of-life on December 3, 2025. As of today, it has been unsupported for over nine months: no new vulnerability discovered in Django since that date will ever be patched on the 5.1 branch, no matter how current the patch version is within it.

That said, even within 5.1's now-closed lifetime, the pinned 5.1.4 misses real fixes that did ship before EOL — including at least one high-severity SQL injection issue (via `annotate()`/`alias()`/`aggregate()`/`extra()` keyword-argument handling on MySQL/MariaDB — worth confirming this project's Postgres backend isn't affected, but don't assume it isn't without checking) and further SQL-injection-class fixes to `Q`/`QuerySet` and `FilteredRelation` handling in later 5.1.x point releases, which are not backend-specific and likely do apply here.

**Recommendation, two-step:**
1. **This week, zero compatibility risk:** bump to the last released 5.1.x version (5.1.15) as an immediate stopgap. This captures every fix that shipped before the branch died, without any of the risk of a minor-version jump.
2. **Its own scheduled pass, not bundled into feature work:** migrate to Django 5.2 LTS (supported until April 2028). The 5.1→5.2 path is generally regarded as low-risk with no major breaking changes, but "generally low-risk" still means a dedicated pass with real regression testing against this app's actual test suite — not a rider on an unrelated PR.

### djangorestframework-simplejwt (pinned 5.3.1)

**Concrete and directly relevant to this app.** Versions up to and including 5.3.1 have a confirmed vulnerability: token issuance via the `for_user` method doesn't verify the target account is still active, so a disabled or deactivated user's tokens can still grant access. Fixed in 5.5.1.

This matters specifically here: the account-activation policy is still an open product question, and however it resolves, deactivating an account (a rejected sign-up, an offboarded fellow, anything requiring revocation) needs to actually work. Given the real engineering investment already made in this auth layer — the RBAC test suite, the httpOnly refresh cookie migration, `MultiFernet` rotation — this is exactly the kind of gap that shouldn't be allowed to sit underneath all of that other work.

**Recommendation:** bump to >=5.5.1 now. This is a small, self-contained dependency with no framework-wide migration risk — there's no reason to wait for the Django work to do this one.

### djangorestframework (pinned 3.15.2)

**Not the source of the finding.** The pinned version, 3.15.2, is precisely the release that fixed the one known CVE affecting earlier versions (a cross-site scripting issue in the `break_long_headers` template filter). No known vulnerability exists at 3.15.2 itself. Whatever the audit attributed to DRF almost certainly reflects its dependency on the vulnerable Django version above, not a DRF-specific flaw.

**Recommendation:** no urgent standalone action. When the Django 5.2 migration happens, check DRF's compatibility matrix for that Django version and bump alongside it only if actually required — don't bump it speculatively in isolation first.

### Summary — what actually ships when

| Action | Timing | Risk |
|---|---|---|
| Bump `djangorestframework-simplejwt` to ≥5.5.1 | This week | Low — self-contained |
| Bump Django to 5.1.15 | This week | Zero — last patch of the same branch |
| Migrate Django to 5.2 LTS | Own scheduled pass | Medium — needs real regression testing |
| Bump DRF if the 5.2 migration requires it | Alongside the Django 5.2 pass | Low, contingent |

Re-run `pip-audit` after each step to confirm the count actually drops — don't assume it does just because the plan looks right on paper.

---

## 3. Block Assignment — A Recommendation, Not Just an Open Question

The question (fellow-picks-at-onboarding vs. admin-assigns-after) still needs an NGO answer, but the team shouldn't sit fully blocked on it. **Recommendation if a default is needed before that answer arrives:** let the fellow pick their block during onboarding, with a `GET /api/v1/blocks` endpoint to list the 7 blocks. Rationale: this doesn't block onboarding completion on an Admin's availability, matches the pattern of everything else in Phase 2 being fellow-initiated (profile, documents, volunteers), and is trivially reversible — an Admin-side "reassign block" action can be added later without touching the onboarding flow itself, whereas building admin-assignment-only now and adding self-service later is the more awkward direction to retrofit.

This is a default to build against, not a decision to make unilaterally — get the NGO's actual answer, but don't let its absence stall the profile form indefinitely.

---

## 4. Storage Unblock (Should-have, unchanged from prior mandate)

Still worth pursuing in parallel with the Docker install already in progress: a free-tier Cloudflare R2 bucket + API token needs no local Docker and unblocks the real `s3` backend independently of how that install goes. Docker has now blocked progress three separate times — this doesn't require abandoning the Docker path, just not being solely dependent on it a fourth time.

## 5. Consolidate Open Questions (Should-have, unchanged)

Account activation policy, data-consent policy, WhatsApp scope, role hierarchy, `FIELD_ENCRYPTION_KEY` custody, and block assignment are all currently sitting in different mandate files. Worth a single tracked document referenced from each phase's mandate, rather than re-discovering them by re-reading old files — a real risk for a small, rotating student team.

---

## 6. Updated Definition of Done — Phase 2

- [x] Data model, migrations, field encryption, all API endpoints (Pass 1)
- [x] RBAC 403/404 test debt closed
- [x] Sensitive fields verified absent from list serializers
- [x] `MultiFernet` key rotation in place
- [x] Flutter UI built for profile, documents, volunteers, and Admin browsing (Pass 2)
- [x] Onboarding shell wired to real `onboarding_step`
- [x] **UI manually click-tested by a human**
- [ ] `djangorestframework-simplejwt` bumped to ≥5.5.1
- [ ] Django bumped to 5.1.15 (stopgap)
- [ ] Django 5.2 LTS migration scheduled as its own pass
- [ ] Block assignment mechanism decided and built
- [ ] Real `s3` storage backend built and verified
- [ ] `docker-compose.yml` MinIO service added
- [ ] CI smoke-tests the real `s3` backend
- [ ] `FIELD_ENCRYPTION_KEY` backup/escrow procedure documented and owned (NGO/professor decision)

---

## 7. Execution Log

See [phase-2-mandate-pass3-execution-log.md](phase-2-mandate-pass3-execution-log.md).
