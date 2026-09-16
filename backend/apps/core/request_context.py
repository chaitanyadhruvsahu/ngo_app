"""Per-request context (currently just the request ID) shared between the
request middleware and the logging filter, without threading it through
every function signature.
"""
import contextvars

request_id_ctx_var: contextvars.ContextVar[str] = contextvars.ContextVar(
    "request_id", default="-"
)


def get_request_id() -> str:
    return request_id_ctx_var.get()
