import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../core/constants.dart';

/// Database service for managing Hive boxes and CRUD operations
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Box<String> _accountsBox;
  late Box<String> _transactionsBox;
  late Box<String> _categoriesBox;
  late Box<String> _budgetsBox;
  late Box<String> _goalsBox;
  late Box<String> _settingsBox;

  bool _isInitialized = false;

  /// Initialize Hive database
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Open boxes (store as JSON strings)
    _accountsBox = await Hive.openBox<String>(AppConstants.accountsBox);
    _transactionsBox = await Hive.openBox<String>(AppConstants.transactionsBox);
    _categoriesBox = await Hive.openBox<String>(AppConstants.categoriesBox);
    _budgetsBox = await Hive.openBox<String>(AppConstants.budgetsBox);
    _goalsBox = await Hive.openBox<String>(AppConstants.goalsBox);
    _settingsBox = await Hive.openBox<String>(AppConstants.settingsBox);

    // Seed default categories if empty
    await _seedDefaultCategories();

    _isInitialized = true;
  }

  /// Seed default categories if none exist
  Future<void> _seedDefaultCategories() async {
    if (_categoriesBox.isEmpty) {
      for (final category in DefaultCategories.all) {
        await _categoriesBox.put(category.id, jsonEncode(category.toJson()));
      }
    }
  }

  // ============== ACCOUNTS ==============

  List<Account> getAccounts() {
    return _accountsBox.values
        .map((json) => Account.fromJson(jsonDecode(json)))
        .toList();
  }

  Account? getAccount(String id) {
    final json = _accountsBox.get(id);
    return json != null ? Account.fromJson(jsonDecode(json)) : null;
  }

  Future<void> saveAccount(Account account) async {
    await _accountsBox.put(account.id, jsonEncode(account.toJson()));
  }

  Future<void> deleteAccount(String id) async {
    await _accountsBox.delete(id);
  }

  double getTotalBalance() {
    return getAccounts().fold(0, (sum, acc) => sum + acc.balance);
  }

  // ============== TRANSACTIONS ==============

  List<Transaction> getTransactions() {
    final transactions = _transactionsBox.values
        .map((json) => Transaction.fromJson(jsonDecode(json)))
        .toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return getTransactions().where((t) => t.accountId == accountId).toList();
  }

  List<Transaction> getTransactionsByCategory(String categoryId) {
    return getTransactions().where((t) => t.categoryId == categoryId).toList();
  }

  List<Transaction> getTransactionsByType(TransactionType type) {
    return getTransactions().where((t) => t.type == type).toList();
  }

  Future<void> saveTransaction(Transaction transaction) async {
    await _transactionsBox.put(
      transaction.id,
      jsonEncode(transaction.toJson()),
    );
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  double getTotalIncome({DateTime? start, DateTime? end}) {
    var transactions = getTransactionsByType(TransactionType.income);
    if (start != null && end != null) {
      transactions = transactions
          .where(
            (t) =>
                t.date.isAfter(start) &&
                t.date.isBefore(end.add(const Duration(days: 1))),
          )
          .toList();
    }
    return transactions.fold(0, (sum, t) => sum + t.amount);
  }

  double getTotalExpense({DateTime? start, DateTime? end}) {
    var transactions = getTransactionsByType(TransactionType.expense);
    if (start != null && end != null) {
      transactions = transactions
          .where(
            (t) =>
                t.date.isAfter(start) &&
                t.date.isBefore(end.add(const Duration(days: 1))),
          )
          .toList();
    }
    return transactions.fold(0, (sum, t) => sum + t.amount);
  }

  // ============== CATEGORIES ==============

  List<Category> getCategories() {
    return _categoriesBox.values
        .map((json) => Category.fromJson(jsonDecode(json)))
        .toList();
  }

  List<Category> getCategoriesByType(TransactionType type) {
    return getCategories().where((c) => c.type == type).toList();
  }

  Category? getCategory(String id) {
    final json = _categoriesBox.get(id);
    return json != null ? Category.fromJson(jsonDecode(json)) : null;
  }

  Future<void> saveCategory(Category category) async {
    await _categoriesBox.put(category.id, jsonEncode(category.toJson()));
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
  }

  // ============== BUDGETS ==============

  List<Budget> getBudgets() {
    return _budgetsBox.values
        .map((json) => Budget.fromJson(jsonDecode(json)))
        .toList();
  }

  List<Budget> getActiveBudgets() {
    return getBudgets().where((b) => b.isActive).toList();
  }

  Budget? getBudget(String id) {
    final json = _budgetsBox.get(id);
    return json != null ? Budget.fromJson(jsonDecode(json)) : null;
  }

  Future<void> saveBudget(Budget budget) async {
    await _budgetsBox.put(budget.id, jsonEncode(budget.toJson()));
  }

  Future<void> deleteBudget(String id) async {
    await _budgetsBox.delete(id);
  }

  double getBudgetSpent(Budget budget) {
    final transactions = getTransactionsByCategory(budget.categoryId)
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.isAfter(budget.startDate) &&
              t.date.isBefore(budget.endDate),
        )
        .toList();
    return transactions.fold(0, (sum, t) => sum + t.amount);
  }

  // ============== GOALS ==============

  List<Goal> getGoals() {
    final goals = _goalsBox.values
        .map((json) => Goal.fromJson(jsonDecode(json)))
        .toList();
    goals.sort((a, b) => a.deadline.compareTo(b.deadline));
    return goals;
  }

  List<Goal> getActiveGoals() {
    return getGoals().where((g) => !g.isCompleted).toList();
  }

  Goal? getGoal(String id) {
    final json = _goalsBox.get(id);
    return json != null ? Goal.fromJson(jsonDecode(json)) : null;
  }

  Future<void> saveGoal(Goal goal) async {
    await _goalsBox.put(goal.id, jsonEncode(goal.toJson()));
  }

  Future<void> deleteGoal(String id) async {
    await _goalsBox.delete(id);
  }

  // ============== USER PROFILE ==============

  UserProfile getUserProfile() {
    final json = _settingsBox.get(AppConstants.userProfileKey);
    return json != null
        ? UserProfile.fromJson(jsonDecode(json))
        : UserProfile();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _settingsBox.put(
      AppConstants.userProfileKey,
      jsonEncode(profile.toJson()),
    );
  }

  // ============== SETTINGS ==============

  bool isFirstLaunch() {
    return _settingsBox.get(AppConstants.isFirstLaunchKey) == null;
  }

  Future<void> markFirstLaunchComplete() async {
    await _settingsBox.put(AppConstants.isFirstLaunchKey, 'false');
  }

  // ============== DATA EXPORT ==============

  Map<String, dynamic> exportData() {
    return {
      'version': AppConstants.appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': getAccounts().map((a) => a.toJson()).toList(),
      'transactions': getTransactions().map((t) => t.toJson()).toList(),
      'categories': getCategories().map((c) => c.toJson()).toList(),
      'budgets': getBudgets().map((b) => b.toJson()).toList(),
      'goals': getGoals().map((g) => g.toJson()).toList(),
      'userProfile': getUserProfile().toJson(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    await _accountsBox.clear();
    await _transactionsBox.clear();
    await _categoriesBox.clear();
    await _budgetsBox.clear();
    await _goalsBox.clear();

    if (data['accounts'] != null) {
      for (final json in data['accounts'] as List) {
        final account = Account.fromJson(json as Map<String, dynamic>);
        await saveAccount(account);
      }
    }
    if (data['transactions'] != null) {
      for (final json in data['transactions'] as List) {
        final transaction = Transaction.fromJson(json as Map<String, dynamic>);
        await saveTransaction(transaction);
      }
    }
    if (data['categories'] != null) {
      for (final json in data['categories'] as List) {
        final category = Category.fromJson(json as Map<String, dynamic>);
        await saveCategory(category);
      }
    }
    if (data['budgets'] != null) {
      for (final json in data['budgets'] as List) {
        final budget = Budget.fromJson(json as Map<String, dynamic>);
        await saveBudget(budget);
      }
    }
    if (data['goals'] != null) {
      for (final json in data['goals'] as List) {
        final goal = Goal.fromJson(json as Map<String, dynamic>);
        await saveGoal(goal);
      }
    }
    if (data['userProfile'] != null) {
      final profile = UserProfile.fromJson(
        data['userProfile'] as Map<String, dynamic>,
      );
      await saveUserProfile(profile);
    }
  }

  Future<void> clearAllData() async {
    await _accountsBox.clear();
    await _transactionsBox.clear();
    await _budgetsBox.clear();
    await _goalsBox.clear();
    await _settingsBox.clear();
    await _categoriesBox.clear();
    await _seedDefaultCategories();
  }
}
