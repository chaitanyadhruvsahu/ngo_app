import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

/// Landing page for the verification link emailed by the backend
/// (`/verify-email?token=...`). Calls the API as soon as the token is
/// available and shows the result.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _VerifyState { verifying, success, failure, missingToken }

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _VerifyState _state = _VerifyState.verifying;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token == null || token.isEmpty) {
      _state = _VerifyState.missingToken;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(token));
    }
  }

  Future<void> _verify(String token) async {
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(token);
      if (mounted) setState(() => _state = _VerifyState.success);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _state = _VerifyState.failure;
          _errorMessage = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('auth.verify_email_title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _VerifyState.verifying:
        return const CircularProgressIndicator();
      case _VerifyState.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(t('auth.verify_email_title'), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: Text(t('auth.login_title')),
            ),
          ],
        );
      case _VerifyState.failure:
      case _VerifyState.missingToken:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage ?? t('common.generic_error'), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: Text(t('auth.login_title')),
            ),
          ],
        );
    }
  }
}
