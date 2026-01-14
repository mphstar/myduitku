/// Goal model for savings targets
class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.deadline,
    this.icon,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
    deadline: DateTime.parse(json['deadline'] as String),
    icon: json['icon'] as String?,
    color: json['color'] as int?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String? icon;
  final int? color;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'deadline': deadline.toIso8601String(),
    'icon': icon,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? icon,
    int? color,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Calculate progress percentage (0.0 to 1.0)
  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// Calculate remaining amount to reach goal
  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0, double.infinity);

  /// Check if goal is completed
  bool get isCompleted => currentAmount >= targetAmount;

  /// Check if deadline has passed
  bool get isOverdue => DateTime.now().isAfter(deadline) && !isCompleted;

  /// Days remaining until deadline
  int get daysRemaining {
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
}
