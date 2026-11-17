# Saath workspace refresh — 29 October 2026

The prototype now uses a cohesive visual identity: forest green, warm paper surfaces, lime and clay accents, locally bundled DM Sans typography and a custom growth illustration. Saath is the working product name used for this preview.

Desktop uses a persistent workspace sidebar. Below 1040px it switches to bottom navigation with additional actions in the menu. Staff get a work overview, a searchable fellow directory, a review queue and an impact dashboard. Fellows get a personal overview, work stages, their documents, volunteers and profile. Metrics come from existing APIs; no synthetic percentage increases or invented activity charts are displayed.

The review-queue action opens jobs filtered to submitted work. Job cards distinguish to-do work, work in progress, review, completion and changes needed. Documents have a larger file-selection area, selected-image preview and scrolling upload flow. Existing role checks, uploads, review history, exports, read/dismiss actions and bilingual content remain available.

Staff send announcements for team news and events. Assignment/deadline reminders are automatic through `deliver_notifications`: assignment, one day before due, due today, then once overdue. Duplicates are prevented by a unique automation key; submitted/approved jobs stop further reminders; stale pending reminders are cancelled when an assignee or deadline changes. NGO date boundaries default to Asia/Kolkata. See [notification operations](notification-operations.md).

Verification: 135 backend tests pass with two environment-dependent skips. Backend lint and Flutter analysis pass; release web compilation succeeds. Browser checks cover desktop and phone layouts. The local Flutter native widget-test runner currently fails in the Objective-C dependency hook because it cannot resolve the macOS SDK; those tests were not claimed as passing in this refresh.

Browser verification included 1366px desktop, 390px phone and 320px narrow phone layouts; staff review-queue filtering; fellow search; impact reports; fellow work-stage filters; and choosing, previewing and successfully uploading a sample image document. Workspace navigation is isolated from nested route semantics so sidebar, header and bottom navigation remain accessible. Secondary text has 4.82:1 contrast against the page background. Job changes invalidate the overview data so counts update after assignments, submissions and reviews.

The isolated local demo contains fictional fellows and assignments to make the flows demonstrable. It still uses the accounts documented in [demo walkthrough](demo-walkthrough.md). Its app/API and notification worker run as detached background processes at port 15173. Production hosting and real email delivery are separate from this preview.

When rebuilding the local preview, regenerate compressed files before restarting the server. If an old compressed file was served with a new validator during a build, refresh generated asset timestamps, recompress and reload the server before the browser. The production Docker build already compresses its fresh web directory.
