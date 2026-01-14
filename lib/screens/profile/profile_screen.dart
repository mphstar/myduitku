import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/common_widgets.dart';
import '../categories/categories_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ExportImportService _exportImport = ExportImportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        userProvider.profile.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userProvider.profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member sejak ${DateFormatter.formatDate(userProvider.profile.createdAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings
              _buildSection('Pengaturan', [
                _buildTile(
                  Icons.person_outline,
                  'Edit Profil',
                  () => _showEditProfileDialog(context),
                ),
                _buildTile(
                  Icons.category_outlined,
                  'Kelola Kategori',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoriesScreen(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Data
              _buildSection('Data', [
                _buildTile(Icons.upload, 'Export Data', () async {
                  final result = await _exportImport.exportData();
                  if (context.mounted) {
                    if (result.success) {
                      SnackBarHelper.showSuccess(
                        context,
                        'Data berhasil diekspor',
                      );
                    } else {
                      SnackBarHelper.showError(
                        context,
                        result.error ?? 'Gagal ekspor',
                      );
                    }
                  }
                }),
                _buildTile(Icons.download, 'Import Data', () async {
                  final confirm = await DialogHelper.showConfirmation(
                    context,
                    title: 'Import Data?',
                    message: 'Data saat ini akan diganti. Lanjutkan?',
                    isDestructive: true,
                  );
                  if (confirm) {
                    final result = await _exportImport.importData();
                    if (context.mounted) {
                      if (result.success) {
                        await context.read<AccountProvider>().loadAccounts();
                        await context
                            .read<TransactionProvider>()
                            .loadTransactions();
                        await context.read<CategoryProvider>().loadCategories();
                        await context.read<BudgetProvider>().loadBudgets();
                        await context.read<GoalProvider>().loadGoals();
                        if (context.mounted) {
                          SnackBarHelper.showSuccess(
                            context,
                            'Data berhasil diimpor',
                          );
                        }
                      } else if (!result.cancelled) {
                        SnackBarHelper.showError(
                          context,
                          result.error ?? 'Gagal impor',
                        );
                      }
                    }
                  }
                }),
                _buildTile(Icons.delete_forever, 'Reset Semua Data', () async {
                  final confirm = await DialogHelper.showConfirmation(
                    context,
                    title: 'Reset Semua Data?',
                    message:
                        'PERINGATAN: Semua data akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
                    isDestructive: true,
                  );

                  if (confirm && context.mounted) {
                    await DatabaseService().clearAllData();

                    // Reload providers to reflect empty state
                    if (context.mounted) {
                      await context.read<AccountProvider>().loadAccounts();
                      await context
                          .read<TransactionProvider>()
                          .loadTransactions();
                      await context.read<CategoryProvider>().loadCategories();
                      await context.read<BudgetProvider>().loadBudgets();
                      await context.read<GoalProvider>().loadGoals();

                      SnackBarHelper.showSuccess(
                        context,
                        'Semua data berhasil dihapus',
                      );
                    }
                  }
                }),
              ]),
              const SizedBox(height: 16),

              // About
              _buildSection('Tentang', [
                _buildTile(Icons.info_outline, 'Versi 1.0.0', null),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(
      text: context.read<UserProvider>().profile.name,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nama'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await context.read<UserProvider>().updateProfile(
                  name: nameController.text,
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
