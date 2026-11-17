import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/features/profile/data/block.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';

class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Block>> getBlocks() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>('/blocks');
      return response.data!.map((json) => Block.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<FellowProfile> getMyProfile() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/profile/me');
      return FellowProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<FellowProfile> updateMyProfile(Map<String, dynamic> patch) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>('/profile/me', data: patch);
      return FellowProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
