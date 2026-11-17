import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/admin/application/admin_providers.dart';
import 'package:ngo_app/features/documents/application/document_controller.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/documents/services/save_file.dart';
import 'package:ngo_app/features/documents/presentation/document_preview.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';
import 'package:ngo_app/features/profile/application/profile_controller.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

/// Read-only — the other single authorized detail view (alongside a
/// fellow's own `/profile/me`) that's allowed to show decrypted
/// Aadhaar/bank values (Phase 2 mandate, Definition of Done).
class AdminFellowDetailScreen extends ConsumerWidget {
  const AdminFellowDetailScreen({super.key, required this.fellowId});

  final String fellowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fellowDetailProvider(fellowId));

    return Scaffold(
      appBar: AppBar(title: Text(t('admin.fellow_detail_title'))),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(t('common.generic_error'))),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileSection(profile: profile),
            const SizedBox(height: AppSpacing.xl),
            Text(t('documents.title'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _DocumentsSection(fellowId: fellowId),
            const SizedBox(height: AppSpacing.xl),
            Text(t('volunteers.title'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _VolunteersSection(fellowId: fellowId),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection({required this.profile});

  final FellowProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(blocksProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.fullName.isNotEmpty
                  ? profile.fullName
                  : t('admin.no_name_yet'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _field(t('profile.phone_number_label'), profile.phoneNumber),
            _field(t('profile.address_label'), profile.address),
            _field(
                t('profile.block_label'),
                blocks.when(
                  data: (items) =>
                      items
                          .where((b) => b.id == profile.block)
                          .firstOrNull
                          ?.name ??
                      '—',
                  loading: () => t('common.loading'),
                  error: (error, stack) => t('common.generic_error'),
                )),
            _field(
                t('profile.date_of_birth_label'), profile.dateOfBirth ?? '—'),
            const Divider(height: AppSpacing.lg),
            _field(t('profile.aadhaar_number_label'), profile.aadhaarNumber),
            _field(t('profile.bank_account_number_label'),
                profile.bankAccountNumber),
            _field(t('profile.bank_ifsc_label'), profile.bankIfsc),
            _field(t('profile.bank_account_holder_name_label'),
                profile.bankAccountHolderName),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              Text(value.isEmpty ? '—' : value),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 180,
                child: Text(label,
                    style: const TextStyle(color: AppColors.muted))),
            Expanded(child: Text(value.isEmpty ? '—' : value)),
          ],
        );
      }),
    );
  }
}

class _DocumentsSection extends ConsumerWidget {
  const _DocumentsSection({required this.fellowId});

  final String fellowId;

  Future<void> _download(
      BuildContext context, WidgetRef ref, Document document) async {
    try {
      final bytes = await ref
          .read(documentControllerProvider.notifier)
          .download(document.id);
      saveFile(bytes, document.originalFilename, document.contentType);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(fellowDocumentsProvider(fellowId));
    return documentsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(t('common.generic_error')),
      data: (documents) {
        if (documents.isEmpty) return Text(t('documents.empty_state'));
        return Column(
          children: documents
              .map(
                (document) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(t('documents.type.${document.type}')),
                  subtitle: Text(document.originalFilename),
                  onTap: () => showDocumentPreview(context, document),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'View document', icon: const Icon(Icons.visibility_outlined), onPressed: () => showDocumentPreview(context, document)),
                  IconButton(
                    tooltip: t('documents.download_button'),
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _download(context, ref, document),
                  )]),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _VolunteersSection extends ConsumerWidget {
  const _VolunteersSection({required this.fellowId});

  final String fellowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volunteersAsync = ref.watch(fellowVolunteersProvider(fellowId));
    return volunteersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(t('common.generic_error')),
      data: (List<Volunteer> volunteers) {
        if (volunteers.isEmpty) return Text(t('volunteers.empty_state'));
        return Column(
          children: volunteers
              .map(
                (volunteer) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(volunteer.fullName),
                  subtitle: Text(volunteer.phoneNumber),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
