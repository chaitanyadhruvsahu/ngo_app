import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/responsive_widgets.dart';
import 'package:ngo_app/features/documents/application/document_controller.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/documents/services/save_file.dart';
import 'package:ngo_app/features/documents/presentation/document_preview.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _selectedType = Document.types.first;
  bool _isUploading = false;
  PlatformFile? _selectedFile;
  String? _errorMessage;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      setState(() {
        _selectedFile =
            file.size <= 10 * 1024 * 1024 && file.bytes != null ? file : null;
        _errorMessage = file.size > 10 * 1024 * 1024
            ? t('documents.file_too_large')
            : file.bytes == null
                ? t('documents.file_unavailable')
                : null;
      });
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t('documents.pick_error'));
    }
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null || file.bytes == null || _isUploading) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(documentControllerProvider.notifier).upload(
            type: _selectedType,
            bytes: file.bytes!,
            filename: file.name,
          );
      if (mounted) {
        setState(() => _selectedFile = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('documents.upload_success'))),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = t('documents.upload_error'));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _download(Document document) async {
    try {
      final bytes = await ref
          .read(documentControllerProvider.notifier)
          .download(document.id);
      saveFile(bytes, document.originalFilename, document.contentType);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsState = ref.watch(documentControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('documents.title'))),
      body: PageContent(
          maxWidth: 760,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('documents.upload_heading'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(t('documents.upload_hint')),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration:
                          InputDecoration(labelText: t('documents.type_label')),
                      items: Document.types
                          .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(t('documents.type.$type'))))
                          .toList(),
                      onChanged: _isUploading
                          ? null
                          : (value) => setState(() => _selectedType = value!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 108),
                          backgroundColor: const Color(0xFFEAF0E3)),
                      onPressed: _isUploading ? null : _pickFile,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 28),
                      label: Text(_selectedFile == null
                          ? t('documents.choose_file')
                          : t('documents.change_file')),
                    ),
                    if (_selectedFile != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(children: [
                          const Icon(Icons.insert_drive_file_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: Text(
                                  '${_selectedFile!.name} · ${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                              onPressed: _isUploading
                                  ? null
                                  : () => setState(() => _selectedFile = null),
                              tooltip: t('documents.remove_file'),
                              icon: const Icon(Icons.close)),
                        ]),
                      ),
                    if (_selectedFile?.bytes != null &&
                        ['jpg', 'jpeg', 'png']
                            .contains(_selectedFile!.extension?.toLowerCase()))
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(_selectedFile!.bytes!,
                                  height: 150,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stack) =>
                                      const SizedBox.shrink()))),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _isUploading || _selectedFile == null
                          ? null
                          : _upload,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t('documents.upload_button')),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.error)),
                ),
              const Divider(height: AppSpacing.lg),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(t('documents.your_documents'),
                          style: Theme.of(context).textTheme.titleLarge))),
              documentsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('common.generic_error')),
                  OutlinedButton(
                      onPressed: () =>
                          ref.read(documentControllerProvider.notifier).load(),
                      child: Text(t('common.retry'))),
                ])),
                data: (documents) {
                  if (documents.isEmpty) {
                    return Center(child: Text(t('documents.empty_state')));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      return Card(
                          child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(t('documents.type.${document.type}')),
                        subtitle: Text(document.originalFilename),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'View document',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () =>
                                  showDocumentPreview(context, document)),
                          IconButton(
                              tooltip: 'Download',
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () => _download(document)),
                        ]),
                        onTap: () => showDocumentPreview(context, document),
                      ));
                    },
                  );
                },
              ),
            ],
          )),
    );
  }
}
