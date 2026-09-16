import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';
import 'package:ngo_app/features/auth/application/auth_state.dart';

import 'test_support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late InMemoryTokenStorage tokenStorage;
  late AuthController controller;

  setUp(() {
    repository = FakeAuthRepository();
    tokenStorage = InMemoryTokenStorage();
    controller = AuthController(repository: repository, tokenStorage: tokenStorage);
  });

  test('bootstraps to unauthenticated when no session is stored', () async {
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AuthStatus.unauthenticated);
  });

  test('bootstraps to authenticated when a session is already stored', () async {
    await tokenStorage.saveSession(accessToken: 'a', refreshToken: 'r', role: 'fellow');
    final restored = AuthController(repository: repository, tokenStorage: tokenStorage);
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.status, AuthStatus.authenticated);
    expect(restored.state.role, 'fellow');
  });

  test('full signup -> verify -> login flow', () async {
    await controller.signup(email: 'fellow@example.com', password: 'correct-horse-battery-1');
    // Cannot log in before verifying.
    await expectLater(
      controller.login(email: 'fellow@example.com', password: 'correct-horse-battery-1'),
      throwsA(isA<Exception>()),
    );

    await controller.verifyEmail(repository.issuedVerificationToken!);
    await controller.login(email: 'fellow@example.com', password: 'correct-horse-battery-1');

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.role, 'fellow');
    expect(await tokenStorage.readAccessToken(), 'fake-access');
  });

  test('logout clears the stored session', () async {
    await controller.signup(email: 'fellow2@example.com', password: 'correct-horse-battery-1');
    await controller.verifyEmail(repository.issuedVerificationToken!);
    await controller.login(email: 'fellow2@example.com', password: 'correct-horse-battery-1');

    await controller.logout();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(await tokenStorage.readAccessToken(), isNull);
  });

  test('a used verification token cannot be replayed', () async {
    await controller.signup(email: 'fellow3@example.com', password: 'correct-horse-battery-1');
    final token = repository.issuedVerificationToken!;
    await controller.verifyEmail(token);

    await expectLater(controller.verifyEmail(token), throwsA(isA<Exception>()));
  });
}
