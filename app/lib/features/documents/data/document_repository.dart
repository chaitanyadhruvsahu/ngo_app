import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:ngo_app/core/api/api_client.dart';
import 'package:ngo_app/features/documents/data/document.dart';

class DocumentRepository {
  DocumentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Document>> getMyDocuments() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>('/documents/');
      return response.data!
          .map((json) => Document.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Document> upload({
    required String type,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'type': type,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _apiClient.dio
          .post<Map<String, dynamic>>('/documents/', data: form);
      return Document.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }

  Future<Uint8List> preview(String documentId) => _read(documentId, 'preview');

  Future<Uint8List> download(String documentId) =>
      _read(documentId, 'download');

  Future<Uint8List> _read(String documentId, String action) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/documents/$documentId/$action',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiClient.toApiException(error);
    }
  }
}
