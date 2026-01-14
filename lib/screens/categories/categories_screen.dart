import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';

/// Categories management screen
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, _) {
          if (categoryProvider.isLoading) {
            return const LoadingWidget();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(
                categoryProvider.expenseCategories,
                TransactionType.expense,
              ),
              _buildCategoryList(
                categoryProvider.incomeCategories,
                TransactionType.income,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, TransactionType type) {
    if (categories.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.category_outlined,
        title: 'Belum ada kategori',
        subtitle: 'Tambahkan kategori baru',
        buttonText: 'Tambah Kategori',
        onButtonPressed: () => _showCategoryDialog(context, type: type),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryTile(category);
      },
    );
  }

  Widget _buildCategoryTile(Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(category.color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.getIcon(category.icon),
            color: Color(category.color),
            size: 24,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          category.isDefault ? 'Kategori bawaan' : 'Kategori kustom',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: category.isDefault
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showCategoryDialog(context, category: category);
                  } else if (value == 'delete') {
                    _confirmDelete(category);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
        onTap: category.isDefault
            ? null
            : () => _showCategoryDialog(context, category: category),
      ),
    );
  }

  Future<void> _confirmDelete(Category category) async {
    final confirm = await DialogHelper.showConfirmation(
      context,
      title: 'Hapus Kategori?',
      message: 'Kategori "${category.name}" akan dihapus.',
      isDestructive: true,
    );
    if (confirm && mounted) {
      await context.read<CategoryProvider>().deleteCategory(category.id);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Kategori dihapus');
      }
    }
  }

  void _showCategoryDialog(
    BuildContext context, {
    Category? category,
    TransactionType? type,
  }) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    TransactionType selectedType =
        category?.type ?? type ?? TransactionType.expense;
    String selectedIcon = category?.icon ?? 'restaurant';
    int selectedColor = category?.color ?? AppColorPalette.colors.first.value;

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
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Kategori'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Type selector
                if (!isEditing) ...[
                  Text('Jenis', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          'Pengeluaran',
                          TransactionType.expense,
                          selectedType,
                          () => setState(
                            () => selectedType = TransactionType.expense,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeChip(
                          'Pemasukan',
                          TransactionType.income,
                          selectedType,
                          () => setState(
                            () => selectedType = TransactionType.income,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Icon picker
                Text('Ikon', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: AppIcons.allIconNames.length,
                    itemBuilder: (context, index) {
                      final iconName = AppIcons.allIconNames[index];
                      final isSelected = iconName == selectedIcon;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = iconName),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(selectedColor).withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Color(selectedColor)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            AppIcons.getIcon(iconName),
                            color: isSelected
                                ? Color(selectedColor)
                                : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Color picker
                Text('Warna', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColorPalette.colors.map((color) {
                    final isSelected = color.value == selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color.value),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        SnackBarHelper.showError(context, 'Nama harus diisi');
                        return;
                      }

                      final categoryProvider = context.read<CategoryProvider>();
                      if (isEditing) {
                        await categoryProvider.updateCategory(
                          category.copyWith(
                            name: nameController.text,
                            icon: selectedIcon,
                            color: selectedColor,
                          ),
                        );
                      } else {
                        await categoryProvider.addCategory(
                          name: nameController.text,
                          icon: selectedIcon,
                          color: selectedColor,
                          type: selectedType,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        SnackBarHelper.showSuccess(
                          context,
                          isEditing
                              ? 'Kategori berhasil diperbarui'
                              : 'Kategori berhasil ditambahkan',
                        );
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    TransactionType type,
    TransactionType selectedType,
    VoidCallback onTap,
  ) {
    final isSelected = type == selectedType;
    final color = type == TransactionType.expense
        ? AppColors.expense
        : AppColors.income;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
