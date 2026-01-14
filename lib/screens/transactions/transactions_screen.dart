import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

/// Transactions list screen
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CategoryProvider>().loadCategories();
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<TransactionProvider>().setSearchQuery(
                            '',
                          );
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                context.read<TransactionProvider>().setSearchQuery(value);
              },
            ),
          ),

          // Transaction list
          Expanded(
            child:
                Consumer3<
                  TransactionProvider,
                  CategoryProvider,
                  AccountProvider
                >(
                  builder:
                      (
                        context,
                        transactionProvider,
                        categoryProvider,
                        accountProvider,
                        _,
                      ) {
                        if (transactionProvider.isLoading) {
                          return const LoadingWidget();
                        }

                        if (transactionProvider.transactions.isEmpty) {
                          return EmptyStateWidget(
                            icon: Icons.receipt_long_outlined,
                            title: 'Belum ada transaksi',
                            subtitle: 'Tambahkan transaksi pertama Anda',
                            buttonText: 'Tambah Transaksi',
                            onButtonPressed: () =>
                                _showAddTransactionSheet(context),
                          );
                        }

                        // Group by date
                        final grouped = _groupByDate(
                          transactionProvider.transactions,
                        );

                        return RefreshIndicator(
                          onRefresh: () =>
                              transactionProvider.loadTransactions(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: grouped.length,
                            itemBuilder: (context, index) {
                              final dateKey = grouped.keys.elementAt(index);
                              final transactions = grouped[dateKey]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      dateKey,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  ...transactions.map((transaction) {
                                    final category = categoryProvider
                                        .getCategoryById(
                                          transaction.categoryId,
                                        );
                                    final account = accountProvider
                                        .getAccountById(transaction.accountId);
                                    return _buildTransactionTile(
                                      context,
                                      transaction,
                                      category,
                                      account,
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        );
                      },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    for (final transaction in transactions) {
      final dateKey = DateFormatter.formatRelative(transaction.date);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(transaction);
    }
    return grouped;
  }

  Widget _buildTransactionTile(
    BuildContext context,
    Transaction transaction,
    Category? category,
    Account? account,
  ) {
    final isExpense = transaction.type == TransactionType.expense;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: category != null
                ? Color(category.color).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.getIcon(category?.icon ?? 'more_horiz'),
            color: category != null ? Color(category.color) : Colors.grey,
            size: 24,
          ),
        ),
        title: Text(
          category?.name ?? 'Kategori',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.description?.isNotEmpty ?? false)
              Text(
                transaction.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              account?.name ?? 'Akun',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isExpense ? AppColors.expense : AppColors.income,
          ),
        ),
        onTap: () =>
            _showTransactionDetails(context, transaction, category, account),
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    Transaction transaction,
    Category? category,
    Account? account,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              transaction.type == TransactionType.expense
                  ? 'Pengeluaran'
                  : 'Pemasukan',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              'Jumlah',
              CurrencyFormatter.format(transaction.amount),
            ),
            _buildDetailRow('Kategori', category?.name ?? '-'),
            _buildDetailRow('Akun', account?.name ?? '-'),
            _buildDetailRow(
              'Tanggal',
              DateFormatter.formatDate(transaction.date),
            ),
            if (transaction.description?.isNotEmpty ?? false)
              _buildDetailRow('Catatan', transaction.description!),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final confirm = await DialogHelper.showConfirmation(
                        context,
                        title: 'Hapus Transaksi?',
                        message: 'Tindakan ini tidak dapat dibatalkan.',
                        isDestructive: true,
                      );
                      if (confirm && context.mounted) {
                        // Revert balance
                        await context.read<AccountProvider>().revertBalance(
                          transaction.accountId,
                          transaction.amount,
                          transaction.type,
                        );
                        await context
                            .read<TransactionProvider>()
                            .deleteTransaction(transaction.id);
                        if (context.mounted) {
                          SnackBarHelper.showSuccess(
                            context,
                            'Transaksi dihapus',
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      provider.clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Jenis Transaksi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip(
                    'Semua',
                    null,
                    () => provider.setTypeFilter(null),
                  ),
                  _buildFilterChip(
                    'Pemasukan',
                    TransactionType.income,
                    () => provider.setTypeFilter(TransactionType.income),
                  ),
                  _buildFilterChip(
                    'Pengeluaran',
                    TransactionType.expense,
                    () => provider.setTypeFilter(TransactionType.expense),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Terapkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    TransactionType? type,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    TransactionType selectedType = TransactionType.expense;
    String? selectedCategoryId;
    String? selectedAccountId;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) =>
            Consumer2<CategoryProvider, AccountProvider>(
              builder: (context, categoryProvider, accountProvider, _) {
                final categories = selectedType == TransactionType.expense
                    ? categoryProvider.expenseCategories
                    : categoryProvider.incomeCategories;
                final accounts = accountProvider.accounts;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
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
                        const SizedBox(height: 20),
                        Text(
                          'Tambah Transaksi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Type selector
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = TransactionType.expense;
                                    selectedCategoryId = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        selectedType == TransactionType.expense
                                        ? AppColors.expense.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          selectedType ==
                                              TransactionType.expense
                                          ? AppColors.expense
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Pengeluaran',
                                      style: TextStyle(
                                        color:
                                            selectedType ==
                                                TransactionType.expense
                                            ? AppColors.expense
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = TransactionType.income;
                                    selectedCategoryId = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        selectedType == TransactionType.income
                                        ? AppColors.income.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          selectedType == TransactionType.income
                                          ? AppColors.income
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Pemasukan',
                                      style: TextStyle(
                                        color:
                                            selectedType ==
                                                TransactionType.income
                                            ? AppColors.income
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Amount
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            prefixText: 'Rp ',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category
                        Text(
                          'Kategori',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((cat) {
                            final isSelected = cat.id == selectedCategoryId;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedCategoryId = cat.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(cat.color).withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(cat.color)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.getIcon(cat.icon),
                                      size: 16,
                                      color: Color(cat.color),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.name,
                                      style: TextStyle(color: Color(cat.color)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Account
                        DropdownButtonFormField<String>(
                          initialValue: selectedAccountId,
                          decoration: const InputDecoration(labelText: 'Akun'),
                          items: accounts
                              .map(
                                (acc) => DropdownMenuItem(
                                  value: acc.id,
                                  child: Text(acc.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedAccountId = value),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tanggal'),
                          trailing: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => selectedDate = date);
                              }
                            },
                            child: Text(DateFormatter.formatDate(selectedDate)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (amountController.text.isEmpty) {
                                SnackBarHelper.showError(
                                  context,
                                  'Jumlah harus diisi',
                                );
                                return;
                              }
                              if (selectedCategoryId == null) {
                                SnackBarHelper.showError(
                                  context,
                                  'Pilih kategori',
                                );
                                return;
                              }
                              if (selectedAccountId == null) {
                                SnackBarHelper.showError(context, 'Pilih akun');
                                return;
                              }

                              final amount =
                                  CurrencyInputFormatter.parse(
                                    amountController.text,
                                  ) ??
                                  0;

                              await context
                                  .read<TransactionProvider>()
                                  .addTransaction(
                                    amount: amount,
                                    type: selectedType,
                                    categoryId: selectedCategoryId!,
                                    accountId: selectedAccountId!,
                                    description:
                                        descriptionController.text.isEmpty
                                        ? null
                                        : descriptionController.text,
                                    date: selectedDate,
                                  );

                              // Update account balance
                              await context
                                  .read<AccountProvider>()
                                  .updateBalance(
                                    selectedAccountId!,
                                    amount,
                                    selectedType,
                                  );

                              if (context.mounted) {
                                Navigator.pop(context);
                                SnackBarHelper.showSuccess(
                                  context,
                                  'Transaksi berhasil ditambahkan',
                                );
                              }
                            },
                            child: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
