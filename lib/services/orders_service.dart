import '../models/order_model.dart';
import 'supabase_table_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersService {
  final SupabaseTableService<OrderModel> _table;
  final SupabaseClient _client;

  OrdersService({SupabaseTableService<OrderModel>? table})
    : _table =
          table ??
          SupabaseTableService<OrderModel>(
            table: 'orders',
            primaryKey: 'id',
            fromJson: OrderModel.fromJson,
            toJson: (m) => m.toJson(),
          ),
      _client = Supabase.instance.client;

  Future<List<OrderModel>> getAll() async {
    final rows = await _client
        .from('orders')
        .select(
          '*, users!orders_user_id_fkey(name, email, phone, nom, adresse), livreur:users!orders_assigned_livreur_id_fkey(name)',
        )
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => OrderModel.fromJson(e))
        .toList();
  }

  Future<List<OrderModel>> getAllForUser(String userId) async {
    final rows = await _client
        .from('orders')
        .select(
          '*, users!orders_user_id_fkey(name, email, phone, nom, adresse), livreur:users!orders_assigned_livreur_id_fkey(name)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => OrderModel.fromJson(e))
        .toList();
  }

  Future<OrderModel?> getById(int id) => _table.getById(id);

  Future<OrderModel> create(OrderModel model) => _table.create(model);

  Future<OrderModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
