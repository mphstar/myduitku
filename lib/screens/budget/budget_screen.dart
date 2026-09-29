import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

/// Budget management screen with Active and Archive tabs & Category filter
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBudgetSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Sedang Aktif'),
            Tab(text: 'Riwayat / Arsip'),
          ],
        ),
      ),
      body: Consumer2<BudgetProvider, CategoryProvider>(
        builder: (context, budgetProvider, categoryProvider, _) {
          if (budgetProvider.isLoading) {
            return const LoadingWidget();
          }

          final activeList = budgetProvider.filterByCategory(
            budgetProvider.activeBudgets,
          );
          final archivedList = budgetProvider.filterByCategory(
            budgetProvider.archivedBudgets,
          );

          return Column(
            children: [
              // Category Filter Bar
              _buildCategoryFilterBar(context, budgetProvider, categoryProvider),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Active Tab
                    _buildBudgetListView(
                      context,
                      budgets: activeList,
                      categoryProvider: categoryProvider,
                      budgetProvider: budgetProvider,
                      emptyTitle: 'Belum ada anggaran aktif',
                      emptySubtitle:
                          'Buat anggaran baru untuk mengontrol pengeluaran kategori',
                      showAddButton: true,
                    ),
                    // Archived Tab
                    _buildBudgetListView(
                      context,
                      budgets: archivedList,
                      categoryProvider: categoryProvider,
                      budgetProvider: budgetProvider,
                      emptyTitle: 'Belum ada riwayat anggaran',
                      emptySubtitle:
                          'Anggaran yang telah selesai atau diperbarui akan tersimpan di sini',
                      showAddButton: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilterBar(
    BuildContext context,
    BudgetProvider budgetProvider,
    CategoryProvider categoryProvider,
  ) {
    final categories = categoryProvider.expenseCategories;
    final selectedCat = budgetProvider.selectedCategoryFilter;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: selectedCat == null,
            onSelected: (_) => budgetProvider.setCategoryFilter(null),
          ),
          const SizedBox(width: 8),
          ...categories.map((cat) {
            final isSelected = cat.id == selectedCat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  AppIcons.getIcon(cat.icon),
                  size: 14,
                  color: isSelected ? Colors.white : Color(cat.color),
                ),
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (selected) {
                  budgetProvider.setCategoryFilter(selected ? cat.id : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetListView(
    BuildContext context, {
    required List<Budget> budgets,
    required CategoryProvider categoryProvider,
    required BudgetProvider budgetProvider,
    required String emptyTitle,
    required String emptySubtitle,
    required bool showAddButton,
  }) {
    if (budgets.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.pie_chart_outline,
        title: emptyTitle,
        subtitle: emptySubtitle,
        buttonText: showAddButton ? 'Buat Anggaran' : null,
        onButtonPressed:
            showAddButton ? () => _showAddBudgetSheet(context) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => budgetProvider.loadBudgets(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          final category = categoryProvider.getCategoryById(budget.categoryId);
          return _buildBudgetCard(
            context,
            budget,
            category,
            budgetProvider,
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

    Color progressColor = Theme.of(context).primaryColor;
    if (isOver) {
      progressColor = AppColors.error;
    } else if (isNear) {
      progressColor = AppColors.warning;
    }

    final dateRangeStr =
        '${DateFormatter.formatDate(budget.startDate)} - ${DateFormatter.formatDate(budget.endDate)}';

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
                        ? Color(category.color).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category?.name ?? 'Kategori',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (budget.isArchived) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Arsip',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${budget.period.displayName} • $dateRangeStr',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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
              height: 8,
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
                      'Terpakai (${(progress * 100).toStringAsFixed(0)}%)',
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
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Melebihi anggaran sebesar ${CurrencyFormatter.format(spent - budget.amount)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!budget.isArchived)
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: AppColors.textSecondary),
                title: const Text('Arsipkan Anggaran'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await context.read<BudgetProvider>().archiveBudget(budget.id);
                  if (context.mounted) {
                    SnackBarHelper.showSuccess(context, 'Anggaran berhasil diarsipkan');
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Hapus Anggaran',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await DialogHelper.showConfirmation(
                  context,
                  title: 'Hapus Anggaran?',
                  message: 'Tindakan ini akan menghapus riwayat anggaran ini secara permanen.',
                  isDestructive: true,
                );
                if (confirm && context.mounted) {
                  await context.read<BudgetProvider>().deleteBudget(budget.id);
                  if (context.mounted) {
                    SnackBarHelper.showSuccess(context, 'Anggaran berhasil dihapus');
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Text(
                      'Buat Anggaran Baru',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jika sudah ada anggaran aktif di kategori ini, anggaran lama akan otomatis diarsipkan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

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
                      onChanged: (value) {
                        setState(() => selectedCategoryId = value);
                      },
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
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  period.displayName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
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

                          final amount = CurrencyInputFormatter.parse(
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
              ),
            );
          },
        ),
      ),
    );
  }
}
