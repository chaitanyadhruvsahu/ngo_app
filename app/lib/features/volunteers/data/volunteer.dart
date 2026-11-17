class Volunteer {
  const Volunteer({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.phoneNumberRaw,
    required this.relationshipToFellow,
    required this.householdDetails,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    return Volunteer(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      phoneNumberRaw: json['phone_number_raw'] as String,
      relationshipToFellow: json['relationship_to_fellow'] as String? ?? '',
      householdDetails: json['household_details'] as String? ?? '',
    );
  }

  final String id;
  final String fullName;
  final String phoneNumber;
  final String phoneNumberRaw;
  final String relationshipToFellow;
  final String householdDetails;
}
