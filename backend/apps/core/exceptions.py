"""Shared error envelope for every API response.

Every error response from this API takes the shape:

    {"error": {"code": "<machine_readable_code>", "message": "<human_readable_message>"}}

established in Phase 0 so no later phase has to retrofit a different shape.
"""
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


def _flatten_message(data) -> str:
    """DRF's default error bodies are dicts of field -> [messages] or plain
    lists/strings depending on the exception. Collapse any of those shapes
    into one human-readable string for the envelope.
    """
    if isinstance(data, str):
        return data
    if isinstance(data, list):
        return "; ".join(_flatten_message(item) for item in data)
    if isinstance(data, dict):
        parts = []
        for key, value in data.items():
            flattened = _flatten_message(value)
            parts.append(flattened if key == "non_field_errors" else f"{key}: {flattened}")
        return "; ".join(parts)
    return str(data)


def envelope_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    code = getattr(exc, "default_code", None) or exc.__class__.__name__
    message = _flatten_message(response.data)
    response.data = {"error": {"code": code, "message": message}}
    return response


def error_response(code: str, message: str, status_code: int) -> Response:
    """Build an envelope error response directly, for views that need to
    return a deliberately generic error (e.g. auth failures) rather than
    raising a DRF exception.
    """
    return Response({"error": {"code": code, "message": message}}, status=status_code)
