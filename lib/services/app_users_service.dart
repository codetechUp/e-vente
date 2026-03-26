import '../models/app_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_table_service.dart';

class AppUsersService {
  final SupabaseTableService<AppUserModel> _table;
  final SupabaseClient _client;

  AppUsersService({SupabaseTableService<AppUserModel>? table})
    : _table =
          table ??
          SupabaseTableService<AppUserModel>(
            table: 'users',
            primaryKey: 'id',
            fromJson: AppUserModel.fromJson,
            toJson: (m) => m.toJson(),
          ),
      _client = Supabase.instance.client;

  Future<List<AppUserModel>> getAll() => _table.getAll(orderBy: 'created_at');

  Future<AppUserModel?> getById(String id) => _table.getById(id);

  Future<AppUserModel?> getByEmail(String email) async {
    final row = await _client
        .from('users')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (row == null) return null;
    return AppUserModel.fromJson((row as Map).cast<String, dynamic>());
  }

  Future<AppUserModel?> resolveForAuthUser({
    required String authUserId,
    required String? email,
  }) async {
    final byId = await getById(authUserId);
    if (byId != null) return byId;

    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return null;

    return getByEmail(normalizedEmail);
  }

  Future<AppUserModel> create(AppUserModel model) => _table.create(model);

  Future<AppUserModel> updateById(String id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(String id) => _table.delete(id);
}
