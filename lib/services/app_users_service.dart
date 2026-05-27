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
    final list = await _client
        .from('users')
        .select()
        .eq('email', email);

    if (list.isEmpty) return null;
    return AppUserModel.fromJson((list.first as Map).cast<String, dynamic>());
  }

  Future<AppUserModel?> getByPhone(String phone) async {
    // Essayer d'abord le format exact
    final list = await _client
        .from('users')
        .select()
        .eq('phone', phone);

    if (list.isNotEmpty) {
      return AppUserModel.fromJson((list.first as Map).cast<String, dynamic>());
    }

    // Essayer aussi sans le +221 au cas où la DB stocke le numéro local
    final localPhone = phone.startsWith('+221') ? phone.substring(4) : phone;
    final withPrefix = phone.startsWith('+221') ? phone : '+221$phone';

    // Essayer sans préfixe
    final list2 = await _client
        .from('users')
        .select()
        .eq('phone', localPhone);
    if (list2.isNotEmpty) {
      return AppUserModel.fromJson((list2.first as Map).cast<String, dynamic>());
    }

    // Essayer avec +221 si pas encore présent
    if (localPhone != withPrefix) {
      final list3 = await _client
          .from('users')
          .select()
          .eq('phone', withPrefix);
      if (list3.isNotEmpty) {
        return AppUserModel.fromJson((list3.first as Map).cast<String, dynamic>());
      }
    }

    return null;
  }

  Future<AppUserModel?> resolveForAuthUser({
    required String authUserId,
    required String? email,
    String? phone,
  }) async {
    final byId = await getById(authUserId);
    if (byId != null) return byId;

    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      final byEmail = await getByEmail(normalizedEmail);
      if (byEmail != null) return byEmail;
    }

    final normalizedPhone = phone?.trim();
    if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
      return getByPhone(normalizedPhone);
    }

    return null;
  }

  Future<AppUserModel> create(AppUserModel model) => _table.create(model);

  Future<AppUserModel> updateById(String id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(String id) => _table.delete(id);
}
