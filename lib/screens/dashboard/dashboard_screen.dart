import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../budget/budget_screen.dart';
import '../profile/profile_screen.dart';

/// Dashboard screen with financial overview
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await context.read<AccountProvider>().loadAccounts();
    await context.read<TransactionProvider>().loadTransactions();
    await context.read<CategoryProvider>().loadCategories();
    await context.read<BudgetProvider>().loadBudgets();
    await context.read<GoalProvider>().loadGoals();
    await context.read<UserProvider>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            return Text('Halo, ${userProvider.profile.name}! 👋');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Expense Chart
              _buildExpenseChart(),
              const SizedBox(height: 24),

              // Recent Transactions
              _buildRecentTransactions(),
              const SizedBox(height: 24),

              // Active Goals
              _buildActiveGoals(),
              const SizedBox(height: 24),

              // Budget Alerts
              _buildBudgetAlerts(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Consumer2<AccountProvider, TransactionProvider>(
      builder: (context, accountProvider, transactionProvider, _) {
        final totalBalance = accountProvider.totalBalance;
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final monthlyIncome = transactionProvider.getTotalIncomeForRange(
          startOfMonth,
          endOfMonth,
        );
        final monthlyExpense = transactionProvider.getTotalExpenseForRange(
          startOfMonth,
          endOfMonth,
        );

        return Column(
          children: [
            // Total Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Saldo',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyFormatter.format(totalBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Income & Expense Cards
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Pemasukan',
                    value: CurrencyFormatter.formatCompact(monthlyIncome),
                    icon: Icons.arrow_downward,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Pengeluaran',
                    value: CurrencyFormatter.formatCompact(monthlyExpense),
                    icon: Icons.arrow_upward,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpenseChart() {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, _) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final expensesByCategory = transactionProvider.getExpensesByCategory(
          start: startOfMonth,
          end: endOfMonth,
        );

        if (expensesByCategory.isEmpty) {
          return const SizedBox.shrink();
        }

        final sortedEntries = expensesByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topEntries = sortedEntries.take(5).toList();
        final total = topEntries.fold<double>(0, (sum, e) => sum + e.value);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengeluaran Bulan Ini',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: topEntries.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final category = categoryProvider.getCategoryById(
                              data.key,
                            );
                            return PieChartSectionData(
                              value: data.value,
                              title: '',
                              radius: 50,
                              color: category != null
                                  ? Color(category.color)
                                  : AppColors.chartColors[index %
                                        AppColors.chartColors.length],
                            );
                          }).toList(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: topEntries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final category = categoryProvider.getCategoryById(
                            data.key,
                          );
                          final percentage = (data.value / total * 100)
                              .toStringAsFixed(1);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: category != null
                                        ? Color(category.color)
                                        : AppColors.chartColors[index %
                                              AppColors.chartColors.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category?.name ?? 'Lainnya',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, _) {
        final recentTransactions = transactionProvider.getRecentTransactions();

        if (recentTransactions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaksi Terakhir',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to transactions tab
                    },
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...recentTransactions.map((transaction) {
                final category = categoryProvider.getCategoryById(
                  transaction.categoryId,
                );
                final isExpense = transaction.type == TransactionType.expense;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
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
                      color: category != null
                          ? Color(category.color)
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    category?.name ?? 'Lainnya',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    DateFormatter.formatRelative(transaction.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Text(
                    '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveGoals() {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        final activeGoals = goalProvider.activeGoals.take(2).toList();

        if (activeGoals.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Target Keuangan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...activeGoals.map((goal) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(goal.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressBarWidget(
                        progress: goal.progress,
                        color: goal.color != null
                            ? Color(goal.color!)
                            : AppColors.primary,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyFormatter.formatCompact(goal.currentAmount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            CurrencyFormatter.formatCompact(goal.targetAmount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetAlerts() {
    return Consumer2<BudgetProvider, CategoryProvider>(
      builder: (context, budgetProvider, categoryProvider, _) {
        final nearLimitBudgets = budgetProvider.activeBudgets
            .where((b) => budgetProvider.isNearLimit(b))
            .toList();

        if (nearLimitBudgets.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(
                    'Peringatan Anggaran',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...nearLimitBudgets.map((budget) {
                final category = categoryProvider.getCategoryById(
                  budget.categoryId,
                );
                final progress = budgetProvider.getBudgetProgress(budget);
                final isOver = budgetProvider.isOverBudget(budget);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category?.name ?? 'Kategori',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        isOver
                            ? 'Melebihi batas!'
                            : '${(progress * 100).toStringAsFixed(0)}% terpakai',
                        style: TextStyle(
                          color: isOver ? AppColors.error : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Cepat',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Anggaran',
                Icons.pie_chart,
                AppColors.primary,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BudgetScreen()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
