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
    DateTime? endDate,
    this.isArchived = false,
    DateTime? createdAt,
  })  : endDate = endDate ?? _calculateEndDate(startDate, period),
        createdAt = createdAt ?? DateTime.now();

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        amount: (json['amount'] as num).toDouble(),
        period: BudgetPeriod.values[json['period'] as int],
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        isArchived: json['isArchived'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  final String id;
  final String categoryId;
  final double amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final bool isArchived;
  final DateTime createdAt;

  static DateTime _calculateEndDate(DateTime start, BudgetPeriod p) {
    switch (p) {
      case BudgetPeriod.weekly:
        return DateTime(start.year, start.month, start.day + 7, 23, 59, 59);
      case BudgetPeriod.monthly:
        return DateTime(start.year, start.month + 1, start.day, 23, 59, 59);
      case BudgetPeriod.yearly:
        return DateTime(start.year + 1, start.month, start.day, 23, 59, 59);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'period': period.index,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isArchived': isArchived,
        'createdAt': createdAt.toIso8601String(),
      };

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if the budget is currently active
  bool get isActive {
    if (isArchived) return false;
    final now = DateTime.now();
    return now.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        now.isBefore(endDate.add(const Duration(seconds: 1)));
  }
}
