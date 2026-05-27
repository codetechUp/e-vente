class InvoiceModel {
  final String? id;
  final int orderId;
  final String invoiceNumber;
  final DateTime? createdAt;
  final String? createdBy;

  const InvoiceModel({
    this.id,
    required this.orderId,
    required this.invoiceNumber,
    this.createdAt,
    this.createdBy,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String?,
      orderId: json['order_id'] as int,
      invoiceNumber: json['invoice_number'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'invoice_number': invoiceNumber,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
