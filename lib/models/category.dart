import 'transaction.dart';

/// Category model for transaction categorization
class Category {
  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as int,
    type: TransactionType.values[json['type'] as int],
    isDefault: json['isDefault'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String icon;
  final int color;
  final TransactionType type;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'type': type.index,
    'isDefault': isDefault,
  };

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? color,
    TransactionType? type,
    bool? isDefault,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Default categories for the app
class DefaultCategories {
  static List<Category> get all => [...expense, ...income];

  static List<Category> get expense => [
    Category(
      id: 'cat_food',
      name: 'Makanan',
      icon: 'restaurant',
      color: 0xFFFF6B6B,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_transport',
      name: 'Transport',
      icon: 'directions_car',
      color: 0xFF4ECDC4,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_shopping',
      name: 'Belanja',
      icon: 'shopping_bag',
      color: 0xFFFFE66D,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_bills',
      name: 'Tagihan',
      icon: 'receipt_long',
      color: 0xFF95E1D3,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_entertainment',
      name: 'Hiburan',
      icon: 'movie',
      color: 0xFFA66CFF,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_health',
      name: 'Kesehatan',
      icon: 'local_hospital',
      color: 0xFFFF8E8E,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_education',
      name: 'Pendidikan',
      icon: 'school',
      color: 0xFF6BCB77,
      type: TransactionType.expense,
      isDefault: true,
    ),
    Category(
      id: 'cat_other_expense',
      name: 'Lainnya',
      icon: 'more_horiz',
      color: 0xFF9E9E9E,
      type: TransactionType.expense,
      isDefault: true,
    ),
  ];

  static List<Category> get income => [
    Category(
      id: 'cat_salary',
      name: 'Gaji',
      icon: 'work',
      color: 0xFF4CAF50,
      type: TransactionType.income,
      isDefault: true,
    ),
    Category(
      id: 'cat_bonus',
      name: 'Bonus',
      icon: 'card_giftcard',
      color: 0xFF2196F3,
      type: TransactionType.income,
      isDefault: true,
    ),
    Category(
      id: 'cat_investment',
      name: 'Investasi',
      icon: 'trending_up',
      color: 0xFF9C27B0,
      type: TransactionType.income,
      isDefault: true,
    ),
    Category(
      id: 'cat_gift',
      name: 'Hadiah',
      icon: 'redeem',
      color: 0xFFE91E63,
      type: TransactionType.income,
      isDefault: true,
    ),
    Category(
      id: 'cat_other_income',
      name: 'Lainnya',
      icon: 'more_horiz',
      color: 0xFF607D8B,
      type: TransactionType.income,
      isDefault: true,
    ),
  ];
}
