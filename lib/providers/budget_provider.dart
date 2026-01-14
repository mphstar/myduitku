import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for managing budgets
class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<Budget> _budgets = [];
  bool _isLoading = false;

  List<Budget> get budgets => _budgets;
  List<Budget> get activeBudgets => _budgets.where((b) => b.isActive).toList();
  bool get isLoading => _isLoading;

  /// Load budgets from database
  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();

    _budgets = _db.getBudgets();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new budget
  Future<void> addBudget({
    required String categoryId,
    required double amount,
    required BudgetPeriod period,
    required DateTime startDate,
  }) async {
    final budget = Budget(
      id: _uuid.v4(),
      categoryId: categoryId,
      amount: amount,
      period: period,
      startDate: startDate,
    );

    await _db.saveBudget(budget);
    await loadBudgets();
  }

  /// Update an existing budget
  Future<void> updateBudget(Budget budget) async {
    await _db.saveBudget(budget);
    await loadBudgets();
  }

  /// Delete a budget
  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    await loadBudgets();
  }

  /// Get budget by ID
  Budget? getBudgetById(String id) {
    try {
      return _budgets.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get budget by category
  Budget? getBudgetByCategory(String categoryId) {
    try {
      return _budgets.firstWhere(
        (b) => b.categoryId == categoryId && b.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get spent amount for a budget
  double getSpentAmount(Budget budget) {
    return _db.getBudgetSpent(budget);
  }

  /// Get progress percentage for a budget (0.0 to 1.0)
  double getBudgetProgress(Budget budget) {
    if (budget.amount <= 0) return 0;
    final spent = getSpentAmount(budget);
    return (spent / budget.amount).clamp(
      0.0,
      1.5,
    ); // Allow up to 150% for over-budget
  }

  /// Check if budget is near limit (>= 80%)
  bool isNearLimit(Budget budget) {
    return getBudgetProgress(budget) >= 0.8;
  }

  /// Check if budget is over limit
  bool isOverBudget(Budget budget) {
    return getBudgetProgress(budget) > 1.0;
  }

  /// Get remaining amount for a budget
  double getRemainingAmount(Budget budget) {
    final spent = getSpentAmount(budget);
    return (budget.amount - spent).clamp(0, double.infinity);
  }
}
