import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
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

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle migration from old 'stock' field to new 'stockByLocation'
    Map<String, int> stockByLocation = {};
    if (data['stockByLocation'] != null) {
      final rawMap = data['stockByLocation'] as Map<String, dynamic>;
      stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
    } else if (data['stock'] != null) {
      // Legacy: if old 'stock' field exists, we'll handle it in the UI
      // For now, create empty map - stock will be set when editing
      stockByLocation = {};
    }

    return Product(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] ?? 0).toDouble(),
      cost: data['cost']?.toDouble(),
      barcode: data['barcode'],
      categoryId: data['categoryId'],
      subcategoryId: data['subcategoryId'],
      stockByLocation: stockByLocation,
      lowStockThreshold: data['lowStockThreshold'],
      image: data['image'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'barcode': barcode,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'stockByLocation': stockByLocation,
      'lowStockThreshold': lowStockThreshold,
      'image': image,
      'isActive': isActive,
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

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      parentId: data['parentId'],
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'parentId': parentId,
      'order': order,
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
  final FirebaseFirestore _firestore;
  final Ref _ref;
  String? _currentStoreId;
  OfflineDataService? _offlineService;

  ProductNotifier(this._ref, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
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
        // Online: fetch from Firestore and cache locally
        debugPrint('📦 Loading products from Firestore (online)');

        final snapshot = await _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('products')
            .get();

        products = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
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

  /// Force refresh products from Firestore
  Future<void> refreshProducts() async {
    debugPrint('🔄 Refreshing products...');
    await loadProducts();
  }

  Future<void> loadCategories() async {
    if (_currentStoreId == null) return;

    try {
      List<Category> categories;

      if (_isOnline) {
        // Online: fetch from Firestore and cache locally
        final snapshot = await _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('categories')
            .get();

        categories = snapshot.docs
            .map((doc) => Category.fromFirestore(doc))
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

      final docRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('products')
          .doc();

      debugPrint('📝 Creating product at: stores/$_currentStoreId/products/${docRef.id}');

      final product = Product(
        id: docRef.id,
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

      await docRef.set({
        ...product.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Product added successfully: ${product.name} (${product.id})');

      // Reload products
      debugPrint('🔄 Reloading products after add...');
      await loadProducts();

      return product;
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

      final data = product.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      debugPrint('   Data to update: $data');

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('products')
          .doc(product.id)
          .update(data);

      debugPrint('✅ Product updated in Firestore: ${product.name}');

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
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('products')
          .doc(productId)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
        final snapshot = await _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return Product.fromFirestore(snapshot.docs.first);
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

      final docRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('categories')
          .doc();

      await docRef.set({
        'storeId': _currentStoreId,
        'name': name,
        'parentId': parentId,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await loadCategories();

      return state.categories.firstWhere((c) => c.id == docRef.id);
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
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('categories')
          .doc(categoryId)
          .update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
          await _firestore
              .collection(AppConstants.storesCollection)
              .doc(_currentStoreId)
              .collection('products')
              .doc(product.id)
              .update({'categoryId': null, 'subcategoryId': null});
        }
      }

      // Delete all subcategories first
      for (final subcategory in subcategories) {
        await _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('categories')
            .doc(subcategory.id)
            .delete();
      }

      // Delete the main category
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('categories')
          .doc(categoryId)
          .delete();

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

      // Update order in Firestore
      final batch = _firestore.batch();
      for (int i = 0; i < categories.length; i++) {
        batch.update(
          _firestore
              .collection(AppConstants.storesCollection)
              .doc(_currentStoreId)
              .collection('categories')
              .doc(categories[i].id),
          {'order': i},
        );
      }
      await batch.commit();

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
