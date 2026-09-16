import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/core/config/app_config.dart';

/// Authenticated API client shared by every feature. It attaches the
/// stored access token to outgoing requests and transparently refreshes it
/// (once, via a single in-flight refresh call shared across concurrent
/// 401s) on expiry. Every later phase's API calls should go through this
/// client rather than creating their own Dio instance — see
/// `/app/README.md` for the rationale.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, this.onSessionExpired})
      : _tokenStorage = tokenStorage,
        dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.extra.containsKey('skipAuthHeader')) {
            final accessToken = await _tokenStorage.readAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final hasRefreshToken = await _tokenStorage.readRefreshToken() != null;

          if (isUnauthorized && !alreadyRetried && hasRefreshToken) {
            final refreshed = await _refreshAccessToken();
            if (refreshed != null) {
              final retryOptions = error.requestOptions..extra['retried'] = true;
              retryOptions.headers['Authorization'] = 'Bearer $refreshed';
              try {
                final response = await dio.fetch(retryOptions);
                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                handler.next(retryError);
                return;
              }
            }
            await _tokenStorage.clear();
            onSessionExpired?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  /// Called once a refresh attempt itself fails, so the app can route the
  /// user back to login. Set by the app's auth state provider.
  void Function()? onSessionExpired;

  Future<String?>? _refreshFuture;

  Future<String?> _refreshAccessToken() {
    // Coalesce concurrent 401s into a single refresh call.
    return _refreshFuture ??= _performRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuthHeader': true}),
      );
      final data = response.data!;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
      await _tokenStorage.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
      return newAccessToken;
    } on DioException {
      return null;
    }
  }

  /// Converts a DioException into the app-level [ApiException] using the
  /// backend's shared error envelope. Callers should catch [DioException]
  /// and pass it through this to get a user-displayable message.
  static ApiException toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException.fromEnvelope(data, statusCode: error.response?.statusCode);
    }
    return ApiException(
      code: 'network_error',
      message: 'Could not reach the server. Check your connection and try again.',
      statusCode: error.response?.statusCode,
    );
  }
}
