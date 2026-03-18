import '../models/promotion_model.dart';
import 'supabase_table_service.dart';

class PromotionsService {
  final SupabaseTableService<PromotionModel> _table;

  PromotionsService({SupabaseTableService<PromotionModel>? table})
      : _table = table ??
            SupabaseTableService<PromotionModel>(
              table: 'promotions',
              primaryKey: 'id',
              fromJson: PromotionModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<PromotionModel>> getAll() => _table.getAll(orderBy: 'id');

  Future<PromotionModel?> getById(int id) => _table.getById(id);

  Future<PromotionModel> create(PromotionModel model) => _table.create(model);

  Future<PromotionModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
