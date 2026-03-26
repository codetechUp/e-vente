import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json);

typedef ToJson<T> = Map<String, dynamic> Function(T model);

class SupabaseTableService<T> {
  final SupabaseClient _client;
  final String table;
  final String primaryKey;
  final FromJson<T> fromJson;
  final ToJson<T> toJson;

  SupabaseTableService({
    SupabaseClient? client,
    required this.table,
    required this.primaryKey,
    required this.fromJson,
    required this.toJson,
  }) : _client = client ?? Supabase.instance.client;

  Future<List<T>> getAll({String? orderBy, bool ascending = true}) async {
    final rows = await _client
        .from(table)
        .select()
        .order(orderBy ?? primaryKey, ascending: ascending);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => fromJson(e))
        .toList();
  }

  Future<T?> getById(dynamic id) async {
    final row = await _client
        .from(table)
        .select()
        .eq(primaryKey, id)
        .maybeSingle();

    if (kDebugMode) {
      debugPrint('[SupabaseTableService] getById table=$table id=$id row=$row');
    }

    if (row == null) return null;
    return fromJson((row as Map).cast<String, dynamic>());
  }

  Future<T> create(T model) async {
    final row = await _client
        .from(table)
        .insert(toJson(model))
        .select()
        .single();

    return fromJson((row as Map).cast<String, dynamic>());
  }

  Future<T> update(dynamic id, Map<String, dynamic> patch) async {
    if (kDebugMode) {
      debugPrint(
        '[SupabaseTableService] update table=$table id=$id patch=$patch',
      );
    }

    try {
      await _client.from(table).update(patch).eq(primaryKey, id);
      if (kDebugMode) {
        debugPrint(
          '[SupabaseTableService] update executed successfully for $table id=$id',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseTableService] update error table=$table id=$id error=$e',
        );
      }
      rethrow;
    }

    final refreshed = await getById(id);
    if (refreshed != null) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseTableService] update reload success for $table id=$id',
        );
      }
      return refreshed;
    }

    if (kDebugMode) {
      debugPrint(
        '[SupabaseTableService] update reload failed for $table id=$id',
      );
    }
    throw PostgrestException(
      message:
          'Update completed but the row could not be reloaded from $table with $primaryKey=$id.',
      code: 'UPDATE_NO_ROW',
    );
  }

  Future<void> delete(dynamic id) async {
    await _client.from(table).delete().eq(primaryKey, id);
  }
}
