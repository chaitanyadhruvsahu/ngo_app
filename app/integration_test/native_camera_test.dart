import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngo_app/features/jobs/services/job_capture.dart';

// Run on an Android device/emulator. The operator (or adb UI automation) must
// take and confirm a photo in the real Android camera activity when it opens.
// No image_picker mock or gallery upload is used by this acceptance check.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native Android camera returns a decodable evidence photo',
      (tester) async {
    expect(Platform.isAndroid, isTrue,
        reason: 'This acceptance test must run on Android.');
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Native camera acceptance'))),
    ));
    await tester.pumpAndSettle();
    final photo = await tester.runAsync(() => JobCapture().camera());
    expect(photo, isNotNull, reason: 'Take and confirm the camera photo.');
    expect(photo!.bytes.length, greaterThan(1000));
    final codec = await ui.instantiateImageCodec(photo.bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
    debugPrint('NATIVE_CAMERA_PASS bytes=${photo.bytes.length} '
        'size=${frame.image.width}x${frame.image.height}');
    frame.image.dispose();
    codec.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
