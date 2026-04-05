class PatientRecord {
  final String? id;
  final String userId;
  final String? fullName;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String? allergies;
  final String? existingConditions;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool consentGiven;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientRecord({
    this.id,
    required this.userId,
    this.fullName,
    this.age,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.existingConditions,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.consentGiven = false,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      allergies: json['allergies'] as String?,
      existingConditions: json['existing_conditions'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      consentGiven: json['consent_given'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (fullName != null) 'full_name': fullName,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (allergies != null) 'allergies': allergies,
      if (existingConditions != null) 'existing_conditions': existingConditions,
      if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
      if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
      'consent_given': consentGiven,
    };
  }

  PatientRecord copyWith({
    String? id,
    String? userId,
    String? fullName,
    int? age,
    String? gender,
    String? bloodGroup,
    String? allergies,
    String? existingConditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? consentGiven,
  }) {
    return PatientRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      existingConditions: existingConditions ?? this.existingConditions,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      consentGiven: consentGiven ?? this.consentGiven,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
