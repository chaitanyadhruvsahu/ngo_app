/// Mirrors the backend's `FellowProfileListSerializer` — deliberately
/// excludes Aadhaar/bank fields (Phase 2 mandate: sensitive fields never
/// appear outside the single authorized detail view).
class FellowSummary {
  const FellowSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.onboardingStep,
  });

  factory FellowSummary.fromJson(Map<String, dynamic> json) {
    return FellowSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      onboardingStep: json['onboarding_step'] as String,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String onboardingStep;
}
