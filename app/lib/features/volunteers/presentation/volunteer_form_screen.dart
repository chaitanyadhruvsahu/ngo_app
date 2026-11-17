import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/volunteers/application/volunteer_controller.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

/// Add/edit in one screen — `volunteerId` is null for "new".
class VolunteerFormScreen extends ConsumerStatefulWidget {
  const VolunteerFormScreen({super.key, this.volunteerId});

  final String? volunteerId;

  @override
  ConsumerState<VolunteerFormScreen> createState() => _VolunteerFormScreenState();
}

class _VolunteerFormScreenState extends ConsumerState<VolunteerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _relationshipToFellow = TextEditingController();
  final _householdDetails = TextEditingController();

  bool _prefilled = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.volunteerId != null;

  @override
  void dispose() {
    _fullName.dispose();
    _phoneNumber.dispose();
    _relationshipToFellow.dispose();
    _householdDetails.dispose();
    super.dispose();
  }

  void _prefillFrom(Volunteer volunteer) {
    _fullName.text = volunteer.fullName;
    _phoneNumber.text = volunteer.phoneNumberRaw;
    _relationshipToFellow.text = volunteer.relationshipToFellow;
    _householdDetails.text = volunteer.householdDetails;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final data = {
      'full_name': _fullName.text.trim(),
      'phone_number': _phoneNumber.text.trim(),
      'relationship_to_fellow': _relationshipToFellow.text.trim(),
      'household_details': _householdDetails.text.trim(),
    };
    try {
      final notifier = ref.read(volunteerControllerProvider.notifier);
      if (_isEditing) {
        await notifier.update(widget.volunteerId!, data);
      } else {
        await notifier.create(data);
      }
      if (mounted) context.pop();
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.userMessage);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && !_prefilled) {
      final volunteers = ref.read(volunteerControllerProvider).valueOrNull ?? const [];
      for (final volunteer in volunteers) {
        if (volunteer.id == widget.volunteerId) {
          _prefillFrom(volunteer);
          _prefilled = true;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? t('volunteers.edit_title') : t('volunteers.add_title')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: InputDecoration(labelText: t('volunteers.full_name_label')),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? t('profile.required_field') : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneNumber,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: t('volunteers.phone_number_label')),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? t('profile.required_field') : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _relationshipToFellow,
                    decoration: InputDecoration(labelText: t('volunteers.relationship_label')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _householdDetails,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: t('volunteers.household_details_label')),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('common.submit')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
