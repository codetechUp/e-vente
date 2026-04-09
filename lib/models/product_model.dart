class ProductModel {
  final int? id;
  final String name;
  final String? description;
  final double price;
  final int? categoryId;
  final String? imageUrl;
  final int stock;
  final DateTime? createdAt;

  const ProductModel({
    this.id,
    required this.name,
    this.description,
    required this.price,
    this.categoryId,
    this.imageUrl,
    this.stock = 0,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price'];
    final stockValue = json['stock'];

    return ProductModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: priceValue == null ? 0 : (priceValue as num).toDouble(),
      categoryId: json['category_id'] as int?,
      imageUrl: json['image_url'] as String?,
      stock: stockValue == null ? 0 : (stockValue as num).toInt(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'image_url': imageUrl,
      'stock': stock,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
