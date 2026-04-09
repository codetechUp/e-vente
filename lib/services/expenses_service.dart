import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_model.dart';

class ExpensesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ExpenseModel>> getAll() async {
    final response = await _supabase
        .from('expenses')
        .select()
        .order('date', ascending: false);

    return (response as List)
        .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseModel?> getById(int id) async {
    final response = await _supabase
        .from('expenses')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ExpenseModel.fromJson(response);
  }

  Future<ExpenseModel> create(ExpenseModel expense) async {
    final response = await _supabase
        .from('expenses')
        .insert(expense.toJson())
        .select()
        .single();

    return ExpenseModel.fromJson(response);
  }

  Future<void> updateById(int id, Map<String, dynamic> data) async {
    await _supabase.from('expenses').update(data).eq('id', id);
  }

  Future<void> deleteById(int id) async {
    await _supabase.from('expenses').delete().eq('id', id);
  }

  Future<List<ExpenseModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final response = await _supabase
        .from('expenses')
        .select()
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date', ascending: false);

    return (response as List)
        .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseModel>> getByCategory(String category) async {
    final response = await _supabase
        .from('expenses')
        .select()
        .eq('category', category)
        .order('date', ascending: false);

    return (response as List)
        .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<double> getTotalByDateRange(DateTime start, DateTime end) async {
    final expenses = await getByDateRange(start, end);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<Map<String, double>> getTotalByCategory(
    DateTime start,
    DateTime end,
  ) async {
    final expenses = await getByDateRange(start, end);
    final Map<String, double> totals = {};

    for (final expense in expenses) {
      final currentTotal = totals[expense.category] ?? 0.0;
      totals[expense.category] = currentTotal + expense.amount;
    }

    return totals;
  }
}
