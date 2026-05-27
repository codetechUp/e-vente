class AppUserModel {
  final String? id;
  final String? name;
  final String email;
  final String? phone;
  final String? password;
  final int? roleId;
  final bool isActive;
  final DateTime? createdAt;
  final String? nom;
  final String? adresse;
  final String? referrerId;
  final double? latitude;
  final double? longitude;

  const AppUserModel({
    this.id,
    this.name,
    this.email = '',
    this.phone,
    this.password,
    this.roleId,
    this.isActive = true,
    this.createdAt,
    this.nom,
    this.adresse,
    this.referrerId,
    this.latitude,
    this.longitude,
  });

  String get avatarLetter {
    if (name != null && name!.trim().isNotEmpty) return name!.trim()[0].toUpperCase();
    if (nom != null && nom!.trim().isNotEmpty) return nom!.trim()[0].toUpperCase();
    if (email.trim().isNotEmpty) return email.trim()[0].toUpperCase();
    if (phone != null && phone!.trim().isNotEmpty) {
      final p = phone!.replaceAll('+221', '').trim();
      if (p.isNotEmpty) return p[0].toUpperCase();
    }
    return '?';
  }

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      password: json['password'] as String?,
      roleId: json['role_id'] as int?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      nom: json['nom'] as String?,
      adresse: json['adresse'] as String?,
      referrerId: json['referrer_id'] as String?,
      latitude: json['latitude'] == null ? null : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null ? null : (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email.trim().isEmpty ? null : email.trim(),
      'phone': phone,
      'password': password,
      'role_id': roleId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'nom': nom,
      'adresse': adresse,
      'referrer_id': referrerId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
