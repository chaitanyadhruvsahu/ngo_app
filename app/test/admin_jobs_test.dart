import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';
import 'package:ngo_app/features/jobs/admin/admin_jobs_screen.dart';

class _FakeJobs extends JobsRepository {
  _FakeJobs() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));
  int reviews = 0;
  String? reviewedSubmission;
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'id': id,
        'title': 'Field visit',
        'description': 'Village visit',
        'expected_hours': '2.00',
        'status': 'submitted',
        'assigned_to_name': 'Fellow',
        'can_edit': false,
        'can_reassign': false,
        'submissions': [
          {
            'id': 'latest',
            'actual_hours': '2.50',
            'submitted_at': '2026-09-20',
            'submitted_by': 'fellow',
            'review_status': 'pending',
            'photos': []
          }
        ],
        'transitions': [],
      };
  @override
  Future<Map<String, dynamic>> review(String id,
      {required String submissionId,
      required String decision,
      String? reason}) {
    reviews++;
    reviewedSubmission = submissionId;
    return pending.future;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Future<void> boot(WidgetTester tester, _FakeJobs jobs) async {
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
            overrides: [jobsRepositoryProvider.overrideWithValue(jobs)],
            child:
                const MaterialApp(home: AdminJobDetailScreen(jobId: 'one')))));
    await tester.pumpAndSettle();
  }

  testWidgets('rejection requires a nonblank reason and sends no early review',
      (tester) async {
    final jobs = _FakeJobs();
    await boot(tester, jobs);
    final reject = find.byType(OutlinedButton);
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(jobs.reviews, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  testWidgets(
      'review submits current submission ID and prevents duplicate reviews; failure recovers',
      (tester) async {
    final jobs = _FakeJobs();
    await boot(tester, jobs);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(jobs.reviews, 1);
    expect(jobs.reviewedSubmission, 'latest');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    jobs.pending.completeError(StateError('Network failure'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
