/// Mirrors the backend's `FellowProfileDetailSerializer` (own profile /
/// `GET /profile/me`, and Admin's `GET /admin/fellows/{id}`). `block` is a
/// fellow-editable FK (id of a [Block]) — see `GET /api/v1/blocks` and
/// ADR/mandate pass 3 §3: fellow-picks-at-onboarding is the default
/// pending the NGO's actual answer on block assignment.
class FellowProfile {
  const FellowProfile({
    required this.id,
    required this.email,
    required this.block,
    required this.onboardingStep,
    required this.fullName,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.address,
    required this.aadhaarNumber,
    required this.bankAccountNumber,
    required this.bankIfsc,
    required this.bankAccountHolderName,
    required this.consentGivenAt,
  });

  factory FellowProfile.fromJson(Map<String, dynamic> json) {
    return FellowProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      block: json['block'] as String?,
      onboardingStep: json['onboarding_step'] as String,
      fullName: json['full_name'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String?,
      phoneNumber: json['phone_number'] as String? ?? '',
      address: json['address'] as String? ?? '',
      aadhaarNumber: json['aadhaar_number'] as String? ?? '',
      bankAccountNumber: json['bank_account_number'] as String? ?? '',
      bankIfsc: json['bank_ifsc'] as String? ?? '',
      bankAccountHolderName: json['bank_account_holder_name'] as String? ?? '',
      consentGivenAt: json['consent_given_at'] as String?,
    );
  }

  final String id;
  final String email;
  final String? block;
  final String onboardingStep;
  final String fullName;
  final String? dateOfBirth; // ISO 8601 date (yyyy-MM-dd), or null
  final String phoneNumber;
  final String address;
  final String aadhaarNumber;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankAccountHolderName;
  final String? consentGivenAt;

  bool get isComplete =>
      fullName.isNotEmpty && dateOfBirth != null && phoneNumber.isNotEmpty && address.isNotEmpty;
}
