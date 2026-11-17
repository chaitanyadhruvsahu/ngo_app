import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/documents/data/document_repository.dart';

final documentRepositoryProvider =
    Provider((ref) => DocumentRepository(ref.watch(apiClientProvider)));

final documentControllerProvider =
    StateNotifierProvider<DocumentController, AsyncValue<List<Document>>>(
        (ref) {
  final controller = DocumentController(ref.watch(documentRepositoryProvider));
  controller.load();
  return controller;
});

class DocumentController extends StateNotifier<AsyncValue<List<Document>>> {
  DocumentController(this._repository) : super(const AsyncValue.loading());

  final DocumentRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.getMyDocuments());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> upload(
      {required String type,
      required Uint8List bytes,
      required String filename}) async {
    await _repository.upload(type: type, bytes: bytes, filename: filename);
    await load(); // re-fetch so a superseded previous document drops out of the list
  }

  Future<Uint8List> download(String documentId) =>
      _repository.download(documentId);
}
