import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

/// Budget management screen
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBudgetSheet(context),
          ),
        ],
      ),
      body: Consumer2<BudgetProvider, CategoryProvider>(
        builder: (context, budgetProvider, categoryProvider, _) {
          if (budgetProvider.isLoading) {
            return const LoadingWidget();
          }

          if (budgetProvider.budgets.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.pie_chart_outline,
              title: 'Belum ada anggaran',
              subtitle: 'Buat anggaran untuk mengontrol pengeluaran',
              buttonText: 'Buat Anggaran',
              onButtonPressed: () => _showAddBudgetSheet(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => budgetProvider.loadBudgets(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: budgetProvider.budgets.length,
              itemBuilder: (context, index) {
                final budget = budgetProvider.budgets[index];
                final category = categoryProvider.getCategoryById(
                  budget.categoryId,
                );
                return _buildBudgetCard(
                  context,
                  budget,
                  category,
                  budgetProvider,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    Budget budget,
    Category? category,
    BudgetProvider provider,
  ) {
    final spent = provider.getSpentAmount(budget);
    final progress = provider.getBudgetProgress(budget);
    final remaining = provider.getRemainingAmount(budget);
    final isOver = provider.isOverBudget(budget);
    final isNear = provider.isNearLimit(budget);

    Color progressColor = AppColors.primary;
    if (isOver) {
      progressColor = AppColors.error;
    } else if (isNear) {
      progressColor = AppColors.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category != null
                        ? Color(category.color).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.getIcon(category?.icon ?? 'pie_chart'),
                    color: category != null
                        ? Color(category.color)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? 'Kategori',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        budget.period.displayName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showBudgetOptions(context, budget),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            ProgressBarWidget(
              progress: progress.clamp(0, 1),
              color: progressColor,
              height: 10,
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terpakai',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      CurrencyFormatter.format(spent),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppColors.error : null,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Anggaran',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      CurrencyFormatter.format(budget.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),

            if (isOver) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Melebihi anggaran sebesar ${CurrencyFormatter.format(spent - budget.amount)}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Sisa: ${CurrencyFormatter.format(remaining)}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBudgetOptions(BuildContext context, Budget budget) {
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
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Hapus Anggaran',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await DialogHelper.showConfirmation(
                  context,
                  title: 'Hapus Anggaran?',
                  message: 'Tindakan ini tidak dapat dibatalkan.',
                  isDestructive: true,
                );
                if (confirm && context.mounted) {
                  await context.read<BudgetProvider>().deleteBudget(budget.id);
                  if (context.mounted) {
                    SnackBarHelper.showSuccess(context, 'Anggaran dihapus');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBudgetSheet(BuildContext context) {
    String? selectedCategoryId;
    final amountController = TextEditingController();
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Consumer<CategoryProvider>(
          builder: (context, categoryProvider, _) {
            final categories = categoryProvider.expenseCategories;

            return Padding(
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
                  Text(
                    'Buat Anggaran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.getIcon(cat.icon),
                                  color: Color(cat.color),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedCategoryId = value),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Anggaran',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Period
                  Text(
                    'Periode',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: BudgetPeriod.values.map((period) {
                      final isSelected = period == selectedPeriod;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedPeriod = period),
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
                              ),
                            ),
                            child: Center(
                              child: Text(
                                period.displayName,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedCategoryId == null) {
                          SnackBarHelper.showError(context, 'Pilih kategori');
                          return;
                        }
                        if (amountController.text.isEmpty) {
                          SnackBarHelper.showError(context, 'Masukkan jumlah');
                          return;
                        }

                        final amount =
                            CurrencyInputFormatter.parse(
                              amountController.text,
                            ) ??
                            0;

                        await context.read<BudgetProvider>().addBudget(
                          categoryId: selectedCategoryId!,
                          amount: amount,
                          period: selectedPeriod,
                          startDate: DateTime.now(),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          SnackBarHelper.showSuccess(
                            context,
                            'Anggaran berhasil dibuat',
                          );
                        }
                      },
                      child: const Text('Buat Anggaran'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
