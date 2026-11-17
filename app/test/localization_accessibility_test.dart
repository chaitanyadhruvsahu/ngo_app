import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngo_app/app.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/core/i18n/language_menu.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

import 'test_support/fake_auth_repository.dart';

Map<String, String> flatten(Map<String, dynamic> input, [String prefix = '']) {
  final result = <String, String>{};
  for (final entry in input.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      result.addAll(flatten(entry.value as Map<String, dynamic>, key));
    } else {
      result[key] = entry.value as String;
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('English/Hindi keys, interpolation fields and literal lookups match',
      () {
    final en = flatten(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>);
    final hi = flatten(
        jsonDecode(File('assets/translations/hi.json').readAsStringSync())
            as Map<String, dynamic>);
    expect(en.keys.toSet(), hi.keys.toSet());
    final placeholders = RegExp(r'\{\w+\}');
    for (final key in en.keys) {
      expect(hi[key]!.trim(), isNotEmpty, reason: key);
      expect(placeholders.allMatches(en[key]!).map((m) => m[0]).toSet(),
          placeholders.allMatches(hi[key]!).map((m) => m[0]).toSet(),
          reason: key);
    }
    final calls = RegExp("\\bt\\('([^'\u0024]+)'[,)\\s]");
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final match in calls.allMatches(file.readAsStringSync())) {
        expect(en.containsKey(match[1]), isTrue,
            reason: '${file.path}: ${match[1]}');
      }
    }
  });

  test('primary body, error and muted colors have readable contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final color in [
      AppColors.onSurface,
      AppColors.muted,
      AppColors.error
    ]) {
      expect(contrast(color, AppColors.background), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(AppColors.onPrimary, AppColors.primary),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('Hindi login and validation fit a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      startLocale: const Locale('en'),
      path: 'assets/translations',
      child: ProviderScope(overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ], child: const NgoApp()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LanguageMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(LanguageMenu));
    expect(context.locale.languageCode, 'hi');
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('सही ईमेल पता लिखें, जैसे name@example.com।'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
