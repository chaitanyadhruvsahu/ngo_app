import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/features/admin/data/fellow_summary.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

/// Read-only this phase — Admin has no write endpoints for fellow
/// data/documents/volunteers yet (Phase 2 mandate §D).
class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FellowSummary>> getFellows({int? block}) async {
    try {
      final fellows = <FellowSummary>[];
      var page = 1;
      while (true) {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/admin/fellows',
          queryParameters: {'page': page, if (block != null) 'block': block},
        );
        final data = response.data!;
        fellows.addAll((data['results'] as List<dynamic>).map(
            (json) => FellowSummary.fromJson(json as Map<String, dynamic>)));
        if (data['next'] == null) return fellows;
        page++;
      }
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<FellowProfile> getFellowDetail(String fellowId) async {
    try {
      final response = await _apiClient.dio
          .get<Map<String, dynamic>>('/admin/fellows/$fellowId');
      return FellowProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<List<Document>> getFellowDocuments(String fellowId) async {
    try {
      final response = await _apiClient.dio
          .get<List<dynamic>>('/admin/fellows/$fellowId/documents');
      return response.data!
          .map((json) => Document.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<List<Volunteer>> getFellowVolunteers(String fellowId) async {
    try {
      final response = await _apiClient.dio
          .get<List<dynamic>>('/admin/fellows/$fellowId/volunteers');
      return response.data!
          .map((json) => Volunteer.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  /// Downloads still go through the shared endpoint with Admin-scoped
  /// permission (Phase 2 mandate §H) — reuse `DocumentRepository.download`
  /// rather than duplicating it; see `AdminFellowDocumentsTab`.
}
