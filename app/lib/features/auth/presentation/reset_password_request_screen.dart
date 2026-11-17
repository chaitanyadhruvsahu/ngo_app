import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

class ResetPasswordRequestScreen extends ConsumerStatefulWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  ConsumerState<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends ConsumerState<ResetPasswordRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _submitted = true);
    } on ApiException {
      // The request endpoint is deliberately generic — treat any response
      // (including an error) as "an email may have been sent" to avoid
      // leaking account existence through error handling differences.
      if (mounted) setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('auth.reset_password_title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _submitted ? _buildConfirmation(context) : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: AppColors.primary),
        const SizedBox(height: AppSpacing.md),
        Text(t('auth.verify_email_pending'), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
            onPressed: () => context.go('/login'),
            child: Text(t('auth.login_title'))),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: t('auth.email_label')),
            validator: (value) => (value == null || !value.contains('@'))
                ? t('auth.email_error')
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('auth.send_reset_link_button')),
          ),
        ],
      ),
    );
  }
}
