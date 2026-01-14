import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/currency_input_formatter.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddGoalSheet(context),
          ),
        ],
      ),
      body: Consumer<GoalProvider>(
        builder: (context, goalProvider, _) {
          if (goalProvider.isLoading) {
            return const LoadingWidget();
          }
          if (goalProvider.goals.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.flag_outlined,
              title: 'Belum ada target',
              subtitle: 'Buat target untuk mencapai tujuan keuangan',
              buttonText: 'Buat Target',
              onButtonPressed: () => _showAddGoalSheet(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => goalProvider.loadGoals(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goalProvider.goals.length,
              itemBuilder: (context, index) {
                final goal = goalProvider.goals[index];
                return _buildGoalCard(context, goal);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Goal goal) {
    final color = goal.color != null ? Color(goal.color!) : AppColors.primary;
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.getIcon(goal.icon ?? 'flag'),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        goal.isCompleted
                            ? 'Tercapai! 🎉'
                            : '${goal.daysRemaining} hari tersisa',
                        style: TextStyle(
                          fontSize: 12,
                          color: goal.isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showGoalOptions(context, goal),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormatter.format(goal.currentAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(goal.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBarWidget(
              progress: goal.progress,
              color: goal.isCompleted ? AppColors.success : color,
              height: 10,
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${CurrencyFormatter.format(goal.targetAmount)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!goal.isCompleted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddFundsDialog(context, goal),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Dana'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showGoalOptions(BuildContext context, Goal goal) {
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
                'Hapus Target',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await DialogHelper.showConfirmation(
                  context,
                  title: 'Hapus?',
                  message: 'Yakin ingin menghapus?',
                  isDestructive: true,
                );
                if (confirm && context.mounted) {
                  await context.read<GoalProvider>().deleteGoal(goal.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, Goal goal) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Dana'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Jumlah',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount =
                  CurrencyInputFormatter.parse(amountController.text) ?? 0;
              if (amount > 0) {
                await context.read<GoalProvider>().addFunds(goal.id, amount);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 30));
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
              Text(
                'Buat Target',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Target'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Target Jumlah',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline'),
                trailing: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: deadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setState(() => deadline = date);
                  },
                  child: Text(DateFormatter.formatDate(deadline)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        targetController.text.isEmpty) {
                      return;
                    }
                    await context.read<GoalProvider>().addGoal(
                      name: nameController.text,
                      targetAmount:
                          CurrencyInputFormatter.parse(targetController.text) ??
                          0,
                      deadline: deadline,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Buat Target'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
