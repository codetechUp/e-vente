class StockEntryModel {
  final int? id;
  final int productId;
  final int quantity;
  final String entryType; // 'purchase', 'adjustment', 'return'
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  
  // Champs joints pour affichage
  final String? productName;
  final String? createdByName;

  const StockEntryModel({
    this.id,
    required this.productId,
    required this.quantity,
    this.entryType = 'purchase',
    this.notes,
    this.createdBy,
    this.createdAt,
    this.productName,
    this.createdByName,
  });

  factory StockEntryModel.fromJson(Map<String, dynamic> json) {
    return StockEntryModel(
      id: json['id'] as int?,
      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      entryType: json['entry_type'] as String? ?? 'purchase',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      productName: json['products']?['name'] as String?,
      createdByName: json['users']?['name'] as String? ?? 
                     json['users']?['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'quantity': quantity,
      'entry_type': entryType,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  StockEntryModel copyWith({
    int? id,
    int? productId,
    int? quantity,
    String? entryType,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    String? productName,
    String? createdByName,
  }) {
    return StockEntryModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      entryType: entryType ?? this.entryType,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
