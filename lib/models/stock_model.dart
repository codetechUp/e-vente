class StockModel {
  final int? id;
  final int? productId;
  final int quantity;
  final DateTime? updatedAt;

  const StockModel({
    this.id,
    this.productId,
    this.quantity = 0,
    this.updatedAt,
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      id: json['id'] as int?,
      productId: json['product_id'] as int?,
      quantity: (json['quantity'] as int?) ?? 0,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'quantity': quantity,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
