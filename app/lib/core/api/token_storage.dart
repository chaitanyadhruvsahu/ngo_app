import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT storage seam. Production uses [SecureTokenStorage]
/// (flutter_secure_storage — Keychain on iOS, Keystore-backed
/// EncryptedSharedPreferences on Android, `localStorage` on web — never
/// `SharedPreferences` in plain text, see ADR-0003 and `/app/README.md`).
/// Tests substitute [InMemoryTokenStorage] via provider overrides, since
/// the secure storage plugin needs a real platform channel that isn't
/// available in widget/unit tests.
///
/// Per ADR-0007: on web, the refresh token is deliberately never written
/// here. `flutter_secure_storage`'s web backend keeps both its encryption
/// key and the encrypted value in plain `localStorage`, so it's readable
/// by anything that can run JS on the page (XSS) — not meaningfully safer
/// than an unencrypted cookie for a long-lived credential. The backend
/// instead sets the refresh token as an httpOnly cookie on login, which
/// Dart/JS can never read at all; [ApiClient] relies on the browser
/// attaching it automatically. Native platforms are unaffected — Keychain
/// / Keystore-backed storage is real OS-level secure storage, so the
/// refresh token is still persisted there as before.
abstract class TokenStorage {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  });

  Future<void> saveTokens(
      {required String accessToken, required String refreshToken});

  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<String?> readRole();

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _roleKey = 'role';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    // The web implementation lazily creates a shared encryption key. Two
    // concurrent first writes can each create a different key, leaving one
    // stored value undecryptable on the next read.
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (!kIsWeb) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
    await _storage.write(key: _roleKey, value: role);
  }

  @override
  Future<void> saveTokens(
      {required String accessToken, required String refreshToken}) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      if (!kIsWeb) _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() async =>
      kIsWeb ? null : await _storage.read(key: _refreshTokenKey);

  @override
  Future<String?> readRole() => _storage.read(key: _roleKey);

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _roleKey),
    ]);
  }
}

class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;
  String? _role;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _role = role;
  }

  @override
  Future<void> saveTokens(
      {required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<String?> readRole() async => _role;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _role = null;
  }
}
