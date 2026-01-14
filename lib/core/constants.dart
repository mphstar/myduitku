import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  static const String appName = 'MyDuitKu';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String accountsBox = 'accounts';
  static const String transactionsBox = 'transactions';
  static const String categoriesBox = 'categories';
  static const String budgetsBox = 'budgets';
  static const String goalsBox = 'goals';
  static const String settingsBox = 'settings';

  // Settings keys
  static const String userProfileKey = 'user_profile';
  static const String themeKey = 'theme_mode';
  static const String isFirstLaunchKey = 'is_first_launch';

  // Export/Import
  static const String exportFileName = 'myduitku_backup';
  static const String exportFileExtension = 'json';

  // Currency
  static const String defaultCurrency = 'Rp';

  // Animation durations
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 2);

  // AI Chat
  static const String chatMessagesBox = 'chat_messages';
  static const String openRouterApiUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String aiApiKeyKey = 'ai_api_key';
  static const String aiModelKey = 'ai_model';
  static const String defaultAiModel = 'google/gemini-2.0-flash-001';

  // Available AI models
  static const List<Map<String, String>> availableAiModels = [
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash'},
    {'id': 'google/gemini-pro', 'name': 'Gemini Pro'},
    {'id': 'anthropic/claude-3.5-sonnet', 'name': 'Claude 3.5 Sonnet'},
    {'id': 'anthropic/claude-3-haiku', 'name': 'Claude 3 Haiku'},
    {'id': 'openai/gpt-4o-mini', 'name': 'GPT-4o Mini'},
    {'id': 'openai/gpt-4o', 'name': 'GPT-4o'},
    {'id': 'meta-llama/llama-3.1-8b-instruct', 'name': 'Llama 3.1 8B'},
  ];
}

/// Icon name to IconData mapping
class AppIcons {
  static const Map<String, IconData> icons = {
    // Account icons
    'account_balance': Icons.account_balance,
    'payments': Icons.payments,
    'account_balance_wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
    'savings': Icons.savings,

    // Category icons - Expense
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'local_hospital': Icons.local_hospital,
    'school': Icons.school,
    'home': Icons.home,
    'pets': Icons.pets,
    'sports_esports': Icons.sports_esports,
    'flight': Icons.flight,
    'phone_android': Icons.phone_android,
    'wifi': Icons.wifi,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,

    // Category icons - Income
    'work': Icons.work,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'redeem': Icons.redeem,
    'attach_money': Icons.attach_money,
    'business': Icons.business,

    // General icons
    'more_horiz': Icons.more_horiz,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'flag': Icons.flag,
    'emoji_events': Icons.emoji_events,
    'beach_access': Icons.beach_access,
    'directions_bike': Icons.directions_bike,
    'laptop': Icons.laptop,
    'headphones': Icons.headphones,
    'camera_alt': Icons.camera_alt,
    'fitness_center': Icons.fitness_center,
  };

  static IconData getIcon(String name) {
    return icons[name] ?? Icons.help_outline;
  }

  static List<String> get allIconNames => icons.keys.toList();
}

/// Predefined colors for user selection
class AppColorPalette {
  static const List<Color> colors = [
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFF6B6B), // Red
    Color(0xFFFFE66D), // Yellow
    Color(0xFFA66CFF), // Purple
    Color(0xFF95E1D3), // Mint
    Color(0xFFFF8E8E), // Pink
    Color(0xFF6BCB77), // Green
    Color(0xFF3D85C6), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Deep Purple
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  static Color getColor(int index) {
    return colors[index % colors.length];
  }
}
