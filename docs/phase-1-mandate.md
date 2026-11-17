# Phase 1 Engineering Mandate — Auth & Onboarding
## NGO Fellow & Volunteer Management App

**Date:** 2026-09-16
**Status:** Active — supersedes the informal local-dev session notes from the same date
**Issued by:** Head of Engineering
**Audience:** Engineering team, current Phase (Phase 1: Authentication & Onboarding)

---

## 1. Summary of Current State

Local dev testing confirmed the core auth flow works end-to-end: signup, email verification, login, role-based routing, and logout are all functional on Flutter web + Django. One real bug was found and fixed in the process. However, Phase 1 is **not yet done** — three gaps below are gates, not polish, and must close before this phase is signed off.

| Requirement | Status |
|---|---|
| Signup + email verification | ✅ Works, but only against console email backend |
| Login + role-based routing | ✅ Works client-side; server-side RBAC not yet tested |
| Logout | ✅ Fixed — degrades gracefully on storage failure |
| Password reset | ⚠️ Wired up, not manually tested |
| Postgres parity | ❌ Not verified — local testing ran on SQLite |
| Real email delivery | ❌ Console backend only, no SMTP/provider configured |
| Account activation policy (auto vs. admin-approved) | ❓ Open product question — blocks final sign-off |
| Onboarding / Admin shells | ✅ Placeholders present, matches Phase 1 scope (real forms are Phase 2) |

---

## 2. Review Notes

- **The `flutter_secure_storage_web` fix is a real, valid bug fix, not a workaround.** A key/blob desync in browser storage could throw an unhandled decrypt error and permanently wedge the app on the splash screen. Wrapping token reads/clears in `try`/`catch` and degrading to "logged out" on any failure is the correct general-purpose fix — keep it, and turn it into a permanent decision record (see §4, should-have #8) rather than leaving it in a file marked for deletion.
- **Running against SQLite instead of Postgres locally is a reasonable short-term call**, but it means nothing about migrations, constraints, or Postgres-specific behavior has actually been verified. This cannot become "it works on my machine" — see Must-have #1.
- **Token storage on web deserves its own decision**, not just a bug-fix footnote (below).

---

## 3. Decision: Web Token Storage Strategy

**Decision:** How the web build stores auth tokens.

**Context:** `flutter_secure_storage_web` keeps both the AES-GCM encryption key *and* the encrypted token blobs in `localStorage`. On web this is not equivalent to native secure storage — anything that can execute JS in the page (XSS) can read both the key and the blob. Effectively, it's not much stronger than plain `localStorage`.

**Why it matters here:** these tokens will eventually gate access to Aadhaar and bank documents (Phase 2). The master requirements doc treats "no sensitive data exposed by default" as non-negotiable — a token storage scheme that's trivially readable via XSS undercuts that posture.

**Recommendation:** For the web target, move the refresh token to an `httpOnly`, `Secure`, `SameSite=Strict` cookie, with the access token held in memory only (not persisted). Native (Android) can continue using real OS-level secure storage.

**Trade-off:** Slightly more backend work — cookie-based session endpoints and CSRF handling for state-changing requests — versus the current simpler bearer-token setup.

**Reversibility:** Cheap now, while only the auth module touches this. Expensive later, once every authenticated screen depends on the current scheme.

**Trigger for reconsideration:** None needed — implement before Phase 2 begins touching documents, not after.

---

## 4. Mandate — Prioritized Work Items

### Must-have (blocks Phase 1 close-out)

1. Verify the full auth flow against real Postgres via `docker-compose`, not SQLite. Add a Postgres service container to CI so this is never gated on any one developer's local Docker install again.
2. Manually test the password reset request + confirm flow end-to-end.
3. Write backend tests proving RBAC is enforced **server-side** (e.g., a Fellow token hitting an Admin-only endpoint returns 403). Client-side routing (`go_router` redirects) is UX only and proves nothing about actual access control.
4. Move web token storage to httpOnly cookies (§3) before Phase 2 wires up document access on top of this session layer.
5. Get an explicit answer from the NGO on manual account approval. If approval turns out to be required, the current auto-active-on-verify flow needs an Admin "pending accounts" queue before this goes near real users.

### Should-have

6. Configure real email delivery (SMTP / SES / SendGrid) — blocks any testing outside a developer watching the console log.
7. Fix `FRONTEND_BASE_URL` / CORS env handling: adopt a documented, gitignored `.env.local` pattern per developer so verification/reset links are correct out of the box.
8. Turn the `flutter_secure_storage_web` fix into a permanent decision record (ADR) rather than leaving it in a file marked "delete once superseded."

### Could-have

9. Confirm whether the onboarding shell's 4-step progress list persists real step-state, or is purely visual — clarify before Phase 2 builds real forms on top of it.
10. `brew uninstall python@3.12` on the affected dev machine — unused, no urgency.

### Do Not Build Yet

- Anything from Phase 2 (profile forms, document upload). The onboarding/admin shells existing is not a green light to start on them — close out the Must-haves above first, especially Postgres parity and server-side RBAC, while the cost of fixing gaps is still low.

---

## 5. Definition of Done — Phase 1 Close-Out

Phase 1 is complete only when all of the following hold:

- [ ] Full auth flow (signup, verify, login, reset, logout) passes against real Postgres, not SQLite
- [ ] Password reset manually verified end-to-end
- [ ] Server-side RBAC covered by automated tests (not just client-side redirect behavior)
- [ ] Web refresh tokens stored via httpOnly cookie, not client-readable storage
- [ ] Account activation policy confirmed with the NGO and reflected in the actual flow
- [ ] Real email delivery configured (any provider is acceptable for v1)
- [ ] `flutter_secure_storage_web` fix documented as a permanent decision record
- [ ] Local dev setup (Postgres via Docker or a documented alternative) reproducible by a new team member without hand-patched `.env` files

---

## 6. Execution Log

See [phase-1-mandate-execution-log.md](phase-1-mandate-execution-log.md) for what was actually done against this mandate, item by item, including anything that could not be completed and why.
