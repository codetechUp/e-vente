import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock_entry_model.dart';

class StockEntriesService {
  final _client = Supabase.instance.client;

  Future<List<StockEntryModel>> getAll() async {
    final response = await _client
        .from('stock_entries')
        .select('*, products(name), users(name, email)')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => StockEntryModel.fromJson(json))
        .toList();
  }

  Future<List<StockEntryModel>> getByProduct(int productId) async {
    final response = await _client
        .from('stock_entries')
        .select('*, products(name), users(name, email)')
        .eq('product_id', productId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => StockEntryModel.fromJson(json))
        .toList();
  }

  Future<StockEntryModel> create(StockEntryModel entry) async {
    final response = await _client
        .from('stock_entries')
        .insert(entry.toJson())
        .select('*, products(name), users(name, email)')
        .single();

    return StockEntryModel.fromJson(response);
  }

  Future<StockEntryModel> getById(int id) async {
    final response = await _client
        .from('stock_entries')
        .select('*, products(name), users(name, email)')
        .eq('id', id)
        .single();

    return StockEntryModel.fromJson(response);
  }

  Future<void> updateById(int id, Map<String, dynamic> updates) async {
    await _client.from('stock_entries').update(updates).eq('id', id);
  }

  Future<void> deleteById(int id) async {
    await _client.from('stock_entries').delete().eq('id', id);
  }

  // Statistiques
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client
        .from('stock_entries')
        .select('quantity, entry_type');

    final entries = (response as List).cast<Map<String, dynamic>>();
    
    int totalPurchases = 0;
    int totalAdjustments = 0;
    int totalReturns = 0;
    int totalQuantity = 0;

    for (final entry in entries) {
      final quantity = entry['quantity'] as int? ?? 0;
      final type = entry['entry_type'] as String? ?? 'purchase';
      
      totalQuantity += quantity;
      
      switch (type) {
        case 'purchase':
          totalPurchases += quantity;
          break;
        case 'adjustment':
          totalAdjustments += quantity;
          break;
        case 'return':
          totalReturns += quantity;
          break;
      }
    }

    return {
      'total_entries': entries.length,
      'total_quantity': totalQuantity,
      'total_purchases': totalPurchases,
      'total_adjustments': totalAdjustments,
      'total_returns': totalReturns,
    };
  }
}
