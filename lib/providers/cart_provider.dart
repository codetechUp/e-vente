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

  int getProductQuantity(int? productId) {
    if (productId == null) return 0;
    return _itemsByProductId[productId]?.quantity ?? 0;
  }

  void add(ProductModel product, {int quantity = 1, double? effectivePrice}) {
    final id = product.id;
    if (id == null) return;

    final price = effectivePrice ?? product.price;
    final maxQty = product.stock; // never exceed available stock

    final existing = _itemsByProductId[id];
    if (existing == null) {
      final newQty = quantity.clamp(0, maxQty);
      if (newQty <= 0) return;
      _itemsByProductId[id] = CartItem(
        product: product,
        quantity: newQty,
        effectivePrice: price,
      );
    } else {
      final newQty = (existing.quantity + quantity).clamp(0, maxQty);
      if (newQty <= 0) {
        _itemsByProductId.remove(id);
      } else {
        _itemsByProductId[id] = existing.copyWith(quantity: newQty);
      }
    }

    notifyListeners();
  }

  void increment(ProductModel product) => add(product, quantity: 1);

  void setQuantity(ProductModel product, int quantity, {double? effectivePrice}) {
    final id = product.id;
    if (id == null) return;

    final clampedQty = quantity.clamp(0, product.stock);
    if (clampedQty <= 0) {
      _itemsByProductId.remove(id);
    } else {
      final price = effectivePrice ?? product.price;
      final existing = _itemsByProductId[id];
      _itemsByProductId[id] = CartItem(
        product: product,
        quantity: clampedQty,
        effectivePrice: existing?.effectivePrice ?? price,
      );
    }

    notifyListeners();
  }

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
