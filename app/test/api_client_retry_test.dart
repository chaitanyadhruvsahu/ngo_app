import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/api/token_storage.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Stream<Uint8List>?) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) => respond(options, stream);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(int status, Map<String, dynamic> json) =>
    ResponseBody.fromString(jsonEncode(json), status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

void main() {
  test('expired refresh ends session once without recursion or hanging', () async {
    final storage = InMemoryTokenStorage();
    await storage.saveSession(accessToken: 'expired', refreshToken: 'expired', role: 'fellow');
    var refreshes = 0;
    var expirations = 0;
    final client = ApiClient(tokenStorage: storage, onSessionExpired: () => expirations++);
    client.dio.httpClientAdapter = _Adapter((options, stream) async {
      if (options.path == '/auth/refresh') refreshes++;
      return response(401, {'error': {'code': 'expired', 'message': 'Expired'}});
    });
    await expectLater(client.dio.get('/jobs/mine').timeout(const Duration(seconds: 3)),
        throwsA(isA<DioException>()));
    expect(refreshes, 1);
    expect(expirations, 1);
    expect(await storage.readAccessToken(), isNull);
    client.dio.close();
  });

  test('photo upload retries intact multipart after one token refresh', () async {
    final storage = InMemoryTokenStorage();
    await storage.saveSession(accessToken: 'old', refreshToken: 'refresh', role: 'fellow');
    final client = ApiClient(tokenStorage: storage);
    var uploads = 0;
    var refreshes = 0;
    final payloads = <String>[];
    client.dio.httpClientAdapter = _Adapter((options, stream) async {
      if (options.path == '/auth/refresh') {
        refreshes++;
        return response(200, {'access_token': 'new', 'refresh_token': 'rotated'});
      }
      uploads++;
      final bytes = await stream!.expand((chunk) => chunk).toList();
      payloads.add(utf8.decode(bytes));
      if (uploads == 1) return response(401, {});
      expect(options.headers['Authorization'], 'Bearer new');
      return response(201, {'status': 'submitted'});
    });
    final result = await JobsRepository(client).submit('one', actualHours: '2.50', photos: [
      JobPhotoCapture(bytes: Uint8List.fromList(utf8.encode('photo bytes')), filename: 'proof.jpg'),
    ]);
    expect(result['status'], 'submitted');
    expect(uploads, 2);
    expect(refreshes, 1);
    for (final payload in payloads) {
      expect(payload, contains('photo bytes'));
      expect(payload, contains('2.50'));
      expect(payload, contains('proof.jpg'));
    }
    client.dio.close();
  });
}
