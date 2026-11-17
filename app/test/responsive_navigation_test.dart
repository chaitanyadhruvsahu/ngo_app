import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/core/theme/responsive_widgets.dart';
import 'package:ngo_app/features/onboarding/presentation/onboarding_shell_screen.dart';
import 'package:ngo_app/features/profile/application/profile_controller.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';
import 'package:ngo_app/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReadyProfileController extends ProfileController {
  _ReadyProfileController(FellowProfile profile)
      : super(ProfileRepository(
            ApiClient(tokenStorage: InMemoryTokenStorage()))) {
    state = AsyncValue.data(profile);
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final width in [320.0, 600.0, 1024.0]) {
    testWidgets('task cards remain usable at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ActionGrid(children: [
                for (var i = 0; i < 5; i++)
                  ActionCard(
                    icon: Icons.work_outline,
                    title: 'Task $i',
                    description: 'A clear description of this task',
                    onTap: () => tapped = true,
                  ),
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Task 0'), findsOneWidget);
      await tester.tap(find.text('Task 0'));
      expect(tapped, isTrue);
    });
  }

  testWidgets('completed status is one readable badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusBadge(label: 'All set', complete: true)),
    ));
    expect(find.text('All set'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('ready fellow sees one status, not onboarding history',
      (tester) async {
    const profile = FellowProfile(
      id: '1',
      email: 'asha@demo.test',
      block: null,
      onboardingStep: 'active',
      fullName: 'Asha Verma',
      dateOfBirth: '1992-04-12',
      phoneNumber: '+919000000003',
      address: 'Demo address',
      aadhaarNumber: '',
      bankAccountNumber: '',
      bankIfsc: '',
      bankAccountHolderName: '',
      consentGivenAt: null,
    );
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      startLocale: const Locale('en'),
      path: 'assets/translations',
      child: Builder(
          builder: (context) => ProviderScope(
                overrides: [
                  profileControllerProvider
                      .overrideWith((ref) => _ReadyProfileController(profile))
                ],
                child: MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const OnboardingShellScreen(),
                ),
              )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('All set'), findsOneWidget);
    expect(find.text('Account created'), findsNothing);
    expect(find.text('Email verified'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
