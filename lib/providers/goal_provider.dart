import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for managing financial goals
class GoalProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<Goal> _goals = [];
  bool _isLoading = false;

  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<Goal> get completedGoals => _goals.where((g) => g.isCompleted).toList();
  bool get isLoading => _isLoading;

  /// Load goals from database
  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    _goals = _db.getGoals();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new goal
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime deadline,
    String? icon,
    int? color,
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      deadline: deadline,
      icon: icon,
      color: color,
    );

    await _db.saveGoal(goal);
    await loadGoals();
  }

  /// Update an existing goal
  Future<void> updateGoal(Goal goal) async {
    await _db.saveGoal(goal);
    await loadGoals();
  }

  /// Delete a goal
  Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
    await loadGoals();
  }

  /// Add funds to a goal
  Future<void> addFunds(String goalId, double amount) async {
    final goal = getGoalById(goalId);
    if (goal != null) {
      final updatedGoal = goal.copyWith(
        currentAmount: goal.currentAmount + amount,
      );
      await _db.saveGoal(updatedGoal);
      await loadGoals();
    }
  }

  /// Withdraw funds from a goal
  Future<void> withdrawFunds(String goalId, double amount) async {
    final goal = getGoalById(goalId);
    if (goal != null) {
      final newAmount = (goal.currentAmount - amount).clamp(
        0.0,
        double.infinity,
      );
      final updatedGoal = goal.copyWith(currentAmount: newAmount);
      await _db.saveGoal(updatedGoal);
      await loadGoals();
    }
  }

  /// Get goal by ID
  Goal? getGoalById(String id) {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get total saved amount across all goals
  double get totalSaved => _goals.fold(0, (sum, g) => sum + g.currentAmount);

  /// Get total target amount across all goals
  double get totalTarget => _goals.fold(0, (sum, g) => sum + g.targetAmount);
}
