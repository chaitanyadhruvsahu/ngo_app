import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/providers.dart';

final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

class NotificationsRepository {
  NotificationsRepository(this.api);
  final ApiClient api;
  Future<List<Map<String, dynamic>>> pages(String path) async {
    try {
      final rows = <Map<String, dynamic>>[];
      var page = 1;
      while (true) {
        final response = await api.dio
            .get<Map<String, dynamic>>(path, queryParameters: {'page': page});
        final data = response.data!;
        rows.addAll((data['results'] as List).cast<Map<String, dynamic>>());
        if (data['next'] == null) return rows;
        page++;
      }
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<List<Map<String, dynamic>>> blocks() async {
    try {
      return (await api.dio.get<List<dynamic>>('/blocks'))
          .data!
          .cast<Map<String, dynamic>>();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    try {
      await api.dio.post('/admin/notifications', data: data);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<void> mark(String id, {bool dismiss = false}) async {
    try {
      await api.dio.post('/notifications/$id/${dismiss ? 'dismiss' : 'read'}');
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
