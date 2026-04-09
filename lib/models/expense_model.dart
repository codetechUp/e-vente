class ExpenseModel {
  final int? id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? createdBy;
  final DateTime? createdAt;

  const ExpenseModel({
    this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.createdBy,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final amountValue = json['amount'];

    return ExpenseModel(
      id: json['id'] as int?,
      description: json['description'] as String,
      amount: amountValue == null ? 0 : (amountValue as num).toDouble(),
      category: json['category'] as String,
      date: json['date'] == null
          ? DateTime.now()
          : DateTime.parse(json['date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
