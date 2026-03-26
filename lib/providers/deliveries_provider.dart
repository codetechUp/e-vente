import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_model.dart';
import '../services/app_users_service.dart';
import '../services/deliveries_service.dart';

class DeliveriesProvider extends ChangeNotifier {
  final DeliveriesService _deliveriesService;
  final AppUsersService _usersService;

  List<DeliveryModel> _deliveries = [];
  bool _loading = false;
  String? _error;
  String? _currentDeliveryPersonId;

  DeliveriesProvider({
    DeliveriesService? deliveriesService,
    AppUsersService? usersService,
  })  : _deliveriesService = deliveriesService ?? DeliveriesService(),
        _usersService = usersService ?? AppUsersService() {
    _init();
  }

  List<DeliveryModel> get deliveries => _deliveries;
  bool get loading => _loading;
  String? get error => _error;

  List<DeliveryModel> get myDeliveries {
    if (_currentDeliveryPersonId == null) return [];
    return _deliveries
        .where((d) => d.deliveryPersonId == _currentDeliveryPersonId)
        .toList();
  }

  List<DeliveryModel> get pendingRequests {
    if (_currentDeliveryPersonId == null) return [];
    return _deliveries
        .where((d) =>
            d.deliveryPersonId == _currentDeliveryPersonId &&
            (d.status == 'pending' || d.status == 'processing'))
        .toList();
  }

  List<DeliveryModel> get activeDeliveries {
    if (_currentDeliveryPersonId == null) return [];
    return _deliveries
        .where((d) =>
            d.deliveryPersonId == _currentDeliveryPersonId &&
            d.status == 'shipped')
        .toList();
  }

  Future<void> _init() async {
    await _resolveCurrentDeliveryPerson();
    await loadDeliveries();
  }

  Future<void> _resolveCurrentDeliveryPerson() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    try {
      final appUser = await _usersService.resolveForAuthUser(
        authUserId: authUser.id,
        email: authUser.email,
      );
      _currentDeliveryPersonId = appUser?.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeliveriesProvider] Error resolving delivery person: $e');
      }
    }
  }

  Future<void> loadDeliveries() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _deliveries = await _deliveriesService.getAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[DeliveriesProvider] Error loading deliveries: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> acceptDelivery(DeliveryModel delivery) async {
    if (delivery.id == null) return;

    try {
      await _deliveriesService.updateById(delivery.id!, {'status': 'shipped'});

      if (delivery.orderId != null) {
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'shipped'})
            .eq('id', delivery.orderId!);
      }

      await loadDeliveries();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[DeliveriesProvider] Error accepting delivery: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAsDelivered(DeliveryModel delivery) async {
    if (delivery.id == null) return;

    try {
      await _deliveriesService.updateById(delivery.id!, {
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      });

      if (delivery.orderId != null) {
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'delivered'})
            .eq('id', delivery.orderId!);
      }

      await loadDeliveries();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[DeliveriesProvider] Error marking as delivered: $e');
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
