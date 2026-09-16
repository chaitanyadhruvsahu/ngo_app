import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

/// The onboarding *shell* — steps and progress state only. Phase 2 hangs
/// the real profile forms off this; it deliberately has no profile fields
/// of its own yet.
class OnboardingShellScreen extends ConsumerWidget {
  const OnboardingShellScreen({super.key});

  static const _steps = [
    'onboarding.step_account_created',
    'onboarding.step_email_verified',
    'onboarding.step_profile_pending',
    'onboarding.step_active',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('onboarding.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t('auth.logout_button'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView.separated(
          itemCount: _steps.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(t(_steps[index])),
            ),
          ),
        ),
      ),
    );
  }
}
