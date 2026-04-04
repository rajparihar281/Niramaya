// ── StaffUser Model — Maps staff_users table ────────────────────────────────

class StaffUser {
  final String id;
  final String staffId;
  final String phone;
  final String? email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final bool isVerified;
  final bool isActive;

  const StaffUser({
    required this.id,
    required this.staffId,
    required this.phone,
    this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    required this.isVerified,
    required this.isActive,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id']?.toString() ?? '',
      staffId: json['staff_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'driver',
      avatarUrl: json['avatar_url']?.toString(),
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'staff_id': staffId,
        'phone': phone,
        'email': email,
        'full_name': fullName,
        'role': role,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'is_active': isActive,
      };
}
