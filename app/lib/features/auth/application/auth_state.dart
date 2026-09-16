enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.role});

  final AuthStatus status;
  final String? role; // 'admin' | 'fellow', set once authenticated.

  bool get isAdmin => role == 'admin';
  bool get isFellow => role == 'fellow';

  AuthState copyWith({AuthStatus? status, String? role}) {
    return AuthState(status: status ?? this.status, role: role ?? this.role);
  }

  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}
