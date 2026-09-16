/// Mirrors the backend's shared error envelope:
/// `{"error": {"code": "...", "message": "..."}}`.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode});

  factory ApiException.fromEnvelope(Map<String, dynamic> body, {int? statusCode}) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(
        code: error['code']?.toString() ?? 'unknown_error',
        message: error['message']?.toString() ?? 'Something went wrong.',
        statusCode: statusCode,
      );
    }
    return ApiException(code: 'unknown_error', message: 'Something went wrong.', statusCode: statusCode);
  }

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code, $message)';
}
