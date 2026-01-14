/// Budget period types
enum BudgetPeriod { weekly, monthly, yearly }

/// Extension for budget period
extension BudgetPeriodExtension on BudgetPeriod {
  String get displayName {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'Mingguan';
      case BudgetPeriod.monthly:
        return 'Bulanan';
      case BudgetPeriod.yearly:
        return 'Tahunan';
    }
  }
}

/// Budget model for tracking spending limits per category
class Budget {
  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    amount: (json['amount'] as num).toDouble(),
    period: BudgetPeriod.values[json['period'] as int],
    startDate: DateTime.parse(json['startDate'] as String),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String id;
  final String categoryId;
  final double amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'amount': amount,
    'period': period.index,
    'startDate': startDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get the end date based on the period
  DateTime get endDate {
    switch (period) {
      case BudgetPeriod.weekly:
        return startDate.add(const Duration(days: 7));
      case BudgetPeriod.monthly:
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case BudgetPeriod.yearly:
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
    }
  }

  /// Check if the budget is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }
}
