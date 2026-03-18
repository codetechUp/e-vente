class AppUserModel {
  final String? id;
  final String? name;
  final String email;
  final String? phone;
  final String? password;
  final int? roleId;
  final bool isActive;
  final DateTime? createdAt;

  const AppUserModel({
    this.id,
    this.name,
    required this.email,
    this.phone,
    this.password,
    this.roleId,
    this.isActive = true,
    this.createdAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      password: json['password'] as String?,
      roleId: json['role_id'] as int?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role_id': roleId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
