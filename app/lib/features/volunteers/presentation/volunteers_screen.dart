import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/volunteers/application/volunteer_controller.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

class VolunteersScreen extends ConsumerWidget {
  const VolunteersScreen({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Volunteer volunteer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('volunteers.delete_confirm_title')),
        content: Text(volunteer.fullName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('volunteers.delete_button')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(volunteerControllerProvider.notifier).delete(volunteer.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volunteersState = ref.watch(volunteerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('volunteers.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/volunteers/new'),
        icon: const Icon(Icons.add),
        label: Text(t('volunteers.add_title')),
      ),
      body: volunteersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('common.generic_error')),
          OutlinedButton(
              onPressed: () =>
                  ref.read(volunteerControllerProvider.notifier).load(),
              child: Text(t('common.retry'))),
        ])),
        data: (volunteers) {
          if (volunteers.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.groups_outlined, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(t('volunteers.empty_state')),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                          onPressed: () => context.push('/volunteers/new'),
                          icon: const Icon(Icons.add),
                          label: Text(t('volunteers.add_title'))),
                    ])));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 90),
            itemCount: volunteers.length,
            itemBuilder: (context, index) {
              final volunteer = volunteers[index];
              return Card(
                  child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                leading: CircleAvatar(
                    backgroundColor: AppColors.lime.withValues(alpha: .5),
                    foregroundColor: AppColors.primary,
                    child: Text(volunteer.fullName.isEmpty
                        ? '?'
                        : volunteer.fullName.substring(0, 1))),
                title: Text(volunteer.fullName),
                subtitle: Text(volunteer.phoneNumber),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: t('volunteers.edit_title'),
                      onPressed: () =>
                          context.push('/volunteers/${volunteer.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: t('volunteers.delete_button'),
                      onPressed: () => _confirmDelete(context, ref, volunteer),
                    ),
                  ],
                ),
              ));
            },
          );
        },
      ),
    );
  }
}
