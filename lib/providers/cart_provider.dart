import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

class CartItem {
  final ProductModel product;
  final int quantity;
  final double effectivePrice;

  const CartItem({
    required this.product,
    required this.quantity,
    required this.effectivePrice,
  });

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
    double? effectivePrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      effectivePrice: effectivePrice ?? this.effectivePrice,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _itemsByProductId = {};

  List<CartItem> get items => _itemsByProductId.values.toList();

  int get totalItems =>
      _itemsByProductId.values.fold(0, (sum, e) => sum + e.quantity);

  double get totalPrice => _itemsByProductId.values.fold(
    0,
    (sum, e) => sum + (e.effectivePrice * e.quantity),
  );

  bool contains(ProductModel product) {
    final id = product.id;
    if (id == null) return false;
    return _itemsByProductId.containsKey(id);
  }

  void add(ProductModel product, {int quantity = 1, double? effectivePrice}) {
    final id = product.id;
    if (id == null) return;

    final price = effectivePrice ?? product.price;

    final existing = _itemsByProductId[id];
    if (existing == null) {
      _itemsByProductId[id] = CartItem(
        product: product,
        quantity: quantity,
        effectivePrice: price,
      );
    } else {
      _itemsByProductId[id] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    }

    notifyListeners();
  }

  void increment(ProductModel product) => add(product, quantity: 1);

  void decrement(ProductModel product) {
    final id = product.id;
    if (id == null) return;

    final existing = _itemsByProductId[id];
    if (existing == null) return;

    final next = existing.quantity - 1;
    if (next <= 0) {
      _itemsByProductId.remove(id);
    } else {
      _itemsByProductId[id] = existing.copyWith(quantity: next);
    }

    notifyListeners();
  }

  void remove(ProductModel product) {
    final id = product.id;
    if (id == null) return;

    _itemsByProductId.remove(id);
    notifyListeners();
  }

  void clear() {
    _itemsByProductId.clear();
    notifyListeners();
  }
}
