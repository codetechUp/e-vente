class DeliveryModel {
  final int? id;
  final int? orderId;
  final String? deliveryPersonId;
  final String status;
  final DateTime? deliveredAt;

  const DeliveryModel({
    this.id,
    this.orderId,
    this.deliveryPersonId,
    this.status = 'pending',
    this.deliveredAt,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      id: json['id'] as int?,
      orderId: json['order_id'] as int?,
      deliveryPersonId: json['delivery_person_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.parse(json['delivered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'delivery_person_id': deliveryPersonId,
      'status': status,
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
    };
  }
}
