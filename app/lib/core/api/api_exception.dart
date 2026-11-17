import 'package:ngo_app/core/i18n/translator.dart';

/// Mirrors the backend's shared error envelope:
/// `{"error": {"code": "...", "message": "..."}}`.
class ApiException implements Exception {
  const ApiException(
      {required this.code, required this.message, this.statusCode});

  factory ApiException.fromEnvelope(Map<String, dynamic> body,
      {int? statusCode}) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(
        code: error['code']?.toString() ?? 'unknown_error',
        message: error['message']?.toString() ?? 'Something went wrong.',
        statusCode: statusCode,
      );
    }
    return ApiException(
        code: 'unknown_error',
        message: 'Something went wrong.',
        statusCode: statusCode);
  }

  final String code;
  final String message;
  final int? statusCode;

  /// Keep raw server detail for diagnosis; display stable translated guidance.
  String get userMessage {
    const translatedCodes = {
      'network_error',
      'invalid_credentials',
      'invalid_token',
      'duplicate_volunteer',
      'unsupported_file_type',
      'file_too_large',
      'upload_failed',
      'download_failed',
      'storage_unavailable',
      'invalid_transition',
      'throttled',
      'permission_denied',
      'not_found',
    };
    if (translatedCodes.contains(code)) return t('errors.$code');
    if (statusCode == 400 || code == 'invalid') return t('errors.validation');
    if (statusCode == 401) return t('errors.session_expired');
    if (statusCode == 403) return t('errors.permission_denied');
    if (statusCode == 404) return t('errors.not_found');
    if (statusCode == 409) return t('errors.invalid_transition');
    if (statusCode == 429) return t('errors.throttled');
    return t('common.generic_error');
  }

  @override
  String toString() => 'ApiException($code, $message)';
}
