import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'account_provider.dart';
import 'transaction_provider.dart';

/// Provider for managing AI chat state
class AiChatProvider extends ChangeNotifier {
  final OpenRouterService _openRouter = OpenRouterService();
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  PendingTransaction? _pendingTransaction;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PendingTransaction? get pendingTransaction => _pendingTransaction;
  bool get hasPendingTransaction => _pendingTransaction != null;

  /// Load chat history from database
  Future<void> loadMessages() async {
    _messages = _db.getChatMessages();
    notifyListeners();
  }

  /// Send message to AI
  Future<void> sendMessage({
    required String message,
    required String apiKey,
    required String model,
    Map<String, dynamic>? financialContext,
  }) async {
    if (message.trim().isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: message,
      role: ChatRole.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    await _db.saveChatMessage(userMessage);
    notifyListeners();

    // Build message history for context (last 10 messages)
    final historyMessages = _messages
        .where((m) => m.role != ChatRole.system)
        .take(10)
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList();

    // Send to OpenRouter
    final response = await _openRouter.sendMessage(
      apiKey: apiKey,
      model: model,
      messages: historyMessages.cast<Map<String, String>>(),
      userMessage: message,
      financialContext: financialContext,
    );

    if (response.success && response.content != null) {
      // Clean content for display
      final cleanContent = _openRouter.cleanResponseContent(response.content!);

      final assistantMessage = ChatMessage(
        id: _uuid.v4(),
        content: cleanContent,
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
        pendingTransaction: response.pendingTransaction,
      );
      _messages.add(assistantMessage);
      await _db.saveChatMessage(assistantMessage);

      // Store pending transaction if exists
      if (response.pendingTransaction != null) {
        _pendingTransaction = response.pendingTransaction;
      }
    } else {
      _error = response.error ?? 'Terjadi kesalahan tidak diketahui';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Confirm pending transaction with selected account and category
  Future<bool> confirmTransaction({
    required TransactionProvider transactionProvider,
    required AccountProvider accountProvider,
    required String accountId,
    required String categoryId,
  }) async {
    if (_pendingTransaction == null) return false;

    try {
      // Add transaction with user-selected account and category
      await transactionProvider.addTransaction(
        amount: _pendingTransaction!.amount,
        type: _pendingTransaction!.isIncome
            ? TransactionType.income
            : TransactionType.expense,
        categoryId: categoryId,
        accountId: accountId,
        description: _pendingTransaction!.description,
        date: DateTime.now(),
      );

      // Update account balance
      await accountProvider.updateBalance(
        accountId,
        _pendingTransaction!.amount,
        _pendingTransaction!.isIncome
            ? TransactionType.income
            : TransactionType.expense,
      );

      // Add confirmation message
      final confirmMessage = ChatMessage(
        id: _uuid.v4(),
        content: '✅ Transaksi berhasil dicatat!',
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );
      _messages.add(confirmMessage);
      await _db.saveChatMessage(confirmMessage);

      _pendingTransaction = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal menyimpan transaksi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Reject pending transaction
  Future<void> rejectTransaction() async {
    if (_pendingTransaction == null) return;

    // Add rejection message
    final rejectMessage = ChatMessage(
      id: _uuid.v4(),
      content: '❌ Transaksi dibatalkan.',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    );
    _messages.add(rejectMessage);
    await _db.saveChatMessage(rejectMessage);

    _pendingTransaction = null;
    notifyListeners();
  }

  /// Clear all chat messages
  Future<void> clearChat() async {
    await _db.clearChatMessages();
    _messages.clear();
    _pendingTransaction = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if AI is configured
  bool isConfigured(UserProfile profile) {
    return profile.aiApiKey != null && profile.aiApiKey!.isNotEmpty;
  }

  /// Get model name from ID
  String getModelName(String? modelId) {
    if (modelId == null) return 'Default';
    final model = AppConstants.availableAiModels.firstWhere(
      (m) => m['id'] == modelId,
      orElse: () => {'name': modelId},
    );
    return model['name'] ?? modelId;
  }
}
