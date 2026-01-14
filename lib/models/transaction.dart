/// Transaction types
enum TransactionType { income, expense }

/// Extension for transaction types
extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
    }
  }
}

/// Transaction model for recording income and expenses
class Transaction {
  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.description,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionType.values[json['type'] as int],
    categoryId: json['categoryId'] as String,
    accountId: json['accountId'] as String,
    description: json['description'] as String?,
    date: DateTime.parse(json['date'] as String),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'type': type.index,
    'categoryId': categoryId,
    'accountId': accountId,
    'description': description,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
