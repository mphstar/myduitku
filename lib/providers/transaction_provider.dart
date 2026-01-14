import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for managing transactions
class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<Transaction> _transactions = [];
  bool _isLoading = false;

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryFilter;
  String? _accountFilter;
  TransactionType? _typeFilter;
  String _searchQuery = '';

  List<Transaction> get transactions => _filteredTransactions;
  List<Transaction> get allTransactions => _transactions;
  bool get isLoading => _isLoading;

  /// Get filtered transactions based on current filters
  List<Transaction> get _filteredTransactions {
    var filtered = List<Transaction>.from(_transactions);

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      filtered = filtered
          .where(
            (t) =>
                t.date.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                t.date.isBefore(_endDate!.add(const Duration(days: 1))),
          )
          .toList();
    }

    // Apply category filter
    if (_categoryFilter != null) {
      filtered = filtered
          .where((t) => t.categoryId == _categoryFilter)
          .toList();
    }

    // Apply account filter
    if (_accountFilter != null) {
      filtered = filtered.where((t) => t.accountId == _accountFilter).toList();
    }

    // Apply type filter
    if (_typeFilter != null) {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                t.description?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    }

    return filtered;
  }

  /// Get total income
  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Get total expense
  double get totalExpense {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Get total income for a date range
  double getTotalIncomeForRange(DateTime start, DateTime end) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.income &&
              t.date.isAfter(start.subtract(const Duration(days: 1))) &&
              t.date.isBefore(end.add(const Duration(days: 1))),
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Get total expense for a date range
  double getTotalExpenseForRange(DateTime start, DateTime end) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.isAfter(start.subtract(const Duration(days: 1))) &&
              t.date.isBefore(end.add(const Duration(days: 1))),
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Get expenses grouped by category for a date range
  Map<String, double> getExpensesByCategory({DateTime? start, DateTime? end}) {
    var filtered = _transactions.where(
      (t) => t.type == TransactionType.expense,
    );

    if (start != null && end != null) {
      filtered = filtered.where(
        (t) =>
            t.date.isAfter(start.subtract(const Duration(days: 1))) &&
            t.date.isBefore(end.add(const Duration(days: 1))),
      );
    }

    final Map<String, double> result = {};
    for (final t in filtered) {
      result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
    }
    return result;
  }

  /// Get recent transactions
  List<Transaction> getRecentTransactions({int limit = 5}) {
    return _transactions.take(limit).toList();
  }

  /// Load transactions from database
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = _db.getTransactions();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new transaction
  Future<Transaction> addTransaction({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? description,
    required DateTime date,
  }) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      description: description,
      date: date,
    );

    await _db.saveTransaction(transaction);
    await loadTransactions();
    return transaction;
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    await _db.saveTransaction(transaction);
    await loadTransactions();
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  /// Set date filter
  void setDateFilter(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(String? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();
  }

  /// Set account filter
  void setAccountFilter(String? accountId) {
    _accountFilter = accountId;
    notifyListeners();
  }

  /// Set type filter
  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _categoryFilter = null;
    _accountFilter = null;
    _typeFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Get transaction by ID
  Transaction? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
