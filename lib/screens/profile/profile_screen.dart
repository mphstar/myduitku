import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
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
                _buildTile(
                  Icons.smart_toy_outlined,
                  'Pengaturan AI',
                  () => _showAiSettingsDialog(context),
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

  void _showAiSettingsDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final apiKeyController = TextEditingController(
      text: userProvider.profile.aiApiKey ?? '',
    );
    final customUrlController = TextEditingController(
      text: userProvider.profile.aiCustomBaseUrl ?? '',
    );
    final customModelController = TextEditingController();

    String selectedProvider =
        userProvider.profile.aiProvider ?? AppConstants.defaultAiProvider;

    // Migrate removed providers to 'custom'
    final validProviderIds =
        AppConstants.aiProviders.map((p) => p['id']).toList();
    if (!validProviderIds.contains(selectedProvider)) {
      // If it was 'deepseek', auto-fill the base URL
      if (selectedProvider == 'deepseek') {
        customUrlController.text = 'https://api.deepseek.com';
      }
      selectedProvider = 'custom';
    }

    String selectedModel = userProvider.profile.aiModel ??
        AppConstants.getDefaultModelForProvider(selectedProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final providerConfig =
              AppConstants.getProviderConfig(selectedProvider);
          final models = AppConstants.getModelsForProvider(selectedProvider);

          // Ensure selectedModel is valid for current provider
          if (models.isNotEmpty &&
              !models.any((m) => m['id'] == selectedModel)) {
            selectedModel = models.first['id']!;
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Pengaturan AI'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider Selection
                  const Text(
                    'Provider AI',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: selectedProvider,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: AppConstants.aiProviders.map((provider) {
                        return DropdownMenuItem<String>(
                          value: provider['id'],
                          child: Text(
                            provider['name']!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedProvider = value;
                            // Auto-set first model for new provider
                            final newModels =
                                AppConstants.getModelsForProvider(value);
                            if (newModels.isNotEmpty) {
                              selectedModel = newModels.first['id']!;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    providerConfig['hint'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Custom Base URL (only for Custom provider)
                  if (selectedProvider == 'custom') ...[
                    const Text(
                      'Base URL',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://api.deepseek.com',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DeepSeek: https://api.deepseek.com\n'
                      'Groq: https://api.groq.com/openai',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // API Key
                  const Text(
                    'API Key',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: apiKeyController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan API Key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: const Icon(Icons.key, size: 18),
                    ),
                    obscureText: true,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (providerConfig['website']?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        SnackBarHelper.showInfo(
                          dialogContext,
                          'Buka ${providerConfig['website']} untuk API Key',
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Dapatkan API Key di ${providerConfig['website']}',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Model Selection
                  const Text(
                    'Model AI',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (models.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: models.any((m) => m['id'] == selectedModel)
                            ? selectedModel
                            : models.first['id'],
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: models.map((model) {
                          return DropdownMenuItem<String>(
                            value: model['id'],
                            child: Text(
                              model['name']!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedModel = value);
                          }
                        },
                      ),
                    )
                  else
                    TextField(
                      controller: customModelController
                        ..text = selectedModel,
                      decoration: InputDecoration(
                        hintText: 'Masukkan model ID',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (value) => selectedModel = value,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    selectedProvider == 'custom'
                        ? 'Masukkan model ID sesuai server Anda'
                        : 'Pilih model atau ketik ID model manual',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final modelValue = selectedModel.trim().isEmpty
                      ? AppConstants.getDefaultModelForProvider(selectedProvider)
                      : selectedModel.trim();
                  await userProvider.updateProfile(
                    aiApiKey: apiKeyController.text.trim(),
                    aiModel: modelValue,
                    aiProvider: selectedProvider,
                    aiCustomBaseUrl: selectedProvider == 'custom'
                        ? customUrlController.text.trim()
                        : null,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    SnackBarHelper.showSuccess(
                      this.context,
                      'Pengaturan AI berhasil disimpan',
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
