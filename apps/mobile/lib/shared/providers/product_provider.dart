import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../services/offline_data_service.dart';
import 'store_provider.dart';

// Product Model
class Product {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double price;
  final double? cost;
  final String? barcode;
  final String? categoryId;
  final String? subcategoryId; // Optional: for brand/subcategory
  final Map<String, int> stockByLocation; // {locationId: stockCount}
  final int? lowStockThreshold;
  final String? image;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.cost,
    this.barcode,
    this.categoryId,
    this.subcategoryId,
    required this.stockByLocation,
    this.lowStockThreshold,
    this.image,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Get stock for a specific location
  int getStockForLocation(String? locationId) {
    if (locationId == null) return getTotalStock();
    return stockByLocation[locationId] ?? 0;
  }

  /// Get total stock across all locations
  int getTotalStock() {
    return stockByLocation.values.fold(0, (sum, stock) => sum + stock);
  }

  /// Check if low stock for a specific location
  bool isLowStockForLocation(String? locationId) {
    final threshold = lowStockThreshold ?? 10;
    final stock = getStockForLocation(locationId);
    return stock <= threshold;
  }

  factory Product.fromSupabase(Map<String, dynamic> data) {
    // Handle stockByLocation from JSONB
    Map<String, int> stockByLocation = {};
    if (data['stock_by_location'] != null) {
      final rawMap = data['stock_by_location'] as Map<String, dynamic>;
      stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
    }

    return Product(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] ?? 0).toDouble(),
      cost: data['cost']?.toDouble(),
      barcode: data['barcode'],
      categoryId: data['category_id'],
      subcategoryId: data['subcategory_id'],
      stockByLocation: stockByLocation,
      lowStockThreshold: data['low_stock_threshold'],
      image: data['image'],
      isActive: data['is_active'] ?? true,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
      updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'barcode': barcode,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'stock_by_location': stockByLocation,
      'low_stock_threshold': lowStockThreshold,
      'image': image,
      'is_active': isActive,
    };
  }

  Product copyWith({
    String? id,
    String? storeId,
    String? name,
    String? description,
    double? price,
    double? cost,
    String? barcode,
    String? categoryId,
    String? subcategoryId,
    Map<String, int>? stockByLocation,
    int? lowStockThreshold,
    String? image,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      stockByLocation: stockByLocation ?? this.stockByLocation,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      image: image ?? this.image,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a copy with updated stock for a specific location
  Product copyWithStockForLocation(String locationId, int stock) {
    final newStockByLocation = Map<String, int>.from(stockByLocation);
    newStockByLocation[locationId] = stock;
    return copyWith(stockByLocation: newStockByLocation);
  }
}

// Category Model (supports subcategories via parentId)
class Category {
  final String id;
  final String storeId;
  final String name;
  final String? parentId; // null = top-level category, set = subcategory (e.g., brand)
  final int order;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.storeId,
    required this.name,
    this.parentId,
    required this.order,
    this.createdAt,
  });

  /// Check if this is a top-level (parent) category
  bool get isTopLevel => parentId == null;

  /// Check if this is a subcategory
  bool get isSubcategory => parentId != null;

  factory Category.fromSupabase(Map<String, dynamic> data) {
    return Category(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      name: data['name'] ?? '',
      parentId: data['parent_id'],
      order: data['sort_order'] ?? 0,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'name': name,
      'parent_id': parentId,
      'sort_order': order,
    };
  }
}

// Product State
class ProductState {
  final List<Product> products;
  final List<Category> categories;
  final bool isLoading;
  final String? error;
  final String? searchQuery;

  const ProductState({
    this.products = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
  });

