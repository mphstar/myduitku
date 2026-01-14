import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

/// Report screen with transaction analytics and charts
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum ReportPeriod { daily, weekly, monthly, yearly, custom }

class _ReportScreenState extends State<ReportScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  double? _minAmount;
  double? _maxAmount;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  bool _showAmountFilter = false;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = _startDate;
        break;
      case ReportPeriod.weekly:
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
        );
        _endDate = _startDate.add(const Duration(days: 6));
        break;
      case ReportPeriod.monthly:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case ReportPeriod.yearly:
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        break;
      case ReportPeriod.custom:
        // Keep existing custom dates
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          if (_selectedPeriod == ReportPeriod.custom)
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _showDateRangePicker,
            ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          _buildPeriodSelector(),

          // Amount filter
          _buildAmountFilter(),

          // Content
          Expanded(
            child: Consumer2<TransactionProvider, CategoryProvider>(
              builder: (context, transactionProvider, categoryProvider, _) {
                if (transactionProvider.isLoading) {
                  return const LoadingWidget();
                }

                final allTransactions = transactionProvider.allTransactions
                    .where(
                      (t) =>
                          t.date.isAfter(
                            _startDate.subtract(const Duration(days: 1)),
                          ) &&
                          t.date.isBefore(
                            _endDate.add(const Duration(days: 1)),
                          ),
                    )
                    .toList();

                // Apply amount filter
                final transactions = allTransactions.where((t) {
                  if (_minAmount != null && t.amount < _minAmount!)
                    return false;
                  if (_maxAmount != null && t.amount > _maxAmount!)
                    return false;
                  return true;
                }).toList();

                if (transactions.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.analytics_outlined,
                    title: 'Tidak ada transaksi',
                    subtitle: 'Belum ada transaksi pada periode ini',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => transactionProvider.loadTransactions(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary cards
                        _buildSummaryCards(transactions),
                        const SizedBox(height: 24),

                        // Bar chart
                        _buildBarChart(transactions),
                        const SizedBox(height: 24),

                        // Category breakdown
                        _buildCategoryBreakdown(transactions, categoryProvider),
                        const SizedBox(height: 24),

                        // Transaction list
                        _buildTransactionList(transactions, categoryProvider),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReportPeriod.values.map((period) {
            final isSelected = period == _selectedPeriod;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_getPeriodLabel(period)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      if (period == ReportPeriod.custom) {
                        _showDateRangePicker();
                      } else {
                        _updateDateRange();
                      }
                    });
                  }
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getPeriodLabel(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        return 'Harian';
      case ReportPeriod.weekly:
        return 'Mingguan';
      case ReportPeriod.monthly:
        return 'Bulanan';
      case ReportPeriod.yearly:
        return 'Tahunan';
      case ReportPeriod.custom:
        return 'Range';
    }
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Allow current day
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate.isAfter(DateTime.now()) ? DateTime.now() : _endDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildSummaryCards(List<Transaction> transactions) {
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getDateRangeLabel(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Pemasukan',
                totalIncome,
                AppColors.income,
                Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Pengeluaran',
                totalExpense,
                AppColors.expense,
                Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: balance >= 0
                ? AppColors.income.withOpacity(0.1)
                : AppColors.expense.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: balance >= 0 ? AppColors.income : AppColors.expense,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selisih',
                style: TextStyle(
                  color: balance >= 0 ? AppColors.income : AppColors.expense,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${balance >= 0 ? '+' : ''} ${CurrencyFormatter.format(balance)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: balance >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
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
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatCompact(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateRangeLabel() {
    final dateFormat = DateFormat('d MMM yyyy', 'id');
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day) {
      return dateFormat.format(_startDate);
    }
    return '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}';
  }

  Widget _buildBarChart(List<Transaction> transactions) {
    final groupedData = _groupTransactionsByPeriod(transactions);
    if (groupedData.isEmpty) return const SizedBox.shrink();

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
            'Ringkasan Transaksi',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChartLegend('Pemasukan', AppColors.income),
              const SizedBox(width: 16),
              _buildChartLegend('Pengeluaran', AppColors.expense),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(groupedData),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        Theme.of(context).cardTheme.color ?? Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        CurrencyFormatter.format(rod.toY),
                        TextStyle(
                          color: rod.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: groupedData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data['income'] ?? 0,
                        color: AppColors.income,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: data['expense'] ?? 0,
                        color: AppColors.expense,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatYAxisValue(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < groupedData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              groupedData[index]['label'] ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxY(groupedData) / 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  double _getMaxY(List<Map<String, dynamic>> data) {
    double max = 0;
    for (final item in data) {
      final income = (item['income'] as double?) ?? 0;
      final expense = (item['expense'] as double?) ?? 0;
      if (income > max) max = income;
      if (expense > max) max = expense;
    }
    return max * 1.2; // Add 20% padding
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}M';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}Jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}Rb';
    }
    return value.toStringAsFixed(0);
  }

  List<Map<String, dynamic>> _groupTransactionsByPeriod(
    List<Transaction> transactions,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final t in transactions) {
      String key;
      String label;

      switch (_selectedPeriod) {
        case ReportPeriod.daily:
          key = DateFormat('HH').format(t.date);
          label = '$key:00';
          break;
        case ReportPeriod.weekly:
          key = DateFormat('E').format(t.date);
          label = key;
          break;
        case ReportPeriod.monthly:
          key = DateFormat('d').format(t.date);
          label = key;
          break;
        case ReportPeriod.yearly:
          key = DateFormat('MMM').format(t.date);
          label = key;
          break;
        case ReportPeriod.custom:
          final days = _endDate.difference(_startDate).inDays;
          if (days <= 7) {
            key = DateFormat('E').format(t.date);
            label = key;
          } else if (days <= 31) {
            key = DateFormat('d').format(t.date);
            label = key;
          } else {
            key = DateFormat('MMM').format(t.date);
            label = key;
          }
          break;
      }

      grouped.putIfAbsent(
        key,
        () => <String, dynamic>{'income': 0.0, 'expense': 0.0, 'label': label},
      );
      if (t.type == TransactionType.income) {
        grouped[key]!['income'] =
            (grouped[key]!['income'] as double) + t.amount;
      } else {
        grouped[key]!['expense'] =
            (grouped[key]!['expense'] as double) + t.amount;
      }
      grouped[key]!['label'] = label;
    }

    // Sort by key
    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys.map((k) {
      final data = grouped[k]!;
      return {
        'income': data['income'],
        'expense': data['expense'],
        'label': data['label'],
      };
    }).toList();
  }

  Widget _buildCategoryBreakdown(
    List<Transaction> transactions,
    CategoryProvider categoryProvider,
  ) {
    // Get expense by category
    final expenseByCategory = <String, double>{};
    for (final t in transactions.where(
      (t) => t.type == TransactionType.expense,
    )) {
      expenseByCategory[t.categoryId] =
          (expenseByCategory[t.categoryId] ?? 0) + t.amount;
    }

    if (expenseByCategory.isEmpty) return const SizedBox.shrink();

    // Sort by amount
    final sortedEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sortedEntries.fold<double>(0, (sum, e) => sum + e.value);

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
            'Pengeluaran per Kategori',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Pie chart
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sortedEntries.take(5).map((entry) {
                        final category = categoryProvider.getCategoryById(
                          entry.key,
                        );
                        final percentage = entry.value / total * 100;
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                          color: category != null
                              ? Color(category.color)
                              : Colors.grey,
                        );
                      }).toList(),
                      centerSpaceRadius: 35,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedEntries.take(5).map((entry) {
                      final category = categoryProvider.getCategoryById(
                        entry.key,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: category != null
                                    ? Color(category.color)
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category?.name ?? 'Lainnya',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
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
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // Detail list
          ...sortedEntries.map((entry) {
            final category = categoryProvider.getCategoryById(entry.key);
            final percentage = entry.value / total * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: category != null
                          ? Color(category.color).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      AppIcons.getIcon(category?.icon ?? 'more_horiz'),
                      color: category != null
                          ? Color(category.color)
                          : Colors.grey,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?.name ?? 'Lainnya',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAmountFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAmountFilter = !_showAmountFilter),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter Jumlah',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Icon(_showAmountFilter ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_showAmountFilter) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      prefixText: 'Rp ',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _minAmount = CurrencyInputFormatter.parse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      prefixText: 'Rp ',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _maxAmount = CurrencyInputFormatter.parse(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_minAmount != null || _maxAmount != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _minAmount = null;
                      _maxAmount = null;
                      _minAmountController.clear();
                      _maxAmountController.clear();
                    });
                  },
                  child: const Text('Reset Filter'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<Transaction> transactions,
    CategoryProvider categoryProvider,
  ) {
    // Group transactions by date
    final Map<String, List<Transaction>> grouped = {};
    for (final t in transactions) {
      final key = DateFormatter.formatDate(t.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(t);
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
                'Daftar Transaksi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${transactions.length} transaksi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...entry.value.map((transaction) {
                  final category = categoryProvider.getCategoryById(
                    transaction.categoryId,
                  );
                  final isExpense = transaction.type == TransactionType.expense;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: category != null
                                ? Color(category.color).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            AppIcons.getIcon(category?.icon ?? 'more_horiz'),
                            color: category != null
                                ? Color(category.color)
                                : Colors.grey,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category?.name ?? 'Lainnya',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (transaction.description?.isNotEmpty ?? false)
                                Text(
                                  transaction.description!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(transaction.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isExpense
                                ? AppColors.expense
                                : AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }),
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Tidak ada transaksi',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
