import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/product_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final Set<String> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    final topLevelCategories = ref.watch(topLevelCategoriesProvider);
    final productState = ref.watch(productProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: productState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : topLevelCategories.isEmpty
              ? _buildEmptyView()
              : _buildCategoryList(topLevelCategories),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add categories to organize your products',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) {
        _reorderCategories(categories, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryTile(
          key: ValueKey(category.id),
          category: category,
          isExpanded: _expandedCategories.contains(category.id),
          onToggleExpand: () {
            setState(() {
              if (_expandedCategories.contains(category.id)) {
                _expandedCategories.remove(category.id);
              } else {
                _expandedCategories.add(category.id);
              }
            });
          },
          onEdit: () => _showEditCategoryDialog(category),
          onDelete: () => _showDeleteCategoryDialog(category),
          onAddSubcategory: () => _showAddSubcategoryDialog(category),
          index: index,
        );
      },
    );
  }

  int _getProductCount(String categoryId) {
    final products = ref.read(productProvider).products;
    // Count products in this category OR any of its subcategories
    final subcategories = ref.read(subcategoriesProvider(categoryId));
    final subcategoryIds = subcategories.map((s) => s.id).toSet();

    return products.where((p) =>
      p.isActive && (
        p.categoryId == categoryId ||
        subcategoryIds.contains(p.categoryId) ||
        p.subcategoryId == categoryId ||
        subcategoryIds.contains(p.subcategoryId)
      )
    ).length;
  }

  int _getSubcategoryProductCount(String subcategoryId) {
    final products = ref.read(productProvider).products;
    return products.where((p) =>
      p.isActive && (p.categoryId == subcategoryId || p.subcategoryId == subcategoryId)
    ).length;
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Beverages, Snacks, Dairy',
            prefixIcon: Icon(Icons.category),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _addCategory(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _addCategory(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSubcategoryDialog(Category parentCategory) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Subcategory to ${parentCategory.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a brand or subcategory under "${parentCategory.name}"',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Subcategory/Brand Name',
                hintText: 'e.g., Alaska, Bear Brand, Nestle',
                prefixIcon: Icon(Icons.label_outline),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _addSubcategory(parentCategory.id, value.trim());
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _addSubcategory(parentCategory.id, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    final controller = TextEditingController(text: category.name);
    final isSubcategory = category.isSubcategory;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSubcategory ? 'Edit Subcategory' : 'Edit Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: isSubcategory ? 'Subcategory Name' : 'Category Name',
            prefixIcon: Icon(isSubcategory ? Icons.label_outline : Icons.category),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _updateCategory(category.id, value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _updateCategory(category.id, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(Category category) {
    final isSubcategory = category.isSubcategory;
    final productCount = isSubcategory
        ? _getSubcategoryProductCount(category.id)
        : _getProductCount(category.id);
    final subcategories = isSubcategory
        ? <Category>[]
        : ref.read(subcategoriesProvider(category.id));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSubcategory ? 'Delete Subcategory' : 'Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${category.name}"?'),
            if (subcategories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${subcategories.length} subcategories will also be deleted',
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (productCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$productCount products will be uncategorized',
                        style: TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteCategory(category.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory(String name) async {
    try {
      await ref.read(productProvider.notifier).addCategory(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addSubcategory(String parentId, String name) async {
    try {
      await ref.read(productProvider.notifier).addSubcategory(parentId, name);
      // Auto-expand the parent to show the new subcategory
      setState(() {
        _expandedCategories.add(parentId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subcategory "$name" added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateCategory(String categoryId, String name) async {
    try {
      await ref.read(productProvider.notifier).updateCategory(categoryId, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await ref.read(productProvider.notifier).deleteCategory(categoryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reorderCategories(List<Category> categories, int oldIndex, int newIndex) async {
    try {
      await ref.read(productProvider.notifier).reorderCategories(oldIndex, newIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddSubcategory;
  final int index;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubcategory,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategories = ref.watch(subcategoriesProvider(category.id));
    final products = ref.watch(productProvider).products;
    final productCount = products.where((p) =>
      p.isActive && (p.categoryId == category.id || p.subcategoryId == category.id)
    ).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: GestureDetector(
              onTap: subcategories.isNotEmpty ? onToggleExpand : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  subcategories.isNotEmpty
                      ? (isExpanded ? Icons.folder_open : Icons.folder)
                      : Icons.category,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (subcategories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${subcategories.length} sub',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '$productCount products',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAddSubcategory,
                  color: AppColors.primary,
                  tooltip: 'Add Subcategory',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  color: AppColors.textSecondary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  color: AppColors.error,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: AppColors.textMuted),
                ),
              ],
            ),
            onTap: subcategories.isNotEmpty ? onToggleExpand : null,
          ),
          // Subcategories
          if (isExpanded && subcategories.isNotEmpty)
            Container(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              child: Column(
                children: subcategories.map((sub) => _SubcategoryTile(
                  subcategory: sub,
                  onEdit: () => _showEditDialog(context, ref, sub),
                  onDelete: () => _showDeleteDialog(context, ref, sub),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Category subcategory) {
    final controller = TextEditingController(text: subcategory.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subcategory'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Subcategory Name',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ref.read(productProvider.notifier).updateCategory(subcategory.id, name);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subcategory updated'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Category subcategory) {
    final products = ref.read(productProvider).products;
    final productCount = products.where((p) =>
      p.isActive && (p.categoryId == subcategory.id || p.subcategoryId == subcategory.id)
    ).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subcategory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${subcategory.name}"?'),
            if (productCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$productCount products will be uncategorized',
                        style: TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(productProvider.notifier).deleteCategory(subcategory.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subcategory deleted'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryTile extends ConsumerWidget {
  final Category subcategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubcategoryTile({
    required this.subcategory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productProvider).products;
    final productCount = products.where((p) =>
      p.isActive && (p.categoryId == subcategory.id || p.subcategoryId == subcategory.id)
    ).length;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.label_outline, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(
        subcategory.name,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '$productCount products',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
