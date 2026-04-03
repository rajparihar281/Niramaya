class UserModel {
  final String id;
  final String abhaId;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.id,
    required this.abhaId,
    this.phone,
    this.email,
    this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      abhaId: json['abha_id'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'abha_id': abhaId,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }
}
