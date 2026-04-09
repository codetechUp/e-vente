import 'package:flutter/foundation.dart';

import '../models/expense_model.dart';
import '../services/expenses_service.dart';

class ExpensesProvider extends ChangeNotifier {
  final ExpensesService _expensesService;

  List<ExpenseModel> _expenses = [];
  bool _loading = false;
  String? _error;

  ExpensesProvider({ExpensesService? expensesService})
      : _expensesService = expensesService ?? ExpensesService() {
    loadExpenses();
  }

  List<ExpenseModel> get expenses => _expenses;
  bool get loading => _loading;
  String? get error => _error;

  double get totalExpenses =>
      _expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  Map<String, double> get expensesByCategory {
    final Map<String, double> totals = {};
    for (final expense in _expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  List<ExpenseModel> getExpensesByCategory(String category) {
    return _expenses.where((e) => e.category == category).toList();
  }

  Future<void> loadExpenses() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _expensesService.getAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[ExpensesProvider] Error loading expenses: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createExpense(ExpenseModel expense) async {
    try {
      await _expensesService.create(expense);
      await loadExpenses();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[ExpensesProvider] Error creating expense: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(int id, Map<String, dynamic> data) async {
    try {
      await _expensesService.updateById(id, data);
      await loadExpenses();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[ExpensesProvider] Error updating expense: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      await _expensesService.deleteById(id);
      await loadExpenses();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[ExpensesProvider] Error deleting expense: $e');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<double> getTotalForDateRange(DateTime start, DateTime end) async {
    try {
      return await _expensesService.getTotalByDateRange(start, end);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ExpensesProvider] Error getting total: $e');
      }
      return 0.0;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
