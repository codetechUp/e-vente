import '../models/app_user_model.dart';
import 'supabase_table_service.dart';

class AppUsersService {
  final SupabaseTableService<AppUserModel> _table;

  AppUsersService({SupabaseTableService<AppUserModel>? table})
      : _table = table ??
            SupabaseTableService<AppUserModel>(
              table: 'users',
              primaryKey: 'id',
              fromJson: AppUserModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<AppUserModel>> getAll() => _table.getAll(orderBy: 'created_at');

  Future<AppUserModel?> getById(String id) => _table.getById(id);

  Future<AppUserModel> create(AppUserModel model) => _table.create(model);

  Future<AppUserModel> updateById(String id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(String id) => _table.delete(id);
}
