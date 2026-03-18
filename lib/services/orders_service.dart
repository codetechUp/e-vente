import '../models/order_model.dart';
import 'supabase_table_service.dart';

class OrdersService {
  final SupabaseTableService<OrderModel> _table;

  OrdersService({SupabaseTableService<OrderModel>? table})
      : _table = table ??
            SupabaseTableService<OrderModel>(
              table: 'orders',
              primaryKey: 'id',
              fromJson: OrderModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<OrderModel>> getAll() => _table.getAll(orderBy: 'created_at');

  Future<OrderModel?> getById(int id) => _table.getById(id);

  Future<OrderModel> create(OrderModel model) => _table.create(model);

  Future<OrderModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
