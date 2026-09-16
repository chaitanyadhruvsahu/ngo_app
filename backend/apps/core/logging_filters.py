import logging
import re

from apps.core.request_context import get_request_id

# Matches key="value" / key='value' / key=value for common sensitive keys,
# case-insensitive, so a stray `log.info(f"login failed for {password=}")`
# never lands a raw secret in the log stream.
_SENSITIVE_KEY_PATTERN = re.compile(
    r'(?i)\b(password|token|refresh_token|access_token|secret)\b\s*[=:]\s*'
    r'("([^"]*)"|\'([^\']*)\'|(\S+))'
)


def scrub(message: str) -> str:
    return _SENSITIVE_KEY_PATTERN.sub(lambda m: f"{m.group(1)}=***", message)


class ScrubSensitiveDataFilter(logging.Filter):
    """Attaches the current request ID to every log record and redacts
    common sensitive field names from the rendered message, as a defense
    in depth measure alongside never logging raw passwords/tokens in the
    first place.
    """

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = getattr(record, "request_id", None) or get_request_id()
        try:
            rendered = record.getMessage()
        except Exception:
            return True
        scrubbed = scrub(rendered)
        if scrubbed != rendered:
            record.msg = scrubbed
            record.args = ()
        return True
