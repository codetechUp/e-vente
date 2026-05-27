import '../models/audio_model.dart';
import 'supabase_table_service.dart';

class AudiosService {
  final SupabaseTableService<AudioModel> _table;

  AudiosService({SupabaseTableService<AudioModel>? table})
      : _table = table ??
            SupabaseTableService<AudioModel>(
              table: 'audios',
              primaryKey: 'id',
              fromJson: AudioModel.fromJson,
              toJson: (m) => m.toJson(),
            );

  Future<List<AudioModel>> getAll() => _table.getAll(orderBy: 'created_at', ascending: false);

  Future<AudioModel?> getById(String id) => _table.getById(id);

  Future<AudioModel> create(AudioModel model) => _table.create(model);

  Future<AudioModel> updateById(String id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(String id) => _table.delete(id);
}
