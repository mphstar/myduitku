import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'account_provider.dart';
import 'budget_provider.dart';
import 'category_provider.dart';
import 'goal_provider.dart';
import 'transaction_provider.dart';

/// Provider for managing AI chat state
class AiChatProvider extends ChangeNotifier {
  final AiService _aiService = AiService();
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  PendingAction? _pendingAction;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PendingAction? get pendingAction => _pendingAction;
  bool get hasPendingAction => _pendingAction != null;

  /// Load chat history from database
  Future<void> loadMessages() async {
    _messages = _db.getChatMessages();
    notifyListeners();
  }

  /// Send message to AI with automatic execution for transactions and confirmation for master data
  Future<void> sendMessage({
    required String message,
    required String apiKey,
    required String model,
    String? imageBase64,
    String? customBaseUrl,
    Map<String, dynamic>? financialContext,
    required TransactionProvider transactionProvider,
    required AccountProvider accountProvider,
    required CategoryProvider categoryProvider,
  }) async {
    if (message.trim().isEmpty && (imageBase64 == null || imageBase64.isEmpty)) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: message,
      role: ChatRole.user,
      imageBase64: imageBase64,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    await _db.saveChatMessage(userMessage);
    notifyListeners();

    // Build message history for context (last 10 messages)
    final historyMessages = _messages
        .where((m) => m.role != ChatRole.system && m.id != userMessage.id)
        .take(10)
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList();

    // Send to OpenAI-compatible AI endpoint
    final response = await _aiService.sendMessage(
      apiKey: apiKey,
      model: model,
      imageBase64: imageBase64,
      customBaseUrl: customBaseUrl,
      messages: historyMessages,
      userMessage: message,
      financialContext: financialContext,
    );

    if (response.success && response.content != null) {
      // Clean content for display
      final cleanContent = _aiService.cleanResponseContent(response.content!);

      // If AI produced transactions, execute them directly without dialog!
      final executedActions = <ExecutedActionItem>[];
      if (response.parsedTransactions != null &&
          response.parsedTransactions!.isNotEmpty) {
        for (final tx in response.parsedTransactions!) {
          final recorded = await _executeParsedTransaction(
            tx: tx,
            transactionProvider: transactionProvider,
            accountProvider: accountProvider,
            categoryProvider: categoryProvider,
          );
          if (recorded != null) {
            executedActions.addAll(recorded);
          }
        }
      }

      final assistantMessage = ChatMessage(
        id: _uuid.v4(),
        content: cleanContent,
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
        pendingAction: response.pendingAction,
        executedActions:
            executedActions.isNotEmpty ? executedActions : null,
      );

      _messages.add(assistantMessage);
      await _db.saveChatMessage(assistantMessage);

      // Set pending action (Budget/Account/Goal creation) if any
      _pendingAction = response.pendingAction;
    } else {
      _error = response.error ?? 'Terjadi kesalahan tidak diketahui';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Automatically record transaction(s) or transfer
  Future<List<ExecutedActionItem>?> _executeParsedTransaction({
    required AiParsedTransaction tx,
    required TransactionProvider transactionProvider,
    required AccountProvider accountProvider,
    required CategoryProvider categoryProvider,
  }) async {
    try {
      if (tx.isTransfer) {
        // Case: Transfer / Penarikan dana (Two processes handled simultaneously)
        // Find or match fromAccount and toAccount
        final fromAcc = _findOrCreateAccount(
          name: tx.fromAccount ?? 'BCA',
          accountProvider: accountProvider,
          defaultType: AccountType.bank,
        );
        final toAcc = _findOrCreateAccount(
          name: tx.toAccount ?? 'Cash',
          accountProvider: accountProvider,
          defaultType: AccountType.cash,
        );

        final fromAccFinal = await fromAcc;
        final toAccFinal = await toAcc;

        // 1. Expense from source account
        final expenseDesc = tx.description != null && tx.description!.isNotEmpty
            ? tx.description!
            : 'Transfer / Tarik ke ${toAccFinal.name}';
        final expenseCategory = categoryProvider.expenseCategories.isNotEmpty
            ? categoryProvider.expenseCategories.first.id
            : 'cat_other_expense';

        final expenseTx = await transactionProvider.addTransaction(
          amount: tx.amount,
          type: TransactionType.expense,
          categoryId: expenseCategory,
          accountId: fromAccFinal.id,
          description: expenseDesc,
          date: DateTime.now(),
        );
        await accountProvider.updateBalance(
          fromAccFinal.id,
          tx.amount,
          TransactionType.expense,
        );

        // 2. Income to target account
        final incomeDesc = tx.description != null && tx.description!.isNotEmpty
            ? tx.description!
            : 'Transfer / Masuk dari ${fromAccFinal.name}';
        final incomeCategory = categoryProvider.incomeCategories.isNotEmpty
            ? categoryProvider.incomeCategories.first.id
            : 'cat_other_income';

        final incomeTx = await transactionProvider.addTransaction(
          amount: tx.amount,
          type: TransactionType.income,
          categoryId: incomeCategory,
          accountId: toAccFinal.id,
          description: incomeDesc,
          date: DateTime.now(),
        );
        await accountProvider.updateBalance(
          toAccFinal.id,
          tx.amount,
          TransactionType.income,
        );

        return [
          ExecutedActionItem(
            id: _uuid.v4(),
            type: 'transfer',
            title: 'Tarik / Transfer: ${fromAccFinal.name} ➔ ${toAccFinal.name}',
            subtitle: tx.description ?? 'Penarikan / Transfer dana',
            amount: tx.amount,
            isIncome: false,
            transactionId: expenseTx.id,
            relatedTransactionId: incomeTx.id,
          ),
        ];
      } else {
        // Standard single income/expense transaction
        final targetAcc = await _findOrCreateAccount(
          name: tx.accountName ?? 'Cash',
          accountProvider: accountProvider,
          defaultType: AccountType.cash,
        );

        final isIncome = tx.isIncome;
        String chosenCategoryId = tx.categoryId ?? '';
        final categories = isIncome
            ? categoryProvider.incomeCategories
            : categoryProvider.expenseCategories;

        if (!categories.any((c) => c.id == chosenCategoryId)) {
          chosenCategoryId = categories.isNotEmpty
              ? categories.first.id
              : (isIncome ? 'cat_other_income' : 'cat_other_expense');
        }

        final categoryObj = categoryProvider.getCategoryById(chosenCategoryId);

        final recordedTx = await transactionProvider.addTransaction(
          amount: tx.amount,
          type: isIncome ? TransactionType.income : TransactionType.expense,
          categoryId: chosenCategoryId,
          accountId: targetAcc.id,
          description: tx.description,
          date: DateTime.now(),
        );

        await accountProvider.updateBalance(
          targetAcc.id,
          tx.amount,
          isIncome ? TransactionType.income : TransactionType.expense,
        );

        return [
          ExecutedActionItem(
            id: _uuid.v4(),
            type: 'transaction',
            title: isIncome ? 'Pemasukan Dicatat' : 'Pengeluaran Dicatat',
            subtitle:
                '${categoryObj?.name ?? "Transaksi"} (${targetAcc.name})${tx.description != null ? ' - ${tx.description}' : ''}',
            amount: tx.amount,
            isIncome: isIncome,
            transactionId: recordedTx.id,
          ),
        ];
      }
    } catch (e) {
      debugPrint('Error executing AI transaction: $e');
      return null;
    }
  }

  /// Helper to match or create account if not found
  Future<Account> _findOrCreateAccount({
    required String name,
    required AccountProvider accountProvider,
    required AccountType defaultType,
  }) async {
    final cleanName = name.trim();
    for (final acc in accountProvider.accounts) {
      if (acc.name.toLowerCase() == cleanName.toLowerCase() ||
          acc.name.toLowerCase().contains(cleanName.toLowerCase()) ||
          cleanName.toLowerCase().contains(acc.name.toLowerCase())) {
        return acc;
      }
    }

    // Auto create if named account doesn't exist
    final created = await accountProvider.addAccount(
      name: cleanName.isNotEmpty ? cleanName : 'Dompet Utama',
      type: defaultType,
      balance: 0,
      icon: defaultType == AccountType.cash ? 'account_balance_wallet' : 'account_balance',
      color: defaultType == AccountType.cash ? 0xFF00B8A9 : 0xFF2196F3,
    );
    return created;
  }

  /// Undo / delete an automatically recorded transaction action
  Future<bool> undoExecutedAction({
    required ExecutedActionItem item,
    required TransactionProvider transactionProvider,
    required AccountProvider accountProvider,
  }) async {
    try {
      if (item.transactionId != null) {
        final tx1 = transactionProvider.getTransactionById(item.transactionId!);
        if (tx1 != null) {
          await accountProvider.revertBalance(tx1.accountId, tx1.amount, tx1.type);
          await transactionProvider.deleteTransaction(tx1.id);
        }
      }

      if (item.relatedTransactionId != null) {
        final tx2 = transactionProvider.getTransactionById(item.relatedTransactionId!);
        if (tx2 != null) {
          await accountProvider.revertBalance(tx2.accountId, tx2.amount, tx2.type);
          await transactionProvider.deleteTransaction(tx2.id);
        }
      }

      // Update message state removing or marking executed action
      for (int i = 0; i < _messages.length; i++) {
        final msg = _messages[i];
        if (msg.executedActions != null) {
          final updatedList = msg.executedActions!
              .where((a) => a.id != item.id)
              .toList();
          final newMsg = msg.copyWith(
            executedActions: updatedList,
          );
          _messages[i] = newMsg;
          await _db.saveChatMessage(newMsg);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal membatalkan transaksi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Confirm and execute master data creation (Budget, Account, Goal, Category)
  Future<bool> confirmPendingAction({
    required BudgetProvider budgetProvider,
    required AccountProvider accountProvider,
    required GoalProvider goalProvider,
    required CategoryProvider categoryProvider,
  }) async {
    if (_pendingAction == null) return false;

    try {
      final action = _pendingAction!;
      final data = action.data;

      if (action.actionType == 'create_budget') {
        final categoryId = data['categoryId'] as String? ?? 'cat_food';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final periodStr = data['period'] as String? ?? 'monthly';
        final period = BudgetPeriod.values.firstWhere(
          (p) => p.name.toLowerCase() == periodStr.toLowerCase(),
          orElse: () => BudgetPeriod.monthly,
        );

        await budgetProvider.addBudget(
          categoryId: categoryId,
          amount: amount,
          period: period,
          startDate: DateTime.now(),
        );
      } else if (action.actionType == 'create_account') {
        final name = data['name'] as String? ?? 'Akun Baru';
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        final typeStr = data['type'] as String? ?? 'bank';
        final type = AccountType.values.firstWhere(
          (t) => t.name.toLowerCase() == typeStr.toLowerCase(),
          orElse: () => AccountType.bank,
        );

        await accountProvider.addAccount(
          name: name,
          type: type,
          balance: balance,
        );
      } else if (action.actionType == 'create_goal') {
        final name = data['name'] as String? ?? 'Target Tabungan';
        final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final deadlineStr = data['deadline'] as String?;
        final deadline = deadlineStr != null
            ? DateTime.tryParse(deadlineStr) ?? DateTime.now().add(const Duration(days: 90))
            : DateTime.now().add(const Duration(days: 90));

        await goalProvider.addGoal(
          name: name,
          targetAmount: targetAmount,
          deadline: deadline,
        );
      } else if (action.actionType == 'create_category') {
        final name = data['name'] as String? ?? 'Kategori Baru';
        final typeStr = data['type'] as String? ?? 'expense';
        final type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;

        await categoryProvider.addCategory(
          name: name,
          icon: 'category',
          color: 0xFF00B8A9,
          type: type,
        );
      }

      // Add assistant confirmation feedback message
      final confirmMessage = ChatMessage(
        id: _uuid.v4(),
        content: '✅ Berhasil dibuat: ${action.summary}',
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );
      _messages.add(confirmMessage);
      await _db.saveChatMessage(confirmMessage);

      _pendingAction = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal memproses aksi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Reject pending master data action
  Future<void> rejectPendingAction() async {
    if (_pendingAction == null) return;

    final rejectMessage = ChatMessage(
      id: _uuid.v4(),
      content: '❌ Pembuatan data dibatalkan.',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    );
    _messages.add(rejectMessage);
    await _db.saveChatMessage(rejectMessage);

    _pendingAction = null;
    notifyListeners();
  }

  /// Clear all chat messages
  Future<void> clearChat() async {
    await _db.clearChatMessages();
    _messages.clear();
    _pendingAction = null;
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
    if (modelId == null || modelId.trim().isEmpty) return AppConstants.defaultAiModel;
    return modelId;
  }
}
