import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/i18n/language_menu.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandMark(),
                const SizedBox(height: 38),
                Text(ux(context, 'Welcome back.', 'फिर से स्वागत है।'),
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                    ux(context, 'A little more connected. A lot more possible.',
                        'थोड़ा और साथ। बहुत कुछ संभव।'),
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                      labelText: t('auth.email_label'),
                      prefixIcon: const Icon(Icons.alternate_email, size: 19)),
                  validator: (value) => (value == null || !value.contains('@'))
                      ? t('auth.email_error')
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                      labelText: t('auth.password_label'),
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: IconButton(
                          tooltip: ux(
                              context,
                              _showPassword ? 'Hide password' : 'Show password',
                              _showPassword
                                  ? 'पासवर्ड छिपाएँ'
                                  : 'पासवर्ड दिखाएँ'),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19))),
                  validator: (value) => (value == null || value.isEmpty)
                      ? t('auth.password_required')
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('auth.login_button')),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.push('/reset-password/request'),
                  child: Text(t('auth.forgot_password')),
                ),
                const Divider(height: AppSpacing.xl),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: Text(
                      '${t('auth.no_account_prompt')} ${t('auth.signup_button')}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
        body: Row(children: [
      if (wide)
        Expanded(
            child: Container(
                color: AppColors.primaryVariant,
                child: Stack(children: [
                  const Positioned(
                      top: 44, left: 44, child: BrandMark(light: true)),
                  if (MediaQuery.sizeOf(context).height > 700)
                    const Positioned(
                        top: 105,
                        left: 30,
                        right: 30,
                        child: Center(child: GrowthArtwork(size: 280))),
                  Positioned(
                      left: 44,
                      right: 40,
                      bottom: 65,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                ux(
                                    context,
                                    'Good people.\nMeaningful work.\nReal change.',
                                    'अच्छे लोग।\nसार्थक काम।\nअसली बदलाव।'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 45,
                                    height: 1.12,
                                    letterSpacing: -1.5,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 20),
                            Text(
                                ux(
                                    context,
                                    'A shared space for the people\nwho show up for their communities.',
                                    'समुदाय के लिए आगे आने वाले\nलोगों का साझा कार्यक्षेत्र।'),
                                style: const TextStyle(
                                    color: Color(0xFFB6CBB7),
                                    fontSize: 15,
                                    height: 1.7)),
                          ])),
                ]))),
      Expanded(
          child: Stack(children: [
        form,
        const Positioned(
            right: 20, top: 16, child: SafeArea(child: LanguageMenu()))
      ])),
    ]));
  }
}
