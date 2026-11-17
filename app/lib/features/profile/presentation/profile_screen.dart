import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/profile/application/profile_controller.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';

/// A fellow's own profile — the single authorized full-detail view on this
/// side (Phase 2 mandate, Definition of Done): includes Aadhaar/bank
/// fields, which no other screen in this app ever shows.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _address = TextEditingController();
  final _aadhaarNumber = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _bankAccountHolderName = TextEditingController();
  DateTime? _dateOfBirth;
  String? _selectedBlockId;

  bool _loadedOnce = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullName.dispose();
    _phoneNumber.dispose();
    _address.dispose();
    _aadhaarNumber.dispose();
    _bankAccountNumber.dispose();
    _bankIfsc.dispose();
    _bankAccountHolderName.dispose();
    super.dispose();
  }

  void _populateFrom(FellowProfile profile) {
    _fullName.text = profile.fullName;
    _phoneNumber.text = profile.phoneNumber;
    _address.text = profile.address;
    _aadhaarNumber.text = profile.aadhaarNumber;
    _bankAccountNumber.text = profile.bankAccountNumber;
    _bankIfsc.text = profile.bankIfsc;
    _bankAccountHolderName.text = profile.bankAccountHolderName;
    _dateOfBirth = profile.dateOfBirth != null
        ? DateTime.tryParse(profile.dateOfBirth!)
        : null;
    _selectedBlockId = profile.block;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await ref.read(profileControllerProvider.notifier).update({
        'full_name': _fullName.text.trim(),
        'block': _selectedBlockId,
        if (_dateOfBirth != null)
          'date_of_birth': DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
        'phone_number': _phoneNumber.text.trim(),
        'address': _address.text.trim(),
        'aadhaar_number': _aadhaarNumber.text.trim(),
        'bank_account_number': _bankAccountNumber.text.trim(),
        'bank_ifsc': _bankIfsc.text.trim(),
        'bank_account_holder_name': _bankAccountHolderName.text.trim(),
      });
      if (mounted) setState(() => _successMessage = t('profile.save_success'));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile.title'))),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('common.generic_error')),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(profileControllerProvider.notifier).load(),
                  child: Text(t('common.retry')),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (!_loadedOnce) {
            _populateFrom(profile);
            _loadedOnce = true;
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t('profile.basic_section_title'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(profile.email,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.lg),
                      _BlockDropdown(
                        selectedBlockId: _selectedBlockId,
                        onChanged: (value) =>
                            setState(() => _selectedBlockId = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _fullName,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                            labelText: t('profile.full_name_label')),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? t('profile.required_field')
                                : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: _pickDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: t('profile.date_of_birth_label')),
                          child: Text(
                            _dateOfBirth != null
                                ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
                                : t('profile.select_date'),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _phoneNumber,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                            labelText: t('profile.phone_number_label')),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? t('profile.required_field')
                                : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _address,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: t('profile.address_label')),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? t('profile.required_field')
                                : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(t('profile.sensitive_section_title'),
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        t('profile.sensitive_section_subtitle'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _aadhaarNumber,
                        decoration: InputDecoration(
                            labelText: t('profile.aadhaar_number_label')),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bankAccountNumber,
                        decoration: InputDecoration(
                            labelText: t('profile.bank_account_number_label')),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bankIfsc,
                        decoration: InputDecoration(
                            labelText: t('profile.bank_ifsc_label')),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bankAccountHolderName,
                        decoration: InputDecoration(
                            labelText:
                                t('profile.bank_account_holder_name_label')),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_errorMessage!,
                            style: const TextStyle(color: AppColors.error)),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_successMessage!,
                            style: const TextStyle(color: AppColors.primary)),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(t('profile.save_button')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lets a fellow pick their own block — no admin-assignment UI exists yet
/// (Phase 2 mandate pass 3, §3: fellow-picks-at-onboarding is the default
/// pending the NGO's actual answer).
class _BlockDropdown extends ConsumerWidget {
  const _BlockDropdown(
      {required this.selectedBlockId, required this.onChanged});

  final String? selectedBlockId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(blocksProvider);
    return blocksAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(t('common.generic_error')),
      data: (blocks) {
        // The profile's current block might not be in the list yet on a
        // slow first load — guard against a DropdownButton value that
        // isn't one of its items, which throws.
        final value = blocks.any((block) => block.id == selectedBlockId)
            ? selectedBlockId
            : null;
        return DropdownButtonFormField<String?>(
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
              labelText: t('profile.block_label'),
              helperText: selectedBlockId != null && value == null
                  ? t('reports.legacy_block_note')
                  : null,
              helperMaxLines: 3),
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text(t('profile.block_none'))),
            for (final block in blocks)
              DropdownMenuItem<String?>(
                  value: block.id,
                  child: Text(t('reports.block_number',
                      args: {'number': '${block.number}'}))),
          ],
          validator: (_) => selectedBlockId != null &&
                  !blocks.any((block) => block.id == selectedBlockId)
              ? t('reports.choose_canonical')
              : null,
          onChanged: onChanged,
        );
      },
    );
  }
}
