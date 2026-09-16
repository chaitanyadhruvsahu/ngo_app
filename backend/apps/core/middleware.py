import uuid

from apps.core.request_context import request_id_ctx_var


class RequestIDMiddleware:
    """Assigns a request ID to every request, exposes it as X-Request-ID on
    the response, and makes it available to the JSON log formatter via a
    contextvar so every log line for this request can be correlated.
    """

    header_name = "X-Request-ID"

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        incoming = request.headers.get(self.header_name)
        request_id = incoming or uuid.uuid4().hex
        request.request_id = request_id
        token = request_id_ctx_var.set(request_id)
        try:
            response = self.get_response(request)
        finally:
            request_id_ctx_var.reset(token)
        response[self.header_name] = request_id
        return response
