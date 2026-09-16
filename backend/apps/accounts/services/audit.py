"""Audit trail for auth events — signup, verify, login success/fail, reset
request/confirm, logout. Every call logs a user id (or None) and timestamp
via the standard JSON log formatter; never pass a password or raw token
into `extra`.
"""
import logging

logger = logging.getLogger("apps.accounts.audit")


def log_auth_event(event: str, *, user_id: str | None = None, **extra) -> None:
    logger.info(event, extra={"user_id": user_id, **extra})
