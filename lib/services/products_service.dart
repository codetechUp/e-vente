import '../models/product_model.dart';
import 'supabase_table_service.dart';

class ProductsService {
  final SupabaseTableService<ProductModel> _table;

  ProductsService({SupabaseTableService<ProductModel>? table})
      : _table = table ??
            SupabaseTableService<ProductModel>(
              table: 'products',
              primaryKey: 'id',
              fromJson: ProductModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<ProductModel>> getAll() => _table.getAll(orderBy: 'created_at');

  Future<ProductModel?> getById(int id) => _table.getById(id);

  Future<ProductModel> create(ProductModel model) => _table.create(model);

  Future<ProductModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
