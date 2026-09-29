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
          final currentPrimary = Color(userProvider.profile.primaryColor);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      currentPrimary,
                      HSLColor.fromColor(currentPrimary)
                          .withLightness((HSLColor.fromColor(currentPrimary).lightness - 0.12).clamp(0.0, 1.0))
                          .toColor(),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        userProvider.profile.name.isNotEmpty
                            ? userProvider.profile.name.substring(0, 1).toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: currentPrimary,
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
                _buildTile(
                  Icons.palette_outlined,
                  'Warna Tema Utama',
                  () => _showThemeColorDialog(context),
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
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final currentPrimary = Color(userProvider.profile.primaryColor);
        return ListTile(
          leading: Icon(icon, color: currentPrimary),
          title: Text(title),
          trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
          onTap: onTap,
        );
      },
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

  void _showThemeColorDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    int currentColor = userProvider.profile.primaryColor;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          final activePrimary = Color(userProvider.profile.primaryColor);

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.palette_outlined, color: activePrimary),
                const SizedBox(width: 8),
                const Text('Warna Tema Utama'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih warna aksen utama aplikasi sesuai preferensi Anda:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppThemePresets.presets.map((preset) {
                    final Color color = preset['color'] as Color;
                    final int colorValue = color.toARGB32();
                    final isSelected = currentColor == colorValue;

                    return GestureDetector(
                      onTap: () async {
                        setState(() => currentColor = colorValue);
                        await userProvider.updateProfile(primaryColor: colorValue);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          SnackBarHelper.showSuccess(
                            this.context,
                            'Tema warna berhasil diubah ke ${preset['name']}',
                          );
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.black87 : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAiSettingsDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final endpointController = TextEditingController(
      text: userProvider.profile.aiCustomBaseUrl ?? '',
    );
    final apiKeyController = TextEditingController(
      text: userProvider.profile.aiApiKey ?? '',
    );
    final modelController = TextEditingController(
      text: userProvider.profile.aiModel ?? AppConstants.defaultAiModel,
    );

    List<String> fetchedModels = [];
    bool isFetchingModels = false;
    final aiService = AiService();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> fetchModelsFromApi() async {
            setState(() {
              isFetchingModels = true;
            });
            try {
              final models = await aiService.fetchModels(
                apiKey: apiKeyController.text.trim(),
                customBaseUrl: endpointController.text.trim(),
              );
              setState(() {
                fetchedModels = models;
                isFetchingModels = false;
              });
              if (dialogContext.mounted) {
                if (models.isNotEmpty) {
                  SnackBarHelper.showSuccess(
                    context,
                    'Berhasil mengambil ${models.length} model',
                  );
                } else {
                  SnackBarHelper.showWarning(
                    context,
                    'Tidak dapat menemukan daftar model. Anda tetap dapat mengetik nama model secara manual.',
                  );
                }
              }
            } catch (_) {
              setState(() => isFetchingModels = false);
              if (dialogContext.mounted) {
                SnackBarHelper.showError(
                  context,
                  'Gagal menghubungi endpoint /models',
                );
              }
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Pengaturan AI (OpenAI API)'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Endpoint URL
                  const Text(
                    'Base URL API (contoh: https://9router.mphstar.my.id/v1)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: endpointController,
                    decoration: InputDecoration(
                      hintText: 'https://api.openai.com/v1',
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
                    'Contoh base URL:\n'
                    '• Custom Proxy: https://9router.mphstar.my.id/v1\n'
                    '• OpenAI: https://api.openai.com/v1\n'
                    '• DeepSeek: https://api.deepseek.com\n'
                    '• Groq: https://api.groq.com/openai/v1\n'
                    '• OpenRouter: https://openrouter.ai/api/v1\n'
                    '• Local/Ollama: http://localhost:11434/v1',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // API Key
                  const Text(
                    'API Key',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: apiKeyController,
                    decoration: InputDecoration(
                      hintText: 'sk-xxxxxxxxxxxx',
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
                  const SizedBox(height: 4),
                  Text(
                    'Opsional jika server lokal tidak membutuhkan API key.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Model Selection & Fetch Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Model AI',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: isFetchingModels ? null : fetchModelsFromApi,
                        icon: isFetchingModels
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(
                          isFetchingModels ? 'Memuat...' : 'Fetch Model',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (fetchedModels.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: fetchedModels.contains(modelController.text.trim())
                            ? modelController.text.trim()
                            : null,
                        hint: Text(
                          modelController.text.trim().isEmpty
                              ? 'Pilih dari model yang ditemukan'
                              : modelController.text.trim(),
                          style: const TextStyle(fontSize: 13),
                        ),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: fetchedModels.map((id) {
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              id,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              modelController.text = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextField(
                    controller: modelController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: gpt-4o-mini / deepseek-chat',
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
                    'Pilih dari hasil "Fetch Model" atau ketik nama model secara manual.',
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
                  final modelValue = modelController.text.trim().isEmpty
                      ? AppConstants.defaultAiModel
                      : modelController.text.trim();
                  await userProvider.updateProfile(
                    aiApiKey: apiKeyController.text.trim(),
                    aiModel: modelValue,
                    aiCustomBaseUrl: endpointController.text.trim(),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    SnackBarHelper.showSuccess(
                      this.context,
                      'Pengaturan AI OpenAI-Compatible berhasil disimpan',
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
