import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/auth/data/auth_repository.dart';

/// In-memory stand-in for [AuthRepository] used across widget/unit tests,
/// so tests exercise real controller/UI logic without a live backend.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  final Map<String, String> _passwordsByEmail = {};
  final Map<String, bool> _verifiedByEmail = {};
  String? issuedVerificationToken;
  String? issuedResetToken;
  bool throwOnLogin = false;

  @override
  Future<void> signup({required String email, required String password}) async {
    _passwordsByEmail[email] = password;
    _verifiedByEmail[email] = false;
    issuedVerificationToken = 'fake-verify-token-for-$email';
  }

  @override
  Future<void> verifyEmail(String token) async {
    final email = _emailForVerificationToken(token);
    if (email == null) {
      throw const ApiException(code: 'invalid_token', message: 'Invalid or expired token.');
    }
    _verifiedByEmail[email] = true;
    issuedVerificationToken = null; // single-use, like the real backend token.
  }

  @override
  Future<void> resendVerification(String email) async {
    issuedVerificationToken = 'fake-verify-token-for-$email';
  }

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    if (throwOnLogin ||
        _passwordsByEmail[email] != password ||
        _verifiedByEmail[email] != true) {
      throw const ApiException(code: 'invalid_credentials', message: 'Invalid email or password.');
    }
    return const LoginResult(accessToken: 'fake-access', refreshToken: 'fake-refresh', role: 'fellow');
  }

  @override
  Future<void> logout(String? refreshToken) async {}

  @override
  Future<void> requestPasswordReset(String email) async {
    issuedResetToken = 'fake-reset-token-for-$email';
  }

  @override
  Future<void> confirmPasswordReset({required String token, required String newPassword}) async {
    final email = _emailForResetToken(token);
    if (email == null) {
      throw const ApiException(code: 'invalid_token', message: 'Invalid or expired token.');
    }
    _passwordsByEmail[email] = newPassword;
    issuedResetToken = null; // single-use, like the real backend token.
  }

  String? _emailForVerificationToken(String token) {
    if (issuedVerificationToken != token) return null;
    return token.replaceFirst('fake-verify-token-for-', '');
  }

  String? _emailForResetToken(String token) {
    if (issuedResetToken != token) return null;
    return token.replaceFirst('fake-reset-token-for-', '');
  }
}
