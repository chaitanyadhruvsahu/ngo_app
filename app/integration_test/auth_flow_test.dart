import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngo_app/app.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

import '../test/test_support/fake_auth_repository.dart';

/// Scripted signup -> (mocked) verify -> login -> role-routed landing
/// screen flow, per the Phase 1 E2E testing mandate. The backend is
/// replaced with [FakeAuthRepository] — this exercises real widget/router
/// behavior without depending on a live server.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signup, verify, log in, and land on the fellow onboarding shell', (tester) async {
    final fakeRepository = FakeAuthRepository();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
            authRepositoryProvider.overrideWithValue(fakeRepository),
          ],
          child: const NgoApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on the login screen; navigate to signup.
    await tester.tap(find.widgetWithText(TextButton, "Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'fellow@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct-horse-battery-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
    await tester.pumpAndSettle();

    // Signup succeeded; simulate opening the emailed verification link.
    expect(fakeRepository.issuedVerificationToken, isNotNull);
    await fakeRepository.verifyEmail(fakeRepository.issuedVerificationToken!);

    // Back to login from the signup success screen, then sign in for real.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'fellow@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct-horse-battery-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    // Lands on the Fellow onboarding shell, not the Admin shell.
    expect(find.text('Get started'), findsOneWidget);
  });
}
