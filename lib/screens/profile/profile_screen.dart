import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

              // Support & Feedback
              _buildSection('Dukungan & Masukan', [
                _buildTile(
                  Icons.chat_bubble_outline_rounded,
                  'Saran Pengembangan',
                  () => _launchWhatsApp(context),
                ),
                _buildTile(
                  Icons.favorite_outline_rounded,
                  'Support Saya (Sociabuzz)',
                  () => _launchUrl('https://sociabuzz.com/mphstar'),
                ),
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

  Future<void> _launchWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/62895393933040?text=Halo,%20saya%20ingin%20memberikan%20saran%20pengembangan%20untuk%20aplikasi%20MyDuitKu:');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          SnackBarHelper.showError(context, 'Tidak dapat membuka WhatsApp');
        }
      }
    } catch (_) {
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Gagal membuka tautan WhatsApp');
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Gagal membuka tautan');
      }
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final currentPrimary = Color(userProvider.profile.primaryColor);
    final nameController = TextEditingController(
      text: userProvider.profile.name,
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.85, end: 1.0),
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: currentPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: currentPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF171A2B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ubah nama tampilan akun Anda',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF9EABB9) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name Field
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.badge_outlined, color: currentPrimary, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF333A4D) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isNotEmpty) {
                              await userProvider.updateProfile(
                                name: nameController.text.trim(),
                              );
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                                SnackBarHelper.showSuccess(
                                  dialogCtx,
                                  'Profil berhasil diperbarui',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Simpan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeColorDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    int currentColor = userProvider.profile.primaryColor;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final activePrimary = Color(userProvider.profile.primaryColor);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.85, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: activePrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.palette_outlined, color: activePrimary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warna Tema Utama',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF171A2B),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih tema warna aplikasi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF9EABB9) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Wrap(
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
                                  dialogCtx,
                                  'Tema berhasil diubah ke ${preset['name']}',
                                );
                              }
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF333A4D) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAiSettingsDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final currentPrimary = Color(userProvider.profile.primaryColor);
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
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

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
                    dialogContext,
                    'Berhasil mengambil ${models.length} model',
                  );
                } else {
                  SnackBarHelper.showWarning(
                    dialogContext,
                    'Tidak ditemukan model dari server.',
                  );
                }
              }
            } catch (_) {
              setState(() => isFetchingModels = false);
              if (dialogContext.mounted) {
                SnackBarHelper.showError(
                  dialogContext,
                  'Gagal mengambil daftar model',
                );
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.85, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: currentPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.smart_toy_outlined, color: currentPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pengaturan AI',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF171A2B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'OpenAI Compatibility',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF9EABB9) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Endpoint URL Field
                      const Text(
                        'Base URL API',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: endpointController,
                        decoration: InputDecoration(
                          hintText: 'https://api.openai.com/v1',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.link_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mendukung semua server OpenAI compatible API (misal OpenAI, DeepSeek, Groq, OpenRouter, atau server custom proxy/lokal).',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF8E9BAA) : const Color(0xFF64748B),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // API Key Field
                      const Text(
                        'API Key',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: apiKeyController,
                        decoration: InputDecoration(
                          hintText: 'sk-... (opsional untuk server lokal)',
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      // Model Selection Section
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
                              foregroundColor: currentPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: currentPrimary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (fetchedModels.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? const Color(0xFF333A4D) : const Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? const Color(0xFF151821) : const Color(0xFFF8FAFC),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: fetchedModels.contains(modelController.text.trim())
                                  ? modelController.text.trim()
                                  : null,
                              hint: Text(
                                modelController.text.trim().isEmpty
                                    ? 'Pilih model hasil fetch'
                                    : modelController.text.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
                        ),
                      ],

                      TextField(
                        controller: modelController,
                        decoration: InputDecoration(
                          hintText: 'Nama model (contoh: gpt-4o-mini)',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.memory_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 22),

                      // Dialog buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF333A4D) : const Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
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
                                    dialogContext,
                                    'Pengaturan AI berhasil disimpan',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Simpan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
