import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../profile/profile_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiChatProvider>().loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final aiChatProvider = context.read<AiChatProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    // Check if API key is configured
    if (!aiChatProvider.isConfigured(userProvider.profile)) {
      _showApiKeyDialog();
      return;
    }

    _messageController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // Build financial context
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final financialContext = <String, dynamic>{
      'totalBalance': context.read<AccountProvider>().totalBalance,
      'monthlyIncome': transactionProvider.getTotalIncomeForRange(
        monthStart,
        monthEnd,
      ),
      'monthlyExpense': transactionProvider.getTotalExpenseForRange(
        monthStart,
        monthEnd,
      ),
      'topExpenseCategories': _getTopExpenseCategories(
        transactionProvider,
        categoryProvider,
        monthStart,
        monthEnd,
      ),
    };

    await aiChatProvider.sendMessage(
      message: message,
      apiKey: userProvider.profile.aiApiKey!,
      model: userProvider.profile.aiModel ?? AppConstants.defaultAiModel,
      financialContext: financialContext,
    );

    _scrollToBottom();

    // Check if there's a pending transaction
    if (aiChatProvider.hasPendingTransaction) {
      _showTransactionConfirmation(aiChatProvider.pendingTransaction!);
    }
  }

  List<Map<String, dynamic>> _getTopExpenseCategories(
    TransactionProvider transactionProvider,
    CategoryProvider categoryProvider,
    DateTime start,
    DateTime end,
  ) {
    final expenses = transactionProvider.getExpensesByCategory(
      start: start,
      end: end,
    );

    final sorted = expenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) {
      final category = categoryProvider.getCategoryById(e.key);
      return {'name': category?.name ?? 'Lainnya', 'amount': e.value};
    }).toList();
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan AI'),
        content: const Text(
          'Anda perlu memasukkan API Key OpenRouter untuk menggunakan fitur AI Chat.\n\n'
          'Silakan buka halaman Profil > Pengaturan AI untuk mengatur API Key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  void _showTransactionConfirmation(PendingTransaction transaction) {
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    // Get categories based on transaction type
    final categories = transaction.isIncome
        ? categoryProvider.incomeCategories
        : categoryProvider.expenseCategories;

    // Validate accounts exist
    if (accountProvider.accounts.isEmpty) {
      SnackBarHelper.showError(
        context,
        'Tidak ada akun tersedia. Silakan buat akun terlebih dahulu.',
      );
      context.read<AiChatProvider>().rejectTransaction();
      return;
    }

    // Initial selections
    String selectedAccountId = accountProvider.accounts.first.id;
    String selectedCategoryId = transaction.categoryId;

    // Validate category exists, fallback to first if not found
    if (!categories.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = categories.isNotEmpty ? categories.first.id : '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final selectedCategory = categoryProvider.getCategoryById(
            selectedCategoryId,
          );
          final selectedAccount = accountProvider.accounts.firstWhere(
            (a) => a.id == selectedAccountId,
            orElse: () => accountProvider.accounts.first,
          );

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  transaction.isIncome
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: transaction.isIncome
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  transaction.isIncome
                      ? 'Catat Pemasukan'
                      : 'Catat Pengeluaran',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  _buildConfirmationRow(
                    'Jumlah',
                    CurrencyFormatter.format(transaction.amount),
                  ),
                  const SizedBox(height: 16),

                  // Account Dropdown
                  const Text(
                    'Akun',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedAccountId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: accountProvider.accounts.map((account) {
                        return DropdownMenuItem<String>(
                          value: account.id,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.getIcon(
                                  account.icon ?? 'account_balance_wallet',
                                ),
                                size: 18,
                                color: Color(account.color ?? 0xFF9E9E9E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  account.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedAccountId = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  const Text(
                    'Kategori',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategoryId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.getIcon(category.icon),
                                size: 18,
                                color: Color(category.color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategoryId = value);
                        }
                      },
                    ),
                  ),

                  // Description
                  if (transaction.description != null) ...[
                    const SizedBox(height: 16),
                    _buildConfirmationRow(
                      'Deskripsi',
                      transaction.description!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Pastikan akun dan kategori sudah benar.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await this.context.read<AiChatProvider>().rejectTransaction();
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final success = await this.context
                      .read<AiChatProvider>()
                      .confirmTransaction(
                        transactionProvider: this.context
                            .read<TransactionProvider>(),
                        accountProvider: this.context.read<AccountProvider>(),
                        accountId: selectedAccountId,
                        categoryId: selectedCategoryId,
                      );
                  if (success && mounted) {
                    SnackBarHelper.showSuccess(
                      this.context,
                      'Transaksi berhasil dicatat ke ${selectedAccount.name}!',
                    );
                  }
                },
                child: const Text('Ya, Catat'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const Text(': '),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DuitAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await DialogHelper.showConfirmation(
                context,
                title: 'Hapus Riwayat?',
                message: 'Semua riwayat chat akan dihapus.',
                isDestructive: true,
              );
              if (confirm && mounted) {
                await context.read<AiChatProvider>().clearChat();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AiChatProvider>(
        builder: (context, aiChat, _) {
          if (aiChat.messages.isEmpty && !aiChat.isLoading) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Error banner
              if (aiChat.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppColors.error.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aiChat.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.error),
                        iconSize: 18,
                        onPressed: () => aiChat.clearError(),
                      ),
                    ],
                  ),
                ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      aiChat.messages.length + (aiChat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= aiChat.messages.length) {
                      return _buildLoadingIndicator();
                    }
                    return _buildMessageBubble(aiChat.messages[index]);
                  },
                ),
              ),

              // Input field
              _buildInputField(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Halo! Saya DuitAI 👋',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Asisten keuangan pribadi Anda.\nCatat pemasukan dan pengeluaran dengan mudah!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSuggestionChip('Beli makan 50rb'),
                      _buildSuggestionChip('Gajian 5 juta'),
                      _buildSuggestionChip('Analisa pengeluaran'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildInputField(),
      ],
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 16,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 16,
              child: const Icon(Icons.person, size: 18, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 16,
            child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[400],
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<AiChatProvider>(
            builder: (context, aiChat, _) {
              return FloatingActionButton(
                onPressed: aiChat.isLoading ? null : _sendMessage,
                mini: true,
                child: aiChat.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              );
            },
          ),
        ],
      ),
    );
  }
}
