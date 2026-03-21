import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

class CartItem {
  final ProductModel product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  CartItem copyWith({ProductModel? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _itemsByProductId = {};

  List<CartItem> get items => _itemsByProductId.values.toList();

  int get totalItems => _itemsByProductId.values.fold(0, (sum, e) => sum + e.quantity);

  double get totalPrice => _itemsByProductId.values.fold(
        0,
        (sum, e) => sum + (e.product.price * e.quantity),
      );

  bool contains(ProductModel product) {
    final id = product.id;
    if (id == null) return false;
    return _itemsByProductId.containsKey(id);
  }

  void add(ProductModel product, {int quantity = 1}) {
    final id = product.id;
    if (id == null) return;

    final existing = _itemsByProductId[id];
    if (existing == null) {
      _itemsByProductId[id] = CartItem(product: product, quantity: quantity);
    } else {
      _itemsByProductId[id] = existing.copyWith(quantity: existing.quantity + quantity);
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
