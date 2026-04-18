class OrderModel {
  final int? id;
  final String? userId;
  final String status;
  final double? totalPrice;
  final String? deliveryAddress;
  final DateTime? createdAt;
  final DateTime? desiredDeliveryDate;
  final String? assignedLivreurId;
  final String? assignedLivreurName;

  // Informations utilisateur jointes
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userNom;
  final String? userAdresse;

  const OrderModel({
    this.id,
    this.userId,
    this.status = 'pending',
    this.totalPrice,
    this.deliveryAddress,
    this.createdAt,
    this.desiredDeliveryDate,
    this.assignedLivreurId,
    this.assignedLivreurName,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userNom,
    this.userAdresse,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final total = json['total_price'];
    // Parse client info from users (orders_user_id_fkey relation)
    final user = json['users'] as Map<String, dynamic>?;
    // Parse livreur info from livreur alias (orders_assigned_livreur_id_fkey relation)
    final livreur = json['livreur'] as Map<String, dynamic>?;
    return OrderModel(
      id: json['id'] as int?,
      userId: json['user_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      totalPrice: total == null ? null : (total as num).toDouble(),
      deliveryAddress: json['delivery_address'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      desiredDeliveryDate: json['desired_delivery_date'] == null
          ? null
          : DateTime.parse(json['desired_delivery_date'] as String),
      assignedLivreurId: json['assigned_livreur_id'] as String?,
      assignedLivreurName: livreur?['name'] as String?,
      userName: user?['name'] as String?,
      userEmail: user?['email'] as String?,
      userPhone: user?['phone'] as String?,
      userNom: user?['nom'] as String?,
      userAdresse: user?['adresse'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'status': status,
      'total_price': totalPrice,
      'delivery_address': deliveryAddress,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (desiredDeliveryDate != null)
        'desired_delivery_date': desiredDeliveryDate!.toIso8601String(),
      if (assignedLivreurId != null) 'assigned_livreur_id': assignedLivreurId,
    };
  }
}
