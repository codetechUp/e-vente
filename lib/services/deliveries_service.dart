import '../models/delivery_model.dart';
import 'supabase_table_service.dart';

class DeliveriesService {
  final SupabaseTableService<DeliveryModel> _table;

  DeliveriesService({SupabaseTableService<DeliveryModel>? table})
      : _table = table ??
            SupabaseTableService<DeliveryModel>(
              table: 'deliveries',
              primaryKey: 'id',
              fromJson: DeliveryModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<DeliveryModel>> getAll() => _table.getAll(orderBy: 'id');

  Future<DeliveryModel?> getById(int id) => _table.getById(id);

  Future<DeliveryModel> create(DeliveryModel model) => _table.create(model);

  Future<DeliveryModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
