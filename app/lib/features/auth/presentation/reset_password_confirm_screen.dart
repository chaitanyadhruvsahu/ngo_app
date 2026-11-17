import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

class ResetPasswordConfirmScreen extends ConsumerStatefulWidget {
  const ResetPasswordConfirmScreen({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends ConsumerState<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _success = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = t('common.generic_error'));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).confirmPasswordReset(
            token: token,
            newPassword: _passwordController.text,
          );
      if (mounted) setState(() => _success = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _success ? _buildSuccess(context) : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration:
                InputDecoration(labelText: t('auth.new_password_label')),
            validator: (value) => (value == null || value.length < 10)
                ? t('auth.password_error')
                : null,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!,
                style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('common.submit')),
          ),
        ],
      ),
    );
  }
}
