class ProductModel {
  final int? id;
  final String name;
  final String? description;
  final double price;
  final String? grille;
  final int? categoryId;
  final String? imageUrl;
  final int stock;
  final bool display;
  final DateTime? createdAt;

  const ProductModel({
    this.id,
    required this.name,
    this.description,
    required this.price,
    this.grille,
    this.categoryId,
    this.imageUrl,
    this.stock = 0,
    this.display = true,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price'];
    final stockValue = json['stock'];
    final displayValue = json['display'];

    return ProductModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: priceValue == null ? 0 : (priceValue as num).toDouble(),
      grille: json['grille']?.toString(),
      categoryId: json['category_id'] as int?,
      imageUrl: json['image_url'] as String?,
      stock: stockValue == null ? 0 : (stockValue as num).toInt(),
      display: displayValue == null ? true : (displayValue as bool),
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
      'grille': grille,
      'category_id': categoryId,
      'image_url': imageUrl,
      'stock': stock,
      'display': display,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
