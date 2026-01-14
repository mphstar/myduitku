import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

/// Accounts management screen
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const LoadingWidget();
          }

          if (provider.accounts.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada akun',
              subtitle: 'Tambahkan akun untuk mulai mencatat keuangan',
              buttonText: 'Tambah Akun',
              onButtonPressed: () => _showAddAccountDialog(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadAccounts(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Balance Card
                _buildTotalBalanceCard(provider.totalBalance),
                const SizedBox(height: 20),

                // Account List
                Text(
                  'Daftar Akun',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...provider.accounts.map(
                  (account) => _buildAccountCard(context, account),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Saldo',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: account.color != null
                ? Color(account.color!).withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.getIcon(account.type.icon),
            color: account.color != null
                ? Color(account.color!)
                : AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          account.type.displayName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(account.balance),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: account.balance >= 0
                    ? AppColors.income
                    : AppColors.expense,
              ),
            ),
          ],
        ),
        onTap: () => _showAccountOptions(context, account),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
              account.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Akun'),
              onTap: () {
                Navigator.pop(context);
                _showEditAccountDialog(context, account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Hapus Akun',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await DialogHelper.showConfirmation(
                  context,
                  title: 'Hapus Akun?',
                  message:
                      'Semua transaksi untuk akun ini juga akan terhapus. Tindakan ini tidak dapat dibatalkan.',
                  isDestructive: true,
                );
                if (confirm) {
                  await context.read<AccountProvider>().deleteAccount(
                    account.id,
                  );
                  if (context.mounted) {
                    SnackBarHelper.showSuccess(
                      context,
                      'Akun berhasil dihapus',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    _showAccountFormDialog(context, null);
  }

  void _showEditAccountDialog(BuildContext context, Account account) {
    _showAccountFormDialog(context, account);
  }

  void _showAccountFormDialog(BuildContext context, Account? account) {
    final isEditing = account != null;
    final nameController = TextEditingController(text: account?.name ?? '');
    final balanceController = TextEditingController(
      text: account?.balance.toStringAsFixed(0) ?? '',
    );
    AccountType selectedType = account?.type ?? AccountType.bank;
    int selectedColor = account?.color ?? AppColors.primary.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
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
                isEditing ? 'Edit Akun' : 'Tambah Akun',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Name field
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Akun',
                  hintText: 'Contoh: BCA, Tunai, GoPay',
                ),
              ),
              const SizedBox(height: 16),

              // Account type
              Text(
                'Jenis Akun',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: AccountType.values.map((type) {
                  final isSelected = type == selectedType;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              AppIcons.getIcon(type.icon),
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Balance field
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      SnackBarHelper.showError(
                        context,
                        'Nama akun harus diisi',
                      );
                      return;
                    }

                    final balance =
                        CurrencyInputFormatter.parse(balanceController.text) ??
                        0;

                    if (isEditing) {
                      final updatedAccount = account.copyWith(
                        name: nameController.text,
                        type: selectedType,
                        balance: balance,
                        color: selectedColor,
                      );
                      await context.read<AccountProvider>().updateAccount(
                        updatedAccount,
                      );
                    } else {
                      await context.read<AccountProvider>().addAccount(
                        name: nameController.text,
                        type: selectedType,
                        balance: balance,
                        color: selectedColor,
                      );
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      SnackBarHelper.showSuccess(
                        context,
                        isEditing
                            ? 'Akun berhasil diperbarui'
                            : 'Akun berhasil ditambahkan',
                      );
                    }
                  },
                  child: Text(isEditing ? 'Simpan' : 'Tambah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
