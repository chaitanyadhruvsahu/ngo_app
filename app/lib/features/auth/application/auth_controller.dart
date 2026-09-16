import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/auth/application/auth_state.dart';
import 'package:ngo_app/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(
    repository: ref.watch(authRepositoryProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
  // If the API client's refresh attempt fails (refresh token itself
  // expired/blacklisted), fall back to the login screen.
  ref.watch(apiClientProvider).onSessionExpired = controller.forceLogout;
  return controller;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthRepository repository, required TokenStorage tokenStorage})
      : _repository = repository,
        _tokenStorage = tokenStorage,
        super(const AuthState()) {
    _bootstrap();
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  Future<void> _bootstrap() async {
    final accessToken = await _tokenStorage.readAccessToken();
    final role = await _tokenStorage.readRole();
    if (accessToken != null && role != null) {
      state = AuthState(status: AuthStatus.authenticated, role: role);
    } else {
      state = AuthState.unauthenticated;
    }
  }

  Future<void> signup({required String email, required String password}) {
    return _repository.signup(email: email, password: password);
  }

  Future<void> verifyEmail(String token) {
    return _repository.verifyEmail(token);
  }

  Future<void> resendVerification(String email) {
    return _repository.resendVerification(email);
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      role: result.role,
    );
    state = AuthState(status: AuthStatus.authenticated, role: result.role);
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    try {
      if (refreshToken != null) {
        await _repository.logout(refreshToken);
      }
    } finally {
      await _tokenStorage.clear();
      state = AuthState.unauthenticated;
    }
  }

  Future<void> requestPasswordReset(String email) {
    return _repository.requestPasswordReset(email);
  }

  Future<void> confirmPasswordReset({required String token, required String newPassword}) {
    return _repository.confirmPasswordReset(token: token, newPassword: newPassword);
  }

  /// Local-only logout used when a refresh attempt fails server-side —
  /// there is no valid refresh token left to blacklist.
  Future<void> forceLogout() async {
    await _tokenStorage.clear();
    state = AuthState.unauthenticated;
  }
}