  ProductState copyWith({
    List<Product>? products,
    List<Category>? categories,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return ProductState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Product> get activeProducts => products.where((p) => p.isActive).toList();

  /// Get low stock products for a specific location
  List<Product> getLowStockProducts(String? locationId) {
    return activeProducts.where((p) => p.isLowStockForLocation(locationId)).toList();
  }
}

// Product Notifier
class ProductNotifier extends StateNotifier<ProductState> {
  final SupabaseClient _supabase;
  final Ref _ref;
  String? _currentStoreId;
  OfflineDataService? _offlineService;

  ProductNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const ProductState()) {
    _init();
  }

  /// Get connectivity status
  bool get _isOnline => _ref.read(connectivityProvider).isOnline;

  /// Get offline service
  OfflineDataService get _offline {
    _offlineService ??= _ref.read(offlineDataServiceProvider);
    return _offlineService!;
  }

  void _init() {
    // Listen to store changes
    _ref.listen<StoreState>(storeProvider, (previous, next) {
      debugPrint('📦 Store state changed: store=${next.store?.id}, currentStoreId=$_currentStoreId');
      if (next.store != null && next.store!.id != _currentStoreId) {
        _currentStoreId = next.store!.id;
        debugPrint('📦 Loading products for store: $_currentStoreId');
        loadProducts();
        loadCategories();
      }
    }, fireImmediately: true); // Fire immediately to catch current state

    // Listen to connectivity changes to refresh from server when back online
    _ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (previous?.isOffline == true && next.isOnline && _currentStoreId != null) {
        debugPrint('📦 Back online - refreshing products from server');
        loadProducts();
        loadCategories();
      }
    });
  }

  Future<void> loadProducts() async {
    if (_currentStoreId == null) {
      debugPrint('⚠️ Cannot load products: no store ID');
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      List<Product> products;

      if (_isOnline) {
        // Online: fetch from Supabase and cache locally
        debugPrint('📦 Loading products from Supabase (online)');

        final response = await _supabase
            .from('products')
            .select()
            .eq('store_id', _currentStoreId!);

        products = (response as List)
            .map((data) => Product.fromSupabase(data))
            .toList();

        // Cache products locally for offline use
        await _offline.cacheProducts(products);
      } else {
        // Offline: load from local cache
        debugPrint('📦 Loading products from local cache (offline)');
        products = await _offline.getLocalProducts(_currentStoreId!);
      }

      // Sort in memory
      products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      debugPrint('📦 Loaded ${products.length} products for store $_currentStoreId (${_isOnline ? 'online' : 'offline'})');
      state = state.copyWith(products: products, isLoading: false);
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading products: $e');
      debugPrint('   Stack trace: $stackTrace');

      // If online fetch fails, try loading from cache
      if (_isOnline) {
        debugPrint('📦 Falling back to local cache...');
        try {
          final products = await _offline.getLocalProducts(_currentStoreId!);
          products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          state = state.copyWith(products: products, isLoading: false);
          return;
        } catch (_) {}
      }

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Force refresh products from Supabase
  Future<void> refreshProducts() async {
    debugPrint('🔄 Refreshing products...');
    await loadProducts();
  }

  Future<void> loadCategories() async {
    if (_currentStoreId == null) return;

    try {
      List<Category> categories;

      if (_isOnline) {
        // Online: fetch from Supabase and cache locally
        final response = await _supabase
            .from('categories')
            .select()
            .eq('store_id', _currentStoreId!);

        categories = (response as List)
            .map((data) => Category.fromSupabase(data))
            .toList();

        // Cache categories locally
        await _offline.cacheCategories(categories);
      } else {
        // Offline: load from local cache
        categories = await _offline.getLocalCategories(_currentStoreId!);
      }

      // Sort in memory
      categories.sort((a, b) => a.order.compareTo(b.order));

      debugPrint('📂 Loaded ${categories.length} categories (${_isOnline ? 'online' : 'offline'})');
      state = state.copyWith(categories: categories);
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');

      // Fallback to cache
      if (_isOnline) {
        try {
          final categories = await _offline.getLocalCategories(_currentStoreId!);
          categories.sort((a, b) => a.order.compareTo(b.order));
          state = state.copyWith(categories: categories);
        } catch (_) {}
      }
    }
  }

  Future<Product> addProduct({
    required String name,
    String? description,
    required double price,
    double? cost,
    String? barcode,
    String? categoryId,
    String? subcategoryId,
    required String locationId,
    required int stock,
    int? lowStockThreshold,
    String? image,
  }) async {
    debugPrint('📝 Adding product: $name to store $_currentStoreId, location: $locationId');

    if (_currentStoreId == null) {
      debugPrint('❌ No store selected! Cannot add product.');
      throw Exception('No store selected');
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final product = Product(
        id: '', // Will be set by Supabase
        storeId: _currentStoreId!,
        name: name,
        description: description,
        price: price,
        cost: cost,
        barcode: barcode,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        stockByLocation: {locationId: stock},
        lowStockThreshold: lowStockThreshold ?? 10,
        image: image,
        isActive: true,
      );

      final response = await _supabase
          .from('products')
          .insert(product.toSupabase())
          .select()
          .single();

      final newProduct = Product.fromSupabase(response);

      debugPrint('✅ Product added successfully: ${newProduct.name} (${newProduct.id})');

      // Reload products
      debugPrint('🔄 Reloading products after add...');
      await loadProducts();

      return newProduct;
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      state = state.copyWith(isLoading: true, error: null);
      debugPrint('📝 Updating product: ${product.name} (${product.id})');
      debugPrint('   Store ID: $_currentStoreId');
      debugPrint('   Stock by location: ${product.stockByLocation}');

      await _supabase
          .from('products')
          .update(product.toSupabase())
          .eq('id', product.id);

      debugPrint('✅ Product updated in Supabase: ${product.name}');

      // Reload products
      debugPrint('🔄 Reloading products after update...');
      await loadProducts();
      debugPrint('✅ Products reloaded successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating product: $e');
      debugPrint('   Stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Soft delete - set isActive to false
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);

      debugPrint('✅ Product deleted (soft)');

      // Reload products
      await loadProducts();
    } catch (e) {
      debugPrint('❌ Error deleting product: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<Product?> findByBarcode(String barcode) async {
    if (_currentStoreId == null) return null;

    try {
      if (_isOnline) {
        final response = await _supabase
            .from('products')
            .select()
            .eq('store_id', _currentStoreId!)
            .eq('barcode', barcode)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          return Product.fromSupabase(response);
        }
      }

      // Search locally (as fallback when online or primary when offline)
      return await _offline.findProductByBarcode(_currentStoreId!, barcode);
    } catch (e) {
      debugPrint('❌ Error finding product by barcode: $e');
      // Try local fallback
      return await _offline.findProductByBarcode(_currentStoreId!, barcode);
    }
  }

  Future<Category> addCategory(String name, {String? parentId}) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      // Count categories at same level for ordering
      final sameLevelCategories = state.categories.where((c) => c.parentId == parentId);
      final order = sameLevelCategories.length;

      final response = await _supabase
          .from('categories')
          .insert({
            'store_id': _currentStoreId,
            'name': name,
            'parent_id': parentId,
            'sort_order': order,
          })
          .select()
          .single();

      await loadCategories();

      return Category.fromSupabase(response);
    } catch (e) {
      debugPrint('❌ Error adding category: $e');
      rethrow;
    }
  }

  /// Add a subcategory (brand) under a parent category
  Future<Category> addSubcategory(String parentId, String name) async {
    return addCategory(name, parentId: parentId);
  }

  Future<void> updateCategory(String categoryId, String name) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      await _supabase
          .from('categories')
          .update({'name': name})
          .eq('id', categoryId);

      debugPrint('✅ Category updated: $name');
      await loadCategories();
    } catch (e) {
      debugPrint('❌ Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      // Find all subcategories of this category
      final subcategories = state.categories.where((c) => c.parentId == categoryId);
      final allCategoryIds = [categoryId, ...subcategories.map((c) => c.id)];

      // Remove category/subcategory from all products that have it
      for (final catId in allCategoryIds) {
        final productsWithCategory = state.products.where((p) => p.categoryId == catId);
        for (final product in productsWithCategory) {
          await _supabase
              .from('products')
              .update({'category_id': null, 'subcategory_id': null})
              .eq('id', product.id);
        }
      }

      // Delete all subcategories first
      for (final subcategory in subcategories) {
        await _supabase
            .from('categories')
            .delete()
            .eq('id', subcategory.id);
      }

      // Delete the main category
      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId);

      debugPrint('✅ Category and ${subcategories.length} subcategories deleted');
      await loadCategories();
      await loadProducts();
    } catch (e) {
      debugPrint('❌ Error deleting category: $e');
      rethrow;
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (_currentStoreId == null) throw Exception('No store selected');

    try {
      // Adjust newIndex for the removal
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Create a mutable copy of categories
      final categories = List<Category>.from(state.categories);
      final movedCategory = categories.removeAt(oldIndex);
      categories.insert(newIndex, movedCategory);

      // Update order in Supabase one by one
      for (int i = 0; i < categories.length; i++) {
        await _supabase
            .from('categories')
            .update({'sort_order': i})
            .eq('id', categories[i].id);
      }

      debugPrint('✅ Categories reordered');
      await loadCategories();
    } catch (e) {
      debugPrint('❌ Error reordering categories: $e');
      rethrow;
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  List<Product> get filteredProducts {
    var products = state.activeProducts;
    final query = state.searchQuery?.toLowerCase();

    if (query != null && query.isNotEmpty) {
      products = products.where((p) =>
          p.name.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false) ||
          (p.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return products;
  }
}

// Providers
final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(ref);
});

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final state = ref.watch(productProvider);
  final query = state.searchQuery?.toLowerCase();
  var products = state.activeProducts;

  if (query != null && query.isNotEmpty) {
    products = products.where((p) =>
        p.name.toLowerCase().contains(query) ||
        (p.barcode?.toLowerCase().contains(query) ?? false) ||
        (p.description?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  debugPrint('🔍 Filtered products: ${products.length} (total: ${state.products.length}, active: ${state.activeProducts.length})');
  return products;
});

final lowStockProductsProvider = Provider<List<Product>>((ref) {
  final currentLocation = ref.watch(currentLocationProvider);
  final productState = ref.watch(productProvider);
  return productState.getLowStockProducts(currentLocation?.id);
});

final categoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(productProvider).categories;
});

/// Provider for top-level categories only (no parent)
final topLevelCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider);
  return categories.where((c) => c.isTopLevel).toList();
});

/// Provider for subcategories of a specific parent category
final subcategoriesProvider = Provider.family<List<Category>, String>((ref, parentId) {
  final categories = ref.watch(categoriesProvider);
  return categories.where((c) => c.parentId == parentId).toList();
});

/// Get all subcategories (for any parent)
final allSubcategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider);
  return categories.where((c) => c.isSubcategory).toList();
});
