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
        // withCredentials: on web this makes the browser send/accept the
        // httpOnly refresh-token cookie (ADR-0007); ignored on other
        // platforms, which don't have a cookie jar in the same sense.
        dio = Dio(BaseOptions(
            baseUrl: AppConfig.apiBaseUrl, extra: {'withCredentials': true})) {
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
          if (error.response?.statusCode != 401 ||
              error.requestOptions.extra['skipRefresh'] == true) {
            handler.next(error);
            return;
          }
          if (error.requestOptions.extra['retried'] == true) {
            await _expireSession();
            handler.next(error);
            return;
          }
          try {
            // A late response for the old token must not rotate the newly
            // refreshed cookie again after another request already succeeded.
            final current = await _tokenStorage.readAccessToken();
            final sent = error.requestOptions.headers['Authorization'];
            final token = current != null && sent != 'Bearer $current'
                ? current
                : await _refreshAccessToken();
            if (token != null) {
              final retry = error.requestOptions..extra['retried'] = true;
              retry.headers['Authorization'] = 'Bearer $token';
              final rebuild = retry.extra['rebuildBody'];
              if (rebuild is FormData Function()) {
                retry.data = rebuild();
              } else if (retry.data is FormData) {
                retry.data = (retry.data as FormData).clone();
              }
              final response = await dio.fetch<dynamic>(retry);
              handler.resolve(response);
              return;
            }
          } on DioException catch (retryError) {
            handler.next(retryError);
            return;
          } catch (_) {
            // Storage/cast failures must finish the request, not hang the UI.
          }
          await _expireSession();
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
  bool _expiring = false;

  Future<void> _expireSession() async {
    if (_expiring) return;
    _expiring = true;
    try {
      await _tokenStorage.clear();
    } catch (_) {
      // Redirect even when secure storage is unavailable.
    } finally {
      onSessionExpired?.call();
      _expiring = false;
    }
  }

  Future<String?> _refreshAccessToken() {
    // Coalesce concurrent 401s into a single refresh call.
    return _refreshFuture ??=
        _performRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<String?> _performRefresh() async {
    // Mobile sends its securely-stored refresh token in the body; web sends
    // none — the browser attaches the httpOnly cookie itself, which the
    // backend falls back to when the body has no refresh_token (ADR-0007).
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: refreshToken != null
            ? {'refresh_token': refreshToken}
            : <String, dynamic>{},
        options: Options(extra: {
          'skipAuthHeader': true,
          'skipRefresh': true,
          'withCredentials': true
        }),
      );
      final data = response.data!;
      final newAccessToken = data['access_token'] as String;
      // ROTATE_REFRESH_TOKENS is on server-side, so a successful refresh
      // always returns a new refresh_token too.
      final newRefreshToken = data['refresh_token'] as String;
      await _tokenStorage.saveTokens(
          accessToken: newAccessToken, refreshToken: newRefreshToken);
      return newAccessToken;
    } catch (_) {
      return null;
    }
  }

  /// Converts a DioException into the app-level [ApiException] using the
  /// backend's shared error envelope. Callers should catch [DioException]
  /// and pass it through this to get a user-displayable message.
  static ApiException toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException.fromEnvelope(data,
          statusCode: error.response?.statusCode);
    }
    return ApiException(
      code: 'network_error',
      message:
          'Could not reach the server. Check your connection and try again.',
      statusCode: error.response?.statusCode,
    );
  }
}
