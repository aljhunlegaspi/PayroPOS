import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/product_provider.dart';
import '../../../../shared/providers/store_provider.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  bool _isGridView = true;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterByCategory(List<Product> products) {
    if (_selectedCategoryId == null) return products;

    // If subcategory is selected, filter by subcategory
    if (_selectedSubcategoryId != null) {
      return products.where((p) => p.subcategoryId == _selectedSubcategoryId).toList();
    }

    // Otherwise filter by category (includes products with any subcategory of this category)
    return products.where((p) => p.categoryId == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final allProducts = ref.watch(filteredProductsProvider);
    final products = _filterByCategory(allProducts);
    final store = ref.watch(currentStoreProvider);
    final topLevelCategories = ref.watch(topLevelCategoriesProvider);
    final subcategories = _selectedCategoryId != null
        ? ref.watch(subcategoriesProvider(_selectedCategoryId!))
        : <Category>[];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // Decorative Header
          _buildDecorativeHeader(context),

          // Content with rounded top corners
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: store == null
                    ? _buildNoStoreView(context)
                    : Column(
                        children: [
                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref.read(productProvider.notifier).setSearchQuery(null);
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) {
                                ref.read(productProvider.notifier).setSearchQuery(value);
                              },
                            ),
                          ),

                          // Category Filter Chips (Top-level categories only)
                          if (topLevelCategories.isNotEmpty)
                            SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: const Text('All'),
                                      selected: _selectedCategoryId == null,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategoryId = null;
                                          _selectedSubcategoryId = null;
                                        });
                                      },
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      checkmarkColor: AppColors.primary,
                                    ),
                                  ),
                                  ...topLevelCategories.map((category) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(category.name),
                                      selected: _selectedCategoryId == category.id,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategoryId = selected ? category.id : null;
                                          _selectedSubcategoryId = null;
                                        });
                                      },
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      checkmarkColor: AppColors.primary,
                                    ),
                                  )),
                                ],
                              ),
                            ),

                          // Subcategory Filter Chips
                          if (_selectedCategoryId != null && subcategories.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: const Text('All'),
                                        selected: _selectedSubcategoryId == null,
                                        onSelected: (selected) {
                                          setState(() => _selectedSubcategoryId = null);
                                        },
                                        selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                                        checkmarkColor: AppColors.secondary,
                                        labelStyle: const TextStyle(fontSize: 12),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    ...subcategories.map((subcategory) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(subcategory.name),
                                        selected: _selectedSubcategoryId == subcategory.id,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedSubcategoryId = selected ? subcategory.id : null;
                                          });
                                        },
                                        selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                                        checkmarkColor: AppColors.secondary,
                                        labelStyle: const TextStyle(fontSize: 12),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Product Count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${products.length} products',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final lowStockProducts = ref.watch(lowStockProductsProvider);
                                    if (lowStockProducts.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${lowStockProducts.length} low stock',
                                            style: TextStyle(
                                              color: AppColors.warning,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Products List/Grid
                          Expanded(
                            child: productState.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : products.isEmpty
                                    ? _buildEmptyView(context)
                                    : RefreshIndicator(
                                        onRefresh: () => ref.read(productProvider.notifier).refreshProducts(),
                                        child: _isGridView
                                            ? _buildGridView(products)
                                            : _buildListView(products),
                                      ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: store != null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/products/add'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            )
          : null,
    );
  }

  Widget _buildDecorativeHeader(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative shapes
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryMuted.withValues(alpha: 0.3),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 80,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            // Header content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  // Top row with back button and actions
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.go('/home'),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.category_outlined, color: Colors.white),
                          onPressed: () => context.push('/products/categories'),
                          tooltip: 'Manage Categories',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white),
                          onPressed: () => setState(() => _isGridView = !_isGridView),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                          onPressed: () => context.push('/products/scan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Products',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Manage your inventory',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStoreView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No store setup',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.push('/store-setup'),
            child: const Text('Setup Store'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No products yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first product to get started',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/products/scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Barcode'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/products/add'),
                icon: const Icon(Icons.add),
                label: const Text('Add Manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Product> products) {
    final currentLocation = ref.watch(currentLocationProvider);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProductGridCard(
        product: products[index],
        locationId: currentLocation?.id,
        onTap: () => context.push('/products/edit/${products[index].id}'),
      ),
    );
  }

  Widget _buildListView(List<Product> products) {
    final currentLocation = ref.watch(currentLocationProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProductListTile(
        product: products[index],
        locationId: currentLocation?.id,
        onTap: () => context.push('/products/edit/${products[index].id}'),
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final String? locationId;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.product,
    required this.locationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: AppColors.surfaceVariant,
                child: product.image != null
                    ? CachedNetworkImage(
                        imageUrl: product.image!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.inventory_2,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.inventory_2,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _StockBadge(
                          stock: product.getStockForLocation(locationId),
                          isLowStock: product.isLowStockForLocation(locationId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final String? locationId;
  final VoidCallback onTap;

  const _ProductListTile({
    required this.product,
    required this.locationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: product.image != null
              ? CachedNetworkImage(
                  imageUrl: product.image!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(
                    Icons.inventory_2,
                    color: AppColors.textMuted,
                  ),
                )
              : const Icon(Icons.inventory_2, color: AppColors.textMuted),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          product.barcode ?? 'No barcode',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _StockBadge(
              stock: product.getStockForLocation(locationId),
              isLowStock: product.isLowStockForLocation(locationId),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  final bool isLowStock;

  const _StockBadge({required this.stock, required this.isLowStock});

  @override
  Widget build(BuildContext context) {
    final color = isLowStock ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$stock in stock',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
