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
  static const String aiApiKeyKey = 'ai_api_key';
  static const String aiModelKey = 'ai_model';
  static const String aiProviderKey = 'ai_provider';
  static const String defaultAiProvider = 'openrouter';
  static const String defaultAiModel = 'google/gemini-2.0-flash-001';

  // AI Providers
  static const List<Map<String, String>> aiProviders = [
    {
      'id': 'openrouter',
      'name': 'OpenRouter',
      'baseUrl': 'https://openrouter.ai/api/v1/chat/completions',
      'hint': 'Akses 100+ model AI dalam satu API key',
      'website': 'https://openrouter.ai',
    },
    {
      'id': 'openai',
      'name': 'OpenAI',
      'baseUrl': 'https://api.openai.com/v1/chat/completions',
      'hint': 'GPT-5.5, GPT-5.4, GPT-5.4 Mini, dll.',
      'website': 'https://platform.openai.com',
    },
    {
      'id': 'anthropic',
      'name': 'Anthropic',
      'baseUrl': 'https://api.anthropic.com/v1/messages',
      'hint': 'Claude Opus 4.7, Claude Sonnet 4.6, dll.',
      'website': 'https://console.anthropic.com',
    },
    {
      'id': 'custom',
      'name': 'Custom (OpenAI-Compatible)',
      'baseUrl': '',
      'hint': 'DeepSeek, Groq, Together AI, atau server API custom lainnya',
      'website': '',
    },
  ];

  /// Get provider config by ID
  static Map<String, String> getProviderConfig(String? providerId) {
    return aiProviders.firstWhere(
      (p) => p['id'] == providerId,
      orElse: () => aiProviders.first,
    );
  }

  /// Get base URL for a provider
  static String getProviderBaseUrl(String? providerId,
      {String? customBaseUrl}) {
    if (providerId == 'custom' && customBaseUrl != null) {
      String url = customBaseUrl.trimRight();
      // Remove trailing slash
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      // Auto-append /v1/chat/completions if user only entered base URL
      if (!url.contains('/chat/completions')) {
        url = '$url/v1/chat/completions';
      }
      return url;
    }
    return getProviderConfig(providerId)['baseUrl']!;
  }

  // Available AI models per provider
  static const Map<String, List<Map<String, String>>> providerModels = {
    'openrouter': [
      {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash'},
      {'id': 'google/gemini-pro', 'name': 'Gemini Pro'},
      {'id': 'anthropic/claude-sonnet-4-6', 'name': 'Claude Sonnet 4.6'},
      {'id': 'anthropic/claude-opus-4-6', 'name': 'Claude Opus 4.6'},
      {'id': 'openai/gpt-5.4', 'name': 'GPT-5.4'},
      {'id': 'openai/gpt-5.4-mini', 'name': 'GPT-5.4 Mini'},
      {'id': 'deepseek/deepseek-v4-flash', 'name': 'DeepSeek V4 Flash'},
      {'id': 'deepseek/deepseek-v4-pro', 'name': 'DeepSeek V4 Pro'},
      {'id': 'meta-llama/llama-3.1-8b-instruct', 'name': 'Llama 3.1 8B'},
    ],
    'openai': [
      {'id': 'gpt-5.5', 'name': 'GPT-5.5'},
      {'id': 'gpt-5.4', 'name': 'GPT-5.4'},
      {'id': 'gpt-5.4-mini', 'name': 'GPT-5.4 Mini'},
      {'id': 'gpt-5.4-nano', 'name': 'GPT-5.4 Nano'},
    ],
    'anthropic': [
      {'id': 'claude-opus-4-7', 'name': 'Claude Opus 4.7'},
      {'id': 'claude-opus-4-6', 'name': 'Claude Opus 4.6'},
      {'id': 'claude-sonnet-4-6', 'name': 'Claude Sonnet 4.6'},
    ],
    'custom': [
      {'id': 'deepseek-v4-flash', 'name': 'DeepSeek V4 Flash'},
      {'id': 'deepseek-v4-pro', 'name': 'DeepSeek V4 Pro'},
      {'id': 'deepseek-chat', 'name': 'DeepSeek Chat (Legacy)'},
      {'id': 'deepseek-reasoner', 'name': 'DeepSeek Reasoner (Legacy)'},
    ],
  };

  /// Get models for a specific provider
  static List<Map<String, String>> getModelsForProvider(String? providerId) {
    return providerModels[providerId ?? defaultAiProvider] ?? [];
  }

  /// Get default model for a provider
  static String getDefaultModelForProvider(String? providerId) {
    final models = getModelsForProvider(providerId);
    if (models.isNotEmpty) return models.first['id']!;
    return defaultAiModel;
  }
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
