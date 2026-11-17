# Phase 5 notification contract

Frozen 2026-09-21. All paths below are under `/api/v1` and authenticated.

- `POST /admin/notifications`: Admin only. Body: `type` (`training`, `event`, `deadline`), required `title_en`, `title_hi`, `body_en`, `body_hi`, `scheduled_time` (ISO-8601), `remind_before` (nonnegative duration, e.g. `1 00:00:00`), `channel` (`in_app` only), exactly one of `target_user` (active user UUID) or `target_block` (active canonical block UUID). Returns definition, 201.
- `GET /admin/notifications`: Admin-only paginated definitions, newest first.
- `GET /admin/notifications/targets`: Admin-only paginated active users (`id`, `email`) for the person selector; never fetches sensitive profiles.
- `GET /notifications/mine`: paginated delivered reminders, with own `read_at` and `dismissed_at`; dismissals remain in history. Optional `month=YYYY-MM` filters scheduled date using UTC month boundaries. Each result has `id` (notification UUID), bilingual content, type/channel/scheduled_time and recipient state. No recipient list or targeting metadata.
- `POST /notifications/{id}/read`, `POST /notifications/{id}/dismiss`: idempotent recipient-only transitions; 404 for another user's/undelivered definition. Dismiss also marks read. Response is recipient item.

The calendar is an accessible date-ordered agenda grouped by day, with month navigation. API and UI use local display times; month filtering uses explicit UTC boundaries (UI fetches all delivered pages then groups locally). Bilingual content is required rather than machine-translated.

Run `python manage.py deliver_notifications` every minute with cron/systemd. Due means `scheduled_time - remind_before <= now`. The command locks each definition and atomically creates all eligible active recipients plus `delivered_at`. A unique `(notification,user)` constraint and transaction make retries/concurrent PostgreSQL workers safe. Block membership is snapshotted at delivery, not creation; later block moves do not grant or revoke already delivered messages. A delivery with zero recipients is final. Failed transactions leave no partial delivery and retry next run. No push/SMS, queue, or background process is shipped. The command must be scheduled by the deployment operator; GET requests never deliver messages.

401 unauthenticated, 403 authenticated non-admin on admin routes, 404 inaccessible recipient object, 400 invalid input. No edit/delete API: sent definitions cannot silently change. `delivered_at` is operational state on the definition; per-user read/dismiss state is independent.
