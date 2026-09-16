import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';

class HealthStatus {
  const HealthStatus({required this.status, required this.version, required this.time});

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String,
      version: json['version'] as String,
      time: json['time'] as String,
    );
  }

  final String status;
  final String version;
  final String time;
}

class HealthService {
  HealthService(this._apiClient);

  final ApiClient _apiClient;

  Future<HealthStatus> fetchHealth() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/health',
        options: Options(extra: {'skipAuthHeader': true}),
      );
      return HealthStatus.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
