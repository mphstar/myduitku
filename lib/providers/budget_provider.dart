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
  String? _selectedCategoryFilter;

  List<Budget> get budgets => _budgets;
  List<Budget> get activeBudgets =>
      _budgets.where((b) => b.isActive && !b.isArchived).toList();
  List<Budget> get archivedBudgets =>
      _budgets.where((b) => !b.isActive || b.isArchived).toList();
  
  String? get selectedCategoryFilter => _selectedCategoryFilter;
  bool get isLoading => _isLoading;

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryFilter = categoryId;
    notifyListeners();
  }

  /// Filter a budget list by current category filter
  List<Budget> filterByCategory(List<Budget> list) {
    if (_selectedCategoryFilter == null) return list;
    return list.where((b) => b.categoryId == _selectedCategoryFilter).toList();
  }

  /// Load budgets from database
  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();

    _budgets = _db.getBudgets();
    // Sort: newest start date first
    _budgets.sort((a, b) => b.startDate.compareTo(a.startDate));

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new budget and archive previous active budget for the same category
  Future<void> addBudget({
    required String categoryId,
    required double amount,
    required BudgetPeriod period,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();

    // Auto-archive any previously active budget for the same category
    for (final b in _budgets) {
      if (b.categoryId == categoryId && b.isActive) {
        final archived = b.copyWith(
          isArchived: true,
          endDate: now.isBefore(b.endDate) ? now : b.endDate,
        );
        await _db.saveBudget(archived);
      }
    }

    // Create new budget
    final budget = Budget(
      id: _uuid.v4(),
      categoryId: categoryId,
      amount: amount,
      period: period,
      startDate: startDate,
      endDate: endDate,
      isArchived: false,
    );

    await _db.saveBudget(budget);
    await loadBudgets();
  }

  /// Update an existing budget
  Future<void> updateBudget(Budget budget) async {
    await _db.saveBudget(budget);
    await loadBudgets();
  }

  /// Archive a budget manually
  Future<void> archiveBudget(String id) async {
    final b = getBudgetById(id);
    if (b != null) {
      final updated = b.copyWith(isArchived: true);
      await _db.saveBudget(updated);
      await loadBudgets();
    }
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

  /// Get active budget by category
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

  /// Get progress percentage for a budget (0.0 to 1.5)
  double getBudgetProgress(Budget budget) {
    if (budget.amount <= 0) return 0;
    final spent = getSpentAmount(budget);
    return (spent / budget.amount).clamp(0.0, 1.5);
  }

  /// Check if budget is near limit (>= 80%)
  bool isNearLimit(Budget budget) {
    return getBudgetProgress(budget) >= 0.8;
  }

  /// Check if budget is over limit (> 100%)
  bool isOverBudget(Budget budget) {
    return getBudgetProgress(budget) > 1.0;
  }

  /// Get remaining amount for a budget
  double getRemainingAmount(Budget budget) {
    final spent = getSpentAmount(budget);
    return (budget.amount - spent).clamp(0, double.infinity);
  }
}
