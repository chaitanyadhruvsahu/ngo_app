import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:ngo_app/core/api/api_client.dart';

class JobPhotoCapture {
  const JobPhotoCapture({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

class JobsRepository {
  JobsRepository(this._api, {this.onChanged});
  final ApiClient _api;
  final void Function()? onChanged;

  Future<Map<String, dynamic>> _request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    try {
      final response = await _api.dio.request<Map<String, dynamic>>(path,
          data: data, queryParameters: query, options: Options(method: method));
      if (method != 'GET') onChanged?.call();
      return response.data!;
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Map<String, dynamic>> list(
          {bool mine = false,
          String? fellow,
          String? status,
          int? block,
          int page = 1}) =>
      _request(mine ? '/jobs/mine' : '/jobs', query: {
        'page': page,
        if (block != null) 'block': block,
        if (fellow != null && fellow.isNotEmpty) 'fellow': fellow,
        if (status != null && status.isNotEmpty) 'status': status
      });
  Future<Map<String, dynamic>> config() => _request('/jobs/config');
  Future<Map<String, dynamic>> detail(String id) => _request('/jobs/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _request('/jobs', method: 'POST', data: data);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _request('/jobs/$id', method: 'PATCH', data: data);
  Future<Map<String, dynamic>> start(String id) =>
      _request('/jobs/$id/start', method: 'POST', data: {});
  Future<Map<String, dynamic>> review(String id,
          {required String submissionId,
          required String decision,
          String? reason}) =>
      _request('/jobs/$id/review', method: 'POST', data: {
        'submission_id': submissionId,
        'decision': decision,
        if (reason != null) 'reason': reason
      });
  Future<Map<String, dynamic>> reassign(String id,
          {required String assignedTo, required String reason}) =>
      _request('/jobs/$id/reassign',
          method: 'POST', data: {'assigned_to': assignedTo, 'reason': reason});

  Future<Uint8List> photo(String jobId, String photoId) async {
    try {
      final response = await _api.dio.get<List<int>>(
          '/jobs/$jobId/photos/$photoId',
          options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Map<String, dynamic>> submit(String id,
      {required String actualHours,
      required List<JobPhotoCapture> photos,
      DateTime? deviceTimestamp,
      double? latitude,
      double? longitude}) async {
    FormData body() => FormData.fromMap({
          'actual_hours': actualHours,
          'photos': photos
              .map((photo) => MultipartFile.fromBytes(photo.bytes,
                  filename: photo.filename))
              .toList(),
          if (deviceTimestamp != null)
            'device_timestamp': deviceTimestamp.toUtc().toIso8601String(),
          if (latitude != null && longitude != null) ...{
            'location_consent': 'true',
            'geotag_lat': latitude.toStringAsFixed(6),
            'geotag_lng': longitude.toStringAsFixed(6)
          },
        }, ListFormat.multi);
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
          '/jobs/$id/submissions',
          data: body(),
          options: Options(extra: {'rebuildBody': body}));
      onChanged?.call();
      return response.data!;
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
