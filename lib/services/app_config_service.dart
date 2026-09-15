import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config_model.dart';

class AppConfigService {
  static const _table = 'app_config';
  static const _singletonId = 1;

  SupabaseClient get _client => Supabase.instance.client;

  /// Load the singleton configuration row.
  /// Returns default config if the row does not exist yet.
  Future<AppConfigModel> getConfig() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('id', _singletonId)
        .limit(1);

    if ((rows as List).isEmpty) {
      return const AppConfigModel();
    }

    return AppConfigModel.fromJson((rows as List).first as Map<String, dynamic>);
  }

  /// Upsert the singleton configuration row.
  Future<AppConfigModel> saveConfig(AppConfigModel config) async {
    final data = config.toJson();
    await _client.from(_table).upsert(data);
    return config;
  }
}
