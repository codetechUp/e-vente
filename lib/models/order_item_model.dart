class OrderItemModel {
  final int? id;
  final int? orderId;
  final int? productId;
  final int quantity;
  final double? price;
  final String? productName;

  const OrderItemModel({
    this.id,
    this.orderId,
    this.productId,
    this.quantity = 0,
    this.price,
    this.productName,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price'];
    final products = json['products'];
    String? productName;
    if (products is Map<String, dynamic>) {
      productName = products['name'] as String?;
    }

    return OrderItemModel(
      id: json['id'] as int?,
      orderId: json['order_id'] as int?,
      productId: json['product_id'] as int?,
      quantity: (json['quantity'] as int?) ?? 0,
      price: priceValue == null ? null : (priceValue as num).toDouble(),
      productName: productName,
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
