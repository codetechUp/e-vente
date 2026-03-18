class OrderItemModel {
  final int? id;
  final int? orderId;
  final int? productId;
  final int quantity;
  final double? price;

  const OrderItemModel({
    this.id,
    this.orderId,
    this.productId,
    this.quantity = 0,
    this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price'];

    return OrderItemModel(
      id: json['id'] as int?,
      orderId: json['order_id'] as int?,
      productId: json['product_id'] as int?,
      quantity: (json['quantity'] as int?) ?? 0,
      price: priceValue == null ? null : (priceValue as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }
}
