class OrderModel {
  final int? id;
  final String? userId;
  final String status;
  final double? totalPrice;
  final String? deliveryAddress;
  final DateTime? createdAt;

  const OrderModel({
    this.id,
    this.userId,
    this.status = 'pending',
    this.totalPrice,
    this.deliveryAddress,
    this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final total = json['total_price'];

    return OrderModel(
      id: json['id'] as int?,
      userId: json['user_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      totalPrice: total == null ? null : (total as num).toDouble(),
      deliveryAddress: json['delivery_address'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
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
    };
  }
}
