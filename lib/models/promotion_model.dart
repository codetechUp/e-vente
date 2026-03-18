class PromotionModel {
  final int? id;
  final int? productId;
  final int? discountPercent;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  const PromotionModel({
    this.id,
    this.productId,
    this.discountPercent,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'] as int?,
      productId: json['product_id'] as int?,
      discountPercent: json['discount_percent'] as int?,
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'discount_percent': discountPercent,
      if (startDate != null)
        'start_date': startDate!.toIso8601String().split('T').first,
      if (endDate != null)
        'end_date': endDate!.toIso8601String().split('T').first,
      'is_active': isActive,
    };
  }
}
