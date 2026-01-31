import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/product_provider.dart';
import '../../../../shared/providers/cart_provider.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/providers/user_preferences_provider.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCartModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CartModal(
        onCheckout: () {
          Navigator.pop(context);
          context.push('/checkout');
        },
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    var filtered = products;

    // Filter by category/subcategory
    if (_selectedCategoryId != null) {
      if (_selectedSubcategoryId != null) {
        // Filter by subcategory
        filtered = filtered.where((p) => p.subcategoryId == _selectedSubcategoryId).toList();
      } else {
        // Filter by category
        filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
      }
    }

    // Filter by search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filtered;
  }

  Future<void> _onProductTap(Product product) async {
    final currentLocation = ref.read(currentLocationProvider);
    final stock = product.getStockForLocation(currentLocation?.id);

    // Check if out of stock
    if (stock <= 0) {
      _showOutOfStockAlert(product.name);
      return;
    }

    // Check if quantity input is required
    final requireQuantityInput = ref.read(requireQuantityInputProvider);

    if (requireQuantityInput) {
      // Show quantity dialog
      final quantity = await _showQuantityDialog(context, product.name, maxStock: stock);
      if (quantity != null && quantity > 0 && mounted) {
        ref.read(cartProvider.notifier).addProduct(product, quantity: quantity);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $quantity x ${product.name}'),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } else {
      // Add directly to cart
      ref.read(cartProvider.notifier).addProduct(product);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name}'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  void _showOutOfStockAlert(String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
        title: const Text('Out of Stock'),
        content: Text(
          '$productName is currently out of stock and cannot be added to the cart.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final result = await context.push<String>('/products/scan');
    if (result != null && mounted) {
      // Find product by barcode first
      final product = await ref.read(productProvider.notifier).findByBarcode(result);

      if (product == null) {
        // Product not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product not found: $result'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Check if out of stock
      final currentLocation = ref.read(currentLocationProvider);
      final stock = product.getStockForLocation(currentLocation?.id);
      if (stock <= 0) {
        if (mounted) {
          _showOutOfStockAlert(product.name);
        }
        return;
      }

      // Check if quantity input is required
      final requireQuantityInput = ref.read(requireQuantityInputProvider);

      if (requireQuantityInput) {
        // Show quantity dialog before adding to cart
        if (!mounted) return;
        final quantity = await _showQuantityDialog(context, product.name, maxStock: stock);
        if (quantity != null && quantity > 0 && mounted) {
          ref.read(cartProvider.notifier).addProduct(product, quantity: quantity);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added $quantity x ${product.name}'),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );
        }
      } else {
        // Add directly to cart
        ref.read(cartProvider.notifier).addProduct(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${product.name}'),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );
        }
      }
    }
  }

  Future<int?> _showQuantityDialog(BuildContext context, String productName, {int? maxStock}) {
    final controller = TextEditingController(text: '1');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Quantity'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                productName,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (maxStock != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Available: $maxStock in stock',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(controller.text) ?? 1;
                      if (current > 1) {
                        controller.text = (current - 1).toString();
                      }
                    },
                    color: AppColors.textSecondary,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(controller.text) ?? 1;
                      // Limit to maxStock if provided
                      if (maxStock == null || current < maxStock) {
                        controller.text = (current + 1).toString();
                      }
                    },
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick quantity buttons (filter by maxStock if provided)
              Wrap(
                spacing: 8,
                children: [1, 5, 10, 20]
                    .where((qty) => maxStock == null || qty <= maxStock)
                    .map((qty) => ActionChip(
                          label: Text('$qty'),
                          onPressed: () => controller.text = qty.toString(),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text);
              if (qty == null || qty <= 0) {
                Navigator.pop(context, null);
                return;
              }
              // Warn if exceeds stock
              if (maxStock != null && qty > maxStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Only $maxStock available in stock'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, qty);
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showLowStockSheet(List<Product> lowStockProducts) {
    final currentLocation = ref.read(currentLocationProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Low Stock Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${lowStockProducts.length} items need restocking',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Products List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lowStockProducts.length,
                itemBuilder: (context, index) {
                  final product = lowStockProducts[index];
                  final stock = product.getStockForLocation(currentLocation?.id);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: product.image != null
                          ? CachedNetworkImage(
                              imageUrl: product.image!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.inventory_2, color: AppColors.textMuted),
                            )
                          : const Icon(Icons.inventory_2, color: AppColors.textMuted),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stock <= 0 ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stock <= 0 ? 'Out of stock' : '$stock in stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: stock <= 0 ? AppColors.error : AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/products/${product.id}/restock');
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Restock'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/products');
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Go to Products'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredProductsProvider);
    final topLevelCategories = ref.watch(topLevelCategoriesProvider);
    final subcategories = _selectedCategoryId != null
        ? ref.watch(subcategoriesProvider(_selectedCategoryId!))
        : <Category>[];
    final cart = ref.watch(cartProvider);
    final filteredProducts = _filterProducts(products);
    final currentLocation = ref.watch(currentLocationProvider);
    final viewMode = ref.watch(posViewModeProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // Decorative Header
          _buildDecorativeHeader(viewMode),

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
                child: Column(
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
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    // Low Stock Alert Banner
                    Consumer(
                      builder: (context, ref, _) {
                        final lowStockProducts = ref.watch(lowStockProductsProvider);
                        if (lowStockProducts.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => _showLowStockSheet(lowStockProducts),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${lowStockProducts.length} product${lowStockProducts.length > 1 ? 's' : ''} low on stock',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        'Tap to view and restock',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.warning),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Category Filter Chips (Top-level categories only)
                    if (topLevelCategories.isNotEmpty)
                      SizedBox(
                        height: 44,
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
                        padding: const EdgeInsets.only(top: 4),
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

                    // Products Grid or List
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No products found',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : viewMode == ProductViewMode.card
                              ? _buildGridView(filteredProducts, currentLocation, cart)
                              : _buildListView(filteredProducts, currentLocation, cart),
                    ),

                    // Cart Summary Bar (fixed at bottom)
                    if (cart.isNotEmpty)
                      _CartSummaryBar(
                        cart: cart,
                        onTap: _showCartModal,
                        onCheckout: () => context.push('/checkout'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeHeader(ProductViewMode viewMode) {
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
            Positioned(
              top: 60,
              left: 60,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentLime,
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
                      // Back button
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
                      // View mode toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.grid_view_rounded,
                                color: viewMode == ProductViewMode.card
                                    ? AppColors.accentLime
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                              onPressed: () {
                                ref.read(userPreferencesProvider.notifier)
                                    .setPosViewMode(ProductViewMode.card);
                              },
                              tooltip: 'Card View',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.view_list_rounded,
                                color: viewMode == ProductViewMode.list
                                    ? AppColors.accentLime
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                              onPressed: () {
                                ref.read(userPreferencesProvider.notifier)
                                    .setPosViewMode(ProductViewMode.list);
                              },
                              tooltip: 'List View',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Scan button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                          onPressed: _scanBarcode,
                          tooltip: 'Scan Barcode',
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
                          Icons.point_of_sale,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Sale',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Select products to add to cart',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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

  Widget _buildGridView(List<Product> products, StoreLocation? location, CartState cart) {
    return GridView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: cart.isNotEmpty ? 100 : 16,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(
          product: product,
          locationId: location?.id,
          onTap: () => _onProductTap(product),
        );
      },
    );
  }

  Widget _buildListView(List<Product> products, StoreLocation? location, CartState cart) {
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: cart.isNotEmpty ? 100 : 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductListTile(
          product: product,
          locationId: location?.id,
          onTap: () => _onProductTap(product),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String? locationId;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.locationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.getStockForLocation(locationId);
    final isOutOfStock = stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        child: Opacity(
          opacity: isOutOfStock ? 0.5 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
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
                    if (isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final stock = product.getStockForLocation(locationId);
    final isOutOfStock = stock <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        child: Opacity(
          opacity: isOutOfStock ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.image != null
                      ? CachedNetworkImage(
                          imageUrl: product.image!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.inventory_2,
                            size: 24,
                            color: AppColors.textMuted,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2,
                          size: 24,
                          color: AppColors.textMuted,
                        ),
                ),
                const SizedBox(width: 12),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isOutOfStock) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else
                      Icon(
                        Icons.add_circle,
                        color: AppColors.primary,
                        size: 28,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Cart Summary Bar - Fixed at bottom, tappable to open modal
class _CartSummaryBar extends StatelessWidget {
  final CartState cart;
  final VoidCallback onTap;
  final VoidCallback onCheckout;

  const _CartSummaryBar({
    required this.cart,
    required this.onTap,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Cart info (tappable to view cart)
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Badge(
                          label: Text('${cart.itemCount}'),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.shopping_cart, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${AppConstants.currencySymbol}${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'View Cart',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Checkout button
              ElevatedButton(
                onPressed: onCheckout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text(
                  'Checkout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Cart Modal - Full cart display
class _CartModal extends ConsumerWidget {
  final VoidCallback onCheckout;

  const _CartModal({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Cart Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart (${cart.itemCount} items)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ref.read(cartProvider.notifier).clearCart();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Cart Items
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Cart is empty',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemTile(item: item);
                    },
                  ),
          ),

          // Totals and Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                      Text('${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Tax
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
                           style: TextStyle(color: AppColors.textSecondary)),
                      Text('${AppConstants.currencySymbol}${cart.tax.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 16),
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                        '${AppConstants.currencySymbol}${cart.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Checkout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cart.items.isEmpty ? null : onCheckout,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Checkout ${AppConstants.currencySymbol}${cart.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  void _showQuantityEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(controller.text) ?? 1;
                      if (current > 1) {
                        controller.text = (current - 1).toString();
                      }
                    },
                    color: AppColors.textSecondary,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(controller.text) ?? 1;
                      controller.text = (current + 1).toString();
                    },
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(cartProvider.notifier).removeItem(item.productId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text);
              if (qty != null && qty > 0) {
                ref.read(cartProvider.notifier).setQuantity(item.productId, qty);
              }
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(cartProvider.notifier).removeItem(item.productId);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Left: Product Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.image != null
                  ? CachedNetworkImage(
                      imageUrl: item.image!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.inventory_2,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.inventory_2, size: 20, color: AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            // Left: Product Name and Subtotal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)} x ${item.quantity} = ${AppConstants.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Right: Quantity Controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    ref.read(cartProvider.notifier).decreaseQuantity(item.productId);
                  },
                  iconSize: 24,
                  visualDensity: VisualDensity.compact,
                  color: AppColors.textSecondary,
                ),
                // Tappable quantity
                GestureDetector(
                  onTap: () => _showQuantityEditDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    ref.read(cartProvider.notifier).increaseQuantity(item.productId);
                  },
                  iconSize: 24,
                  visualDensity: VisualDensity.compact,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
