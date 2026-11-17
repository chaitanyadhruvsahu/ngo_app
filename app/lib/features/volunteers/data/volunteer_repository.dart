import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

class VolunteerRepository {
  VolunteerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Volunteer>> getMyVolunteers() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>('/volunteers/');
      return response.data!.map((json) => Volunteer.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Volunteer> create(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>('/volunteers/', data: data);
      return Volunteer.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Volunteer> update(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>('/volunteers/$id', data: data);
      return Volunteer.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.dio.delete('/volunteers/$id');
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
