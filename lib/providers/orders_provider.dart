import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../services/orders_service.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersService _ordersService;

  List<OrderModel> _orders = [];
  bool _loading = false;
  String? _error;

  OrdersProvider({OrdersService? ordersService})
    : _ordersService = ordersService ?? OrdersService() {
    loadOrders();
  }

  List<OrderModel> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;

  List<OrderModel> get pendingOrders =>
      _orders.where((o) => o.status == 'pending').toList();

  int get pendingOrdersCount => pendingOrders.length;

  int getPendingOrdersCountForClient(String? userId) {
    if (userId == null) return 0;
    return _orders
        .where((o) => o.status == 'pending' && o.userId == userId)
        .length;
  }

  int getPendingOrdersCountForDelivery(String? deliveryPersonId) {
    if (deliveryPersonId == null) return 0;
    return _orders.where((o) => o.status == 'pending').length;
  }

  List<OrderModel> get processingOrders =>
      _orders.where((o) => o.status == 'processing').toList();

  List<OrderModel> get shippedOrders =>
      _orders.where((o) => o.status == 'shipped').toList();

  List<OrderModel> get deliveredOrders =>
      _orders.where((o) => o.status == 'delivered').toList();

  List<OrderModel> get cancelledOrders =>
      _orders.where((o) => o.status == 'cancelled').toList();

  Future<void> loadOrders() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _ordersService.getAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[OrdersProvider] Error loading orders: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createOrder(OrderModel order) async {
    try {
      await _ordersService.create(order);
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[OrdersProvider] Error creating order: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrder(int id, Map<String, dynamic> data) async {
    try {
      await _ordersService.updateById(id, data);
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[OrdersProvider] Error updating order: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOrder(int id) async {
    try {
      await _ordersService.deleteById(id);
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[OrdersProvider] Error deleting order: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrderStatus(int id, String status) async {
    try {
      await _ordersService.updateById(id, {'status': status});
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[OrdersProvider] Error updating order status: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
