class MedicationModel {
  final String? id;
  final String userId;
  final String medName;
  final String? dosage;
  final String? usage;
  final String? precautions;
  final DateTime? scannedAt;

  const MedicationModel({
    this.id,
    required this.userId,
    required this.medName,
    this.dosage,
    this.usage,
    this.precautions,
    this.scannedAt,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '', // Default for local parsing
      medName: json['med_name'] ?? json['name'] as String? ?? 'Unknown Medicine',
      dosage: json['dosage'] as String?,
      usage: json['usage'] as String?,
      precautions: json['precautions'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'med_name': medName,
      if (dosage != null) 'dosage': dosage,
      if (usage != null) 'usage': usage,
      if (precautions != null) 'precautions': precautions,
      if (scannedAt != null) 'scanned_at': scannedAt?.toIso8601String(),
    };
  }
}
