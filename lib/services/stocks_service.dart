import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock_model.dart';
import 'supabase_table_service.dart';

class StocksService {
  final SupabaseTableService<StockModel> _table;
  final SupabaseClient _client;

  StocksService({
    SupabaseTableService<StockModel>? table,
    SupabaseClient? client,
  }) : _table =
           table ??
           SupabaseTableService<StockModel>(
             table: 'stocks',
             primaryKey: 'id',
             fromJson: StockModel.fromJson,
             toJson: (m) => m.toJson(),
           ),
       _client = client ?? Supabase.instance.client;

  Future<List<StockModel>> getAll() => _table.getAll(orderBy: 'updated_at');

  Future<StockModel?> getById(int id) => _table.getById(id);

  Future<StockModel?> getByProductId(int productId) async {
    final row = await _client
        .from('stocks')
        .select()
        .eq('product_id', productId)
        .maybeSingle();
    if (row == null) return null;
    return StockModel.fromJson(row);
  }

  Future<StockModel> create(StockModel model) => _table.create(model);

  Future<StockModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);

  Future<void> decrementStock(int productId, int quantity) async {
    final stock = await getByProductId(productId);
    if (stock == null || stock.id == null) return;
    final newQty = (stock.quantity - quantity).clamp(0, 999999);
    await updateById(stock.id!, {
      'quantity': newQty,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
