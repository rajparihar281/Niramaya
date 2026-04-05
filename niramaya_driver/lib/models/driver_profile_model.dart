// ── DriverProfile Model — unified public.drivers table ───────────────────────

class DriverProfile {
  final String id;
  final String staffId;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? licenseNumber;
  final int yearsExperience;
  final double rating;
  final bool isOnDuty;
  final bool isVerified;
  final bool isActive;
  final String? bloodGroup;
  final String? ambulanceId;
  final String? hospitalId;
  final String role;

  const DriverProfile({
    required this.id,
    required this.staffId,
    this.fullName,
    this.phone,
    this.email,
    this.licenseNumber,
    this.yearsExperience = 0,
    this.rating = 5.0,
    this.isOnDuty = false,
    this.isVerified = false,
    this.isActive = true,
    this.bloodGroup,
    this.ambulanceId,
    this.hospitalId,
    this.role = 'driver',
  });

  factory DriverProfile.fromDrivers(Map<String, dynamic> d) {
    return DriverProfile(
      id: d['id']?.toString() ?? '',
      staffId: d['staff_id']?.toString() ?? '',
      fullName: d['full_name']?.toString(),
      phone: d['phone']?.toString(),
      email: d['email']?.toString(),
      licenseNumber: d['license_number']?.toString(),
      yearsExperience: _parseInt(d['years_experience']),
      rating: _parseDouble(d['rating']),
      isOnDuty: d['is_on_duty'] == true,
      isVerified: d['is_verified'] == true,
      isActive: d['is_active'] != false,
      bloodGroup: d['blood_group']?.toString(),
      ambulanceId: d['ambulance_id']?.toString(),
      hospitalId: d['hospital_id']?.toString(),
      role: d['role']?.toString() ?? 'driver',
    );
  }

  DriverProfile copyWith({
    bool? isOnDuty,
    bool? isVerified,
    bool? isActive,
    String? bloodGroup,
    double? rating,
    String? licenseNumber,
    int? yearsExperience,
    String? ambulanceId,
    String? hospitalId,
    String? fullName,
    String? phone,
  }) {
    return DriverProfile(
      id: id,
      staffId: staffId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      rating: rating ?? this.rating,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      hospitalId: hospitalId ?? this.hospitalId,
      role: role,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 5.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 5.0;
  }
}
