import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/notifications/data/notifications_repository.dart';
import 'package:ngo_app/features/notifications/presentation/updates_screen.dart';

class FakeNotifications extends NotificationsRepository {
  FakeNotifications() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));
  final pending = Completer<void>();
  int marks = 0;
  String? markedId;
  bool dismissed = false;
  @override
  Future<List<Map<String, dynamic>>> pages(String path) async => [
        {
          'id': 'one',
          'type': 'training',
          'title_en': 'English reminder',
          'title_hi': 'हिंदी अनुस्मारक',
          'body_en': 'Training details',
          'body_hi': 'प्रशिक्षण का विवरण',
          'scheduled_time': DateTime.now().toUtc().toIso8601String(),
          'read_at': dismissed ? DateTime.now().toIso8601String() : null,
          'dismissed_at': dismissed ? DateTime.now().toIso8601String() : null,
        }
      ];
  @override
  Future<void> mark(String id, {bool dismiss = false}) async {
    marks++;
    markedId = id;
    await pending.future;
    dismissed = dismiss;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Future<void> boot(WidgetTester tester, FakeNotifications repo,
      {String language = 'en'}) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
          overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
          child: Builder(
              builder: (context) => MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const UpdatesScreen(),
                  ))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Hindi updates present authored Hindi content', (tester) async {
    await boot(tester, FakeNotifications(), language: 'hi');
    expect(find.text('हिंदी अनुस्मारक'), findsOneWidget);
    expect(find.text('प्रशिक्षण का विवरण'), findsOneWidget);
    expect(find.text('English reminder'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'dismiss targets one reminder and disables duplicate actions until completion',
      (tester) async {
    final repo = FakeNotifications();
    await boot(tester, repo);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(repo.marks, 1);
    expect(repo.markedId, 'one');
    for (final button
        in tester.widgetList<TextButton>(find.byType(TextButton))) {
      expect(button.onPressed, isNull);
    }
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Dismiss'), findsNothing);
  });
}
