import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

/// Empty Admin shell for Phase 1 — real dashboards arrive in a later
/// phase. Its only job right now is to prove role-based routing works.
class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t('auth.logout_button'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: const Center(child: Text('Admin shell — dashboards arrive in a later phase.')),
    );
  }
}
