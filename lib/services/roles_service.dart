import '../models/role_model.dart';
import 'supabase_table_service.dart';

class RolesService {
  final SupabaseTableService<RoleModel> _table;

  RolesService({SupabaseTableService<RoleModel>? table})
      : _table = table ??
            SupabaseTableService<RoleModel>(
              table: 'roles',
              primaryKey: 'id',
              fromJson: RoleModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<RoleModel>> getAll() => _table.getAll(orderBy: 'name');

  Future<RoleModel?> getById(int id) => _table.getById(id);

  Future<RoleModel> create(RoleModel model) => _table.create(model);

  Future<RoleModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
