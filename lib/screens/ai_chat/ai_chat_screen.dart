import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/user_avatar.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedImageBase64;
  Uint8List? _selectedImageBytes;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        if (source == ImageSource.camera) {
          final status = await Permission.camera.request();
          if (status.isPermanentlyDenied) {
            openAppSettings();
            return;
          }
        }
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageBase64 = base64Encode(bytes);
        });
      }
    } catch (_) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result != null &&
            result.files.isNotEmpty &&
            result.files.first.bytes != null) {
          final bytes = result.files.first.bytes!;
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageBase64 = base64Encode(bytes);
          });
        }
      } catch (_) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Gagal memilih gambar.');
        }
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Kirim Gambar / Struk',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Ambil Foto Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.secondary),
              ),
              title: const Text('Pilih dari Galeri / File'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final image = _selectedImageBase64;
    if (message.isEmpty && image == null) return;

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
    setState(() {
      _selectedImageBase64 = null;
      _selectedImageBytes = null;
    });
    _focusNode.unfocus();
    _scrollToBottom();

    // Build financial context
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    final accountProvider = context.read<AccountProvider>();

    // Helper to format a transaction for AI context
    Map<String, dynamic> formatTx(transaction) {
      final category = categoryProvider.getCategoryById(transaction.categoryId);
      final account = accountProvider.getAccountById(transaction.accountId);
      return {
        'type': transaction.type == TransactionType.income
            ? 'pemasukan'
            : 'pengeluaran',
        'amount': transaction.amount,
        'category': category?.name ?? 'Lainnya',
        'account': account?.name ?? '-',
        'description': transaction.description ?? '-',
        'date':
            '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
        'time':
            '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
      };
    }

    // Get ALL transactions this month (for answering any date question)
    final thisMonthTransactions = transactionProvider.allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ) &&
              t.date.isBefore(monthEnd.add(const Duration(days: 1))),
        )
        .map(formatTx)
        .toList();

    // Get last month summary + transactions
    final lastMonthTransactions = transactionProvider.allTransactions
        .where(
          (t) =>
              t.date.isAfter(
                lastMonthStart.subtract(const Duration(seconds: 1)),
              ) &&
              t.date.isBefore(lastMonthEnd.add(const Duration(days: 1))),
        )
        .map(formatTx)
        .toList();

    // Get account details
    final accountDetails = accountProvider.accounts.map((a) => {
      'name': a.name,
      'type': a.type.displayName,
      'balance': a.balance,
    }).toList();

    final financialContext = <String, dynamic>{
      'totalBalance': accountProvider.totalBalance,
      'currentDate': '${now.day}/${now.month}/${now.year}',
      'monthlyIncome': transactionProvider.getTotalIncomeForRange(
        monthStart,
        monthEnd,
      ),
      'monthlyExpense': transactionProvider.getTotalExpenseForRange(
        monthStart,
        monthEnd,
      ),
      'thisMonthTransactions': thisMonthTransactions,
      'lastMonthIncome': transactionProvider.getTotalIncomeForRange(
        lastMonthStart,
        lastMonthEnd,
      ),
      'lastMonthExpense': transactionProvider.getTotalExpenseForRange(
        lastMonthStart,
        lastMonthEnd,
      ),
      'lastMonthTransactions': lastMonthTransactions,
      'accounts': accountDetails,
    };

    await aiChatProvider.sendMessage(
      message: message,
      apiKey: userProvider.profile.aiApiKey!,
      model: userProvider.profile.aiModel ?? AppConstants.defaultAiModel,
      imageBase64: image,
      customBaseUrl: userProvider.profile.aiCustomBaseUrl,
      financialContext: financialContext,
      transactionProvider: transactionProvider,
      accountProvider: accountProvider,
      categoryProvider: categoryProvider,
    );

    _scrollToBottom();

    // Check if there is any pending action for master data (Budget, Account, Goal, Category)
    if (aiChatProvider.hasPendingAction) {
      _showMasterDataConfirmation(aiChatProvider.pendingAction!);
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan AI'),
        content: const Text(
          'Anda perlu mengatur API Key AI provider untuk menggunakan fitur AI Chat.\n\n'
          'Silakan buka halaman Profil > Pengaturan AI untuk mengatur provider dan API Key.',
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

  void _showMasterDataConfirmation(PendingAction action) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Konfirmasi Pembuatan Data',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.summary,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI meminta izin untuk membuat data di atas ke akun Anda. Setujui untuk memproses.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await this.context.read<AiChatProvider>().rejectPendingAction();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final success = await this.context
                          .read<AiChatProvider>()
                          .confirmPendingAction(
                            budgetProvider: this.context.read<BudgetProvider>(),
                            accountProvider: this.context.read<AccountProvider>(),
                            goalProvider: this.context.read<GoalProvider>(),
                            categoryProvider: this.context.read<CategoryProvider>(),
                          );
                      if (success && mounted) {
                        SnackBarHelper.showSuccess(
                          this.context,
                          'Data berhasil dibuat!',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Setujui & Buat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionSheet(ExecutedActionItem item) {
    if (item.transactionId == null) return;
    final txProvider = context.read<TransactionProvider>();
    final accountProvider = context.read<AccountProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    final tx = txProvider.getTransactionById(item.transactionId!);
    if (tx == null) {
      SnackBarHelper.showError(context, 'Transaksi tidak ditemukan atau sudah dihapus.');
      return;
    }

    final amountController = TextEditingController(
      text: tx.amount.toStringAsFixed(0),
    );
    final descController = TextEditingController(
      text: tx.description ?? '',
    );
    String selectedAccountId = tx.accountId;
    String selectedCategoryId = tx.categoryId;
    TransactionType selectedType = tx.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setState) {
          final categories = selectedType == TransactionType.income
              ? categoryProvider.incomeCategories
              : categoryProvider.expenseCategories;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Koreksi / Edit Transaksi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: accountProvider.accounts.any((a) => a.id == selectedAccountId)
                        ? selectedAccountId
                        : (accountProvider.accounts.isNotEmpty ? accountProvider.accounts.first.id : null),
                    decoration: const InputDecoration(labelText: 'Akun / Rekening'),
                    items: accountProvider.accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name} (${CurrencyFormatter.format(a.balance)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedAccountId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categories.any((c) => c.id == selectedCategoryId)
                        ? selectedCategoryId
                        : (categories.isNotEmpty ? categories.first.id : null),
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCategoryId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi / Catatan',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final newAmount = double.tryParse(
                              amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                            ) ?? tx.amount;

                            // Revert previous balance impact
                            await accountProvider.revertBalance(tx.accountId, tx.amount, tx.type);

                            // Update transaction
                            final updatedTx = tx.copyWith(
                              amount: newAmount,
                              accountId: selectedAccountId,
                              categoryId: selectedCategoryId,
                              description: descController.text.trim(),
                            );
                            await txProvider.updateTransaction(updatedTx);

                            // Apply new balance impact
                            await accountProvider.updateBalance(
                              selectedAccountId,
                              newAmount,
                              selectedType,
                            );

                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                              SnackBarHelper.showSuccess(
                                this.context,
                                'Transaksi berhasil dikoreksi!',
                              );
                            }
                          },
                          child: const Text('Simpan Koreksi'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Account?> _showInlineAddAccount(BuildContext context) async {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    AccountType selectedType = AccountType.bank;

    return showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Akun / Rekening Baru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Akun',
                  hintText: 'Contoh: BCA, Mandiri, Cash, QRIS',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      SnackBarHelper.showError(context, 'Nama akun harus diisi');
                      return;
                    }
                    final balance = double.tryParse(
                          balanceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                        ) ??
                        0;

                    final acc = await context.read<AccountProvider>().addAccount(
                          name: name,
                          type: selectedType,
                          balance: balance,
                          icon: 'account_balance_wallet',
                          color: 0xFF00B8A9,
                        );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx, acc);
                      SnackBarHelper.showSuccess(
                        context,
                        'Akun "$name" berhasil dibuat',
                      );
                    }
                  },
                  child: const Text('Simpan Akun'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            final model = userProvider.profile.aiModel ?? 'DuitAI';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('DuitAI Assistant'),
                Text(
                  model,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus Chat',
            onPressed: () async {
              final confirm = await DialogHelper.showConfirmation(
                context,
                title: 'Hapus Chat?',
                message: 'Semua riwayat percakapan akan dihapus.',
                isDestructive: true,
              );
              if (confirm && context.mounted) {
                await context.read<AiChatProvider>().clearChat();
              }
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                    'Asisten keuangan pribadi Anda.\nKirim teks atau foto struk untuk mencatat otomatis!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSuggestionChip('Beli makan 50rb BCA'),
                      _buildSuggestionChip('Gajian 5 juta'),
                      _buildSuggestionChip('Analisa pengeluaran bulan ini'),
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
    final primaryColor = Theme.of(context).primaryColor;
    final userName = context.read<UserProvider>().profile.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: primaryColor,
              radius: 16,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageBase64 != null &&
                      message.imageBase64!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(message.imageBase64!),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.content.isNotEmpty) ...[
                    if (isUser)
                      SelectableText(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      )
                    else
                      MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          strong: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          code: TextStyle(
                            backgroundColor: Colors.grey.shade200,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          listBullet: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    // Quick Copy message button
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: message.content),
                          );
                          SnackBarHelper.showSuccess(
                            context,
                            'Teks pesan berhasil disalin!',
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Render executed transactions with action buttons (Edit / Koreksi & Batalkan)
                  if (!isUser &&
                      message.executedActions != null &&
                      message.executedActions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...message.executedActions!.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: item.isIncome
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (item.transactionId != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showEditTransactionSheet(item),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 14),
                                    label: const Text(
                                      'Koreksi / Edit',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () async {
                                    final confirm =
                                        await DialogHelper.showConfirmation(
                                      context,
                                      title: 'Batalkan Transaksi?',
                                      message:
                                          'Transaksi sebesar ${CurrencyFormatter.format(item.amount)} akan dihapus dan saldo dikembalikan.',
                                      isDestructive: true,
                                    );
                                    if (confirm && context.mounted) {
                                      final success = await context
                                          .read<AiChatProvider>()
                                          .undoExecutedAction(
                                            item: item,
                                            transactionProvider: context
                                                .read<TransactionProvider>(),
                                            accountProvider: context
                                                .read<AccountProvider>(),
                                          );
                                      if (success && context.mounted) {
                                        SnackBarHelper.showSuccess(
                                          context,
                                          'Transaksi berhasil dibatalkan!',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      size: 14, color: AppColors.error),
                                  label: const Text(
                                    'Batalkan',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.error),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            UserAvatar(
              name: userName,
              radius: 16,
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
          const CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 16,
            child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
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
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Preview thumbnail before sending
          if (_selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _selectedImageBytes!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImageBase64 = null;
                              _selectedImageBytes = null;
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Foto struk/gambar siap dikirim ke AI',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Media button (Camera / Gallery / Files)
              IconButton(
                icon: Icon(Icons.camera_alt_outlined,
                    color: Theme.of(context).primaryColor),
                onPressed: _showImagePickerSheet,
                tooltip: 'Kirim Struk / Gambar',
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _selectedImageBytes != null
                        ? 'Tambah catatan (opsional)...'
                        : 'Ketik pesan transaksi...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.send_rounded, color: Theme.of(context).primaryColor),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
