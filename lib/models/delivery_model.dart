class DeliveryModel {
  final int? id;
  final int? orderId;
  final String? deliveryPersonId;
  final String status;
  final DateTime? deliveredAt;
  final String? deliveryAddress;
  final double? totalPrice;
  final List<Map<String, dynamic>>? orderItems;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

  const DeliveryModel({
    this.id,
    this.orderId,
    this.deliveryPersonId,
    this.status = 'pending',
    this.deliveredAt,
    this.deliveryAddress,
    this.totalPrice,
    this.orderItems,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    final totalPrice = json['total_price'];
    List<Map<String, dynamic>>? items;
    if (json['order_items'] != null) {
      items = (json['order_items'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    return DeliveryModel(
      id: json['id'] as int?,
      orderId: json['order_id'] as int?,
      deliveryPersonId: json['delivery_person_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.parse(json['delivered_at'] as String),
      deliveryAddress: json['delivery_address'] as String?,
      totalPrice: totalPrice == null ? null : (totalPrice as num).toDouble(),
      orderItems: items,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
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
