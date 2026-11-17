import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/features/documents/application/document_controller.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/documents/services/save_file.dart';
import 'pdf_preview.dart';

Future<void> showDocumentPreview(BuildContext context, Document document) =>
    showDialog<void>(
        context: context, builder: (_) => _DocumentPreview(document: document));

class _DocumentPreview extends ConsumerStatefulWidget {
  const _DocumentPreview({required this.document});
  final Document document;
  @override
  ConsumerState<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends ConsumerState<_DocumentPreview> {
  late Future<Uint8List> _bytes;
  bool _downloading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = ref.read(documentRepositoryProvider).preview(widget.document.id);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await ref
          .read(documentRepositoryProvider)
          .download(widget.document.id);
      saveFile(
          bytes, widget.document.originalFilename, widget.document.contentType);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ApiException
                ? error.userMessage
                : 'Could not download this document. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
          width: 1100,
          height: MediaQuery.sizeOf(context).height * .88,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.document.originalFilename,
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(
                      tooltip: 'Download',
                      onPressed: _downloading ? null : _download,
                      icon: const Icon(Icons.download_outlined)),
                  IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            const Divider(height: 1),
            Expanded(
                child: FutureBuilder<Uint8List>(
                    future: _bytes,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(snapshot.error is ApiException
                                          ? (snapshot.error as ApiException)
                                              .userMessage
                                          : 'Could not open the document.'),
                                      TextButton(
                                          onPressed: () => setState(_load),
                                          child: const Text('Try again'))
                                    ])));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (widget.document.contentType == 'application/pdf') {
                        return PdfPreview(bytes: snapshot.data!);
                      }
                      return InteractiveViewer(
                          minScale: .5,
                          maxScale: 5,
                          child: Center(
                              child: Image.memory(snapshot.data!,
                                  fit: BoxFit.contain)));
                    })),
          ])));
}
