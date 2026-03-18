import '../models/stock_model.dart';
import 'supabase_table_service.dart';

class StocksService {
  final SupabaseTableService<StockModel> _table;

  StocksService({SupabaseTableService<StockModel>? table})
      : _table = table ??
            SupabaseTableService<StockModel>(
              table: 'stocks',
              primaryKey: 'id',
              fromJson: StockModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<StockModel>> getAll() => _table.getAll(orderBy: 'updated_at');

  Future<StockModel?> getById(int id) => _table.getById(id);

  Future<StockModel> create(StockModel model) => _table.create(model);

  Future<StockModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
