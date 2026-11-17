# Open Product/Policy Questions

Single tracked list, per Phase 2 mandate pass 3 §5 — these were previously scattered across
individual phase mandate files, which risks a small, rotating student team re-discovering the
same question twice (or missing that it was ever asked). Each entry names where it originally
came from and its current status. When one gets answered, update its status here rather than
deleting the row — the "why" often matters again later (e.g. if the NGO's answer changes).

| Question | First raised | Status | Notes |
|---|---|---|---|
| **Account activation**: does email verification alone activate an account, or does an Admin need to manually approve? | Phase 1 mandate, Must-have #5 | **Open.** Current behavior: auto-active on email verification (`VerifyEmailView`, `apps/accounts/views.py`) — an explicit, documented placeholder (`User.status`/`User.Status` modeled as an extensible enum specifically so this doesn't need a migration once answered). | If the answer is "needs approval," real scope follows: a pending-accounts queue, a new `User.Status` value, an approval endpoint, a notification on approval. |
| **Data consent policy**: what consent is required before storing Aadhaar/bank/personal data, and when is it captured? | Phase 2 mandate, Assumption 4 | **Open.** Schema-ready: `FellowProfile.consent_given_at` is a nullable timestamp, so no migration is needed once answered — but no consent *flow* (checkbox, forced gate) exists yet, deliberately. | Do not build a consent flow speculatively — the shape of the flow depends on the actual answer (blocking gate vs. informational, per-document vs. once). |
| **Block assignment**: does a fellow pick their own block at onboarding, or does an Admin assign it? | Phase 2 mandate pass 3, §3 | **Partially resolved — a default was built, not a real answer.** `GET /api/v1/blocks` + a fellow-facing picker on the profile form now exist (Phase 2 pass 3), on the reasoning that self-service is reversible and matches the rest of Phase 2's fellow-initiated pattern. This is still not the NGO's actual answer. | If the real answer is admin-assigns-only, the fellow-side picker either needs to become read-only again or coexist with an admin override — worth deciding which before Phase 4's block-filtered Admin views are built on top of whichever shape wins. |
| **Role hierarchy**: is there a tier above Admin (e.g. a "Super Admin")? | `apps/accounts/models.py`, `User` docstring (Phase 1) | **Open.** `User.Role` is modeled as an extensible enum specifically so a new tier can be added as an enum value + permission branch, not a schema rewrite. | No code depends on an assumed two-tier (Admin/Fellow) hierarchy in a way that would need unwinding — safe to leave open. |
| **`FIELD_ENCRYPTION_KEY` custody**: who holds the long-term backup of the field-encryption key once the student team's involvement ends? | ADR-0008, Phase 2 pass 2 should-have #7 | **Open — an ops/ownership decision, not an engineering task.** Losing this key permanently locks the Aadhaar/bank columns (by design — see ADR-0008/0010). Key rotation exists (ADR-0010) but rotation isn't a substitute for an actual custody answer. | Needs an answer from whoever the NGO/professor designates as the long-term owner — the same underlying question as "who owns hosting/the codebase after this team hands off." |
| **WhatsApp scope**: referenced in Phase 2 mandate pass 3 §5 as one of the open items to consolidate here. | Phase 2 mandate pass 3, §5 | **Open — not yet scoped in this codebase.** No WhatsApp-related code exists anywhere in this repo as of Phase 2 pass 3; this entry exists so the question isn't lost, not because implementation has started. | Needs its actual scope defined (what a WhatsApp integration is even for here) before it's actionable — flag to whoever owns the master requirements doc for the actual ask. |
| **Multiple fellows per job**: should one job ever have more than one active assignee? | Phase 3 mandate | **Open. Current implementation deliberately supports one active fellow per job.** | Multi-assignee work changes ownership, evidence visibility, hours accounting, and review semantics; do not infer it from the current single-assignee workflow. |
| **Location evidence policy**: may the NGO collect precise job-submission location, and what retention/access policy applies? | Phase 3 mandate | **Open. Feature is disabled by default.** When enabled, each submission requires explicit fellow opt-in; capture failure is ignored and every coordinate read is audited. | Obtain privacy/legal sign-off before enabling `JOB_GEOTAG_ENABLED` in any shared environment. |
| **Evidence photo limit**: is five photos per submission sufficient for every field workflow? | Phase 3 mandate | **Open. Current cap is 5.** | The cap bounds upload time, memory, review effort, and storage. Change only with matching mobile UX and backend capacity review. |

## Phases 4–6 decisions awaiting the NGO

| Question | Current status | Engineering boundary |
|---|---|---|
| Additional named exports beyond fellow contacts and an event candidate roster? | Awaiting NGO usage and confirmation. | Two named XLSX exports only. The candidate roster does not claim registration or attendance; no event attendance model exists. |
| Stipend calculation formula? | Not supplied; calculation work held. | No payment amounts, rates, or calculation logic. Read-only approved-hours aggregates are available for later discussion. |
| Aadhaar verification budget? | Not confirmed; integration held. | Existing document verification status remains available. No provider integration. |
| Key custodian and recovery drill? | Directly escalated; user answered “nobody right now.” | Procedure exists, but appointment and actual recovery exercise remain open. |
| Which dashboard aggregates should be retained after real use of Phases 0–5? | Provisional scope from this mandate, awaiting NGO usage feedback. | Read-only block/fellow totals, no inferred stipend workflow. |

## Maintaining this list

- When a question gets answered, update its **Status** cell in place (don't delete the row) and note what changed.
- When a new open question surfaces in a mandate/ADR, add it here rather than only leaving it in that document — link back to where it originated.
- Each phase mandate should reference this file rather than re-listing its own open questions inline, to avoid the list drifting out of sync in two places.
