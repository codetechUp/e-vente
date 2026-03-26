import '../models/order_item_model.dart';
import 'supabase_table_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderItemsService {
  final SupabaseTableService<OrderItemModel> _table;
  final SupabaseClient _client;

  OrderItemsService({SupabaseTableService<OrderItemModel>? table})
    : _table =
          table ??
          SupabaseTableService<OrderItemModel>(
            table: 'order_items',
            primaryKey: 'id',
            fromJson: OrderItemModel.fromJson,
            toJson: (m) => m.toJson(),
          ),
      _client = Supabase.instance.client;

  Future<List<OrderItemModel>> getAll() => _table.getAll(orderBy: 'id');

  Future<List<OrderItemModel>> getAllForOrder(int orderId) async {
    final rows = await _client
        .from('order_items')
        .select('*, products(name)')
        .eq('order_id', orderId)
        .order('id', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => OrderItemModel.fromJson(e))
        .toList();
  }

  Future<OrderItemModel?> getById(int id) => _table.getById(id);

  Future<OrderItemModel> create(OrderItemModel model) => _table.create(model);

  Future<OrderItemModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
