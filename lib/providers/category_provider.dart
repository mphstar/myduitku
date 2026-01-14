import 'package:flutter/foundation.dart' hide Category;
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for managing categories
class CategoryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == TransactionType.expense).toList();
  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == TransactionType.income).toList();
  bool get isLoading => _isLoading;

  /// Load categories from database
  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    _categories = _db.getCategories();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new category
  Future<void> addCategory({
    required String name,
    required String icon,
    required int color,
    required TransactionType type,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      color: color,
      type: type,
      isDefault: false,
    );

    await _db.saveCategory(category);
    await loadCategories();
  }

  /// Update an existing category
  Future<void> updateCategory(Category category) async {
    await _db.saveCategory(category);
    await loadCategories();
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    await loadCategories();
  }

  /// Get category by ID
  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
