import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';
import 'package:ngo_app/features/jobs/presentation/fellow_job_detail_screen.dart';
import 'package:ngo_app/features/jobs/services/job_capture.dart';

class FakeJobs extends JobsRepository {
  FakeJobs() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));
  int submissions = 0;
  bool geotagEnabled = false;
  double? submittedLatitude;
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'id': id,
        'title': 'Field visit',
        'description': 'Visit the village',
        'expected_hours': '2.00',
        'status': 'assigned',
        'submissions': [],
        'transitions': []
      };
  @override
  Future<Map<String, dynamic>> config() async =>
      {'geotag_enabled': geotagEnabled, 'max_photos': 5};
  @override
  Future<Map<String, dynamic>> submit(String id,
      {required String actualHours,
      required List<JobPhotoCapture> photos,
      DateTime? deviceTimestamp,
      double? latitude,
      double? longitude}) {
    submissions++;
    submittedLatitude = latitude;
    return pending.future;
  }
}

class FakeCapture extends JobCapture {
  bool fail = false;
  int locationRequests = 0;
  @override
  Future<Position?> optionalLocation() async {
    locationRequests++;
    return null;
  }

  @override
  Future<JobPhotoCapture?> camera() async {
    if (fail) throw StateError('Camera permission denied');
    return JobPhotoCapture(
        bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='),
        filename: 'camera.png');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async => <String, dynamic>{});
    await EasyLocalization.ensureInitialized();
  });
  Future<void> boot(
      WidgetTester tester, FakeJobs jobs, FakeCapture capture) async {
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
            overrides: [
              jobsRepositoryProvider.overrideWithValue(jobs),
              jobCaptureProvider.overrideWithValue(capture)
            ],
            child:
                const MaterialApp(home: FellowJobDetailScreen(jobId: 'one')))));
    await tester.pumpAndSettle();
  }

  testWidgets('hours and at least one photo are required before sending',
      (tester) async {
    final jobs = FakeJobs();
    await boot(tester, jobs, FakeCapture());
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(jobs.submissions, 0);
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(jobs.submissions, 0);
  });
  testWidgets('camera failure leaves form usable and sends no submission',
      (tester) async {
    final jobs = FakeJobs();
    await boot(tester, jobs, FakeCapture()..fail = true);
    await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(jobs.submissions, 0);
  });
  testWidgets(
      'pending submission disables duplicate taps and optional location is absent',
      (tester) async {
    final jobs = FakeJobs();
    await boot(tester, jobs, FakeCapture());
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.enterText(find.byType(TextFormField), '2.50');
    await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(jobs.submissions, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    jobs.pending.complete({});
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('opted-in unavailable location does not block submission',
      (tester) async {
    final jobs = FakeJobs()..geotagEnabled = true;
    final capture = FakeCapture();
    await boot(tester, jobs, capture);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(capture.locationRequests, 0);
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(capture.locationRequests, 1);
    expect(jobs.submissions, 1);
    expect(jobs.submittedLatitude, isNull);
    jobs.pending.complete({});
    await tester.pumpAndSettle();
  });
}
