import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';

void main() {
  test(
      'submission uses repeated photos and builds fresh multipart for authentication retries',
      () async {
    final client = ApiClient(tokenStorage: InMemoryTokenStorage());
    late RequestOptions request;
    client.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response(
          requestOptions: options,
          data: <String, dynamic>{'status': 'submitted'},
          statusCode: 201));
    }));
    await JobsRepository(client).submit('job-1', actualHours: '2.50', photos: [
      JobPhotoCapture(bytes: Uint8List.fromList([1, 2]), filename: 'a.png'),
      JobPhotoCapture(bytes: Uint8List.fromList([3, 4]), filename: 'b.png')
    ]);
    expect(request.path, '/jobs/job-1/submissions');
    final body = request.data as FormData;
    expect(body.files.map((entry) => entry.key), ['photos', 'photos']);
    expect(Map.fromEntries(body.fields)['actual_hours'], '2.50');
    expect(
        body.fields.any((entry) =>
            entry.key.startsWith('geotag') || entry.key == 'location_consent'),
        isFalse);
    await body.finalize().drain<void>();
    final rebuilt = (request.extra['rebuildBody'] as FormData Function())();
    expect(identical(body, rebuilt), isFalse);
    expect(rebuilt.isFinalized, isFalse);
    expect(rebuilt.files.length, 2);
    await JobsRepository(client).submit('job-1',
        actualHours: '1',
        photos: [],
        latitude: 28.123456789,
        longitude: 77.987654321);
    final coordinates = Map.fromEntries((request.data as FormData).fields);
    expect(coordinates['geotag_lat'], '28.123457');
    expect(coordinates['geotag_lng'], '77.987654');
    expect(coordinates['location_consent'], 'true');
  });
  test('mine list is paginated and review carries stale-submission guard',
      () async {
    final client = ApiClient(tokenStorage: InMemoryTokenStorage());
    final requests = <RequestOptions>[];
    client.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(
          requestOptions: options, data: <String, dynamic>{}, statusCode: 200));
    }));
    final repository = JobsRepository(client);
    await repository.list(mine: true, status: 'rejected', page: 2);
    expect(requests.last.path, '/jobs/mine');
    expect(requests.last.queryParameters, {'status': 'rejected', 'page': 2});
    await repository.review('job-1',
        submissionId: 'submission-2',
        decision: 'rejected',
        reason: 'Photo is unclear');
    expect(requests.last.data, {
      'submission_id': 'submission-2',
      'decision': 'rejected',
      'reason': 'Photo is unclear'
    });
  });
}
