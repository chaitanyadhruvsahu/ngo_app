import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/core/providers.dart';

final reportingRepositoryProvider =
    Provider((ref) => ReportingRepository(ref.watch(apiClientProvider)));

class ReportingRepository {
  ReportingRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? query}) async {
    try {
      return (await _api.dio
              .get<Map<String, dynamic>>(path, queryParameters: query))
          .data!;
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Map<String, dynamic>> volunteers({int? block, int page = 1}) =>
      _get('/admin/volunteers',
          query: {'page': page, if (block != null) 'block': block});
  Future<Map<String, dynamic>> history({int page = 1}) =>
      _get('/admin/exports', query: {'page': page});
  Future<Map<String, dynamic>> blocks() => _get('/admin/dashboard/blocks');
  Future<Map<String, dynamic>> fellow(String id) =>
      _get('/admin/dashboard/fellows/$id');

  Future<Uint8List> export(String type, {int? block}) async {
    try {
      final response = await _api.dio.get<List<int>>('/admin/exports/$type',
          queryParameters: {if (block != null) 'block': block},
          options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
