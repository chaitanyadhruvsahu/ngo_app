import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_app/app.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';
import 'package:ngo_app/core/api/token_storage.dart';

import 'test_support/fake_auth_repository.dart';

void main() {
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('unauthenticated app boots to the login screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi')],
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
}
