import '../models/order_item_model.dart';
import 'supabase_table_service.dart';

class OrderItemsService {
  final SupabaseTableService<OrderItemModel> _table;

  OrderItemsService({SupabaseTableService<OrderItemModel>? table})
      : _table = table ??
            SupabaseTableService<OrderItemModel>(
              table: 'order_items',
              primaryKey: 'id',
              fromJson: OrderItemModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<OrderItemModel>> getAll() => _table.getAll(orderBy: 'id');

  Future<OrderItemModel?> getById(int id) => _table.getById(id);

  Future<OrderItemModel> create(OrderItemModel model) => _table.create(model);

  Future<OrderItemModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
