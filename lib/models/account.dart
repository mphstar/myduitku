/// Account types supported by the app
enum AccountType { bank, cash, ewallet }

/// Extension to get display name for account types
extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.bank:
        return 'Bank';
      case AccountType.cash:
        return 'Tunai';
      case AccountType.ewallet:
        return 'E-Wallet';
    }
  }

  String get icon {
    switch (this) {
      case AccountType.bank:
        return 'account_balance';
      case AccountType.cash:
        return 'payments';
      case AccountType.ewallet:
        return 'account_balance_wallet';
    }
  }
}

/// Account model for storing financial accounts
class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.icon,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.values[json['type'] as int],
    balance: (json['balance'] as num).toDouble(),
    icon: json['icon'] as String?,
    color: json['color'] as int?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String? icon;
  final int? color;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.index,
    'balance': balance,
    'icon': icon,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? icon,
    int? color,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
