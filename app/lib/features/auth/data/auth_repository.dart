import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';

class LoginResult {
  const LoginResult(
      {required this.accessToken,
      required this.refreshToken,
      required this.role});

  final String accessToken;
  final String refreshToken;
  final String role;
}

/// Wraps the Phase 1 `/api/v1/auth/*` endpoints. Every method throws
/// [ApiException] (never a raw [DioException]) so UI code has one error
/// type to handle.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> signup({required String email, required String password}) {
    return _post('/auth/signup', {'email': email, 'password': password});
  }

  Future<void> verifyEmail(String token) {
    return _post('/auth/verify-email', {'token': token});
  }

  Future<void> resendVerification(String email) {
    return _post('/auth/resend-verification', {'email': email});
  }

  Future<LoginResult> login(
      {required String email, required String password}) async {
    final data =
        await _post('/auth/login', {'email': email, 'password': password});
    return LoginResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      role: data['role'] as String,
    );
  }

  /// [refreshToken] is null on web — there's nothing stored locally to
  /// send; the backend blacklists whatever the httpOnly cookie carries
  /// instead (ADR-0007).
  Future<void> logout(String? refreshToken) {
    return _post('/auth/logout',
        refreshToken != null ? {'refresh_token': refreshToken} : {});
  }

  Future<void> requestPasswordReset(String email) {
    return _post('/auth/password-reset/request', {'email': email});
  }

  Future<void> confirmPasswordReset(
      {required String token, required String newPassword}) {
    return _post('/auth/password-reset/confirm',
        {'token': token, 'new_password': newPassword});
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(path,
          data: body,
          options: path == '/auth/logout'
              ? null
              : Options(extra: {'skipAuthHeader': true, 'skipRefresh': true}));
      return response.data ?? const {};
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
