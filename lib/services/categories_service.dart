import '../models/category_model.dart';
import 'supabase_table_service.dart';

class CategoriesService {
  final SupabaseTableService<CategoryModel> _table;

  CategoriesService({SupabaseTableService<CategoryModel>? table})
      : _table = table ??
            SupabaseTableService<CategoryModel>(
              table: 'categories',
              primaryKey: 'id',
              fromJson: CategoryModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<CategoryModel>> getAll() => _table.getAll(orderBy: 'created_at');

  Future<CategoryModel?> getById(int id) => _table.getById(id);

  Future<CategoryModel> create(CategoryModel model) => _table.create(model);

  Future<CategoryModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
