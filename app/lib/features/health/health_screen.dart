import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/health/health_service.dart';

final _healthServiceProvider = Provider((ref) => HealthService(ref.watch(apiClientProvider)));

final _healthStatusProvider = FutureProvider((ref) => ref.watch(_healthServiceProvider).fetchHealth());

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(_healthStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('health.status_title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: healthAsync.when(
            data: (health) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(t('health.status_ok'), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text('version: ${health.version}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(t('common.generic_error'), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(_healthStatusProvider),
                  child: Text(t('common.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
