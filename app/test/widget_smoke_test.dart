import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngo_app/app.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/auth/presentation/reset_password_confirm_screen.dart';
import 'package:ngo_app/features/auth/presentation/verify_email_screen.dart';

import 'test_support/fake_auth_repository.dart';

void main() {
  setUp(() => rootBundle.clear());
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('unauthenticated app boots to the login screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi')],
        startLocale: const Locale('en'),
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const NgoApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsWidgets);
  });

  for (final route in ['/reset-password/confirm', '/verify-email']) {
    testWidgets('cold start preserves email link $route and token', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '$route?token=release-token';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi')],
        startLocale: const Locale('en'),
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const NgoApp(),
        ),
      ));
      await tester.pumpAndSettle();
      if (route == '/verify-email') {
        expect(tester.widget<VerifyEmailScreen>(find.byType(VerifyEmailScreen)).token,
            'release-token');
      } else {
        expect(tester.widget<ResetPasswordConfirmScreen>(
            find.byType(ResetPasswordConfirmScreen)).token, 'release-token');
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(ElevatedButton).last);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
