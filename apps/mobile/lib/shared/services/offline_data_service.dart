import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/hive_service.dart';
import '../../core/database/hive_models.dart';
import '../providers/product_provider.dart';
import '../providers/store_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/cart_provider.dart';

/// Service for managing offline data operations
/// Acts as a bridge between Firebase models and local Hive models
class OfflineDataService {
  final HiveService _hive;

  OfflineDataService({HiveService? hive}) : _hive = hive ?? HiveService.instance;

  // ==================== Product Conversions ====================

  /// Convert Firebase Product to LocalProduct
  LocalProduct productToLocal(Product product) {
    return LocalProduct(
      firestoreId: product.id,
      storeId: product.storeId,
      name: product.name,
      description: product.description,
      price: product.price,
      cost: product.cost,
      barcode: product.barcode,
      categoryId: product.categoryId,
      subcategoryId: product.subcategoryId,
      stockByLocation: product.stockByLocation,
      lowStockThreshold: product.lowStockThreshold,
      image: product.image,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      lastSyncedAt: DateTime.now(),
      needsSync: false,
    );
  }

  /// Convert LocalProduct to Firebase Product
  Product localToProduct(LocalProduct local) {
    return Product(
      id: local.firestoreId,
      storeId: local.storeId,
      name: local.name,
      description: local.description,
      price: local.price,
      cost: local.cost,
      barcode: local.barcode,
      categoryId: local.categoryId,
      subcategoryId: local.subcategoryId,
      stockByLocation: local.stockByLocation,
      lowStockThreshold: local.lowStockThreshold,
      image: local.image,
      isActive: local.isActive,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  /// Cache products locally
  Future<void> cacheProducts(List<Product> products) async {
    final localProducts = products.map(productToLocal).toList();
    await _hive.saveProducts(localProducts);
    debugPrint('📦 Offline: Cached ${products.length} products');
  }

  /// Get products from local cache
  Future<List<Product>> getLocalProducts(String storeId) async {
    final localProducts = await _hive.getProductsForStore(storeId);
    return localProducts.map(localToProduct).toList();
  }

  /// Find product by barcode locally
  Future<Product?> findProductByBarcode(String storeId, String barcode) async {
    final local = await _hive.getProductByBarcode(storeId, barcode);
    return local != null ? localToProduct(local) : null;
  }

  /// Update local product stock
  Future<void> updateLocalProductStock(String productId, String locationId, int newStock) async {
    final local = await _hive.getProductByFirestoreId(productId);
    if (local != null) {
      final stockMap = Map<String, int>.from(local.stockByLocation);
      stockMap[locationId] = newStock;
      final updated = local.copyWith(stockByLocation: stockMap, needsSync: true);
      await _hive.saveProduct(updated);
      debugPrint('📦 Offline: Updated stock for $productId at $locationId: $newStock');
    }
  }

  // ==================== Category Conversions ====================

  /// Convert Firebase Category to LocalCategory
  LocalCategory categoryToLocal(Category category) {
    return LocalCategory(
      firestoreId: category.id,
      storeId: category.storeId,
      name: category.name,
      parentId: category.parentId,
      order: category.order,
      createdAt: category.createdAt,
      lastSyncedAt: DateTime.now(),
      needsSync: false,
    );
  }

  /// Convert LocalCategory to Firebase Category
  Category localToCategory(LocalCategory local) {
    return Category(
      id: local.firestoreId,
      storeId: local.storeId,
      name: local.name,
      parentId: local.parentId,
      order: local.order,
      createdAt: local.createdAt,
    );
  }

  /// Cache categories locally
  Future<void> cacheCategories(List<Category> categories) async {
    final localCategories = categories.map(categoryToLocal).toList();
    await _hive.saveCategories(localCategories);
    debugPrint('📦 Offline: Cached ${categories.length} categories');
  }

  /// Get categories from local cache
  Future<List<Category>> getLocalCategories(String storeId) async {
    final localCategories = await _hive.getCategoriesForStore(storeId);
    return localCategories.map((lc) => localToCategory(lc)).toList();
  }

  // ==================== Store Conversions ====================

  /// Convert Firebase Store to LocalStore
  LocalStore storeToLocal(Store store) {
    return LocalStore(
      firestoreId: store.id,
      name: store.name,
      businessType: store.businessType,
      hasMultipleLocations: store.hasMultipleLocations,
      logo: store.logo,
      ownerId: store.ownerId,
      settings: store.settings,
      isActive: store.isActive,
      createdAt: store.createdAt,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Convert LocalStore to Firebase Store
  Store localToStore(LocalStore local) {
    return Store(
      id: local.firestoreId,
      name: local.name,
      businessType: local.businessType,
      hasMultipleLocations: local.hasMultipleLocations,
      logo: local.logo,
      ownerId: local.ownerId,
      settings: local.settings,
      isActive: local.isActive,
      createdAt: local.createdAt,
    );
  }

  /// Cache store locally
  Future<void> cacheStore(Store store) async {
    final localStore = storeToLocal(store);
    await _hive.saveStore(localStore);
    debugPrint('📦 Offline: Cached store ${store.name}');
  }

  /// Get store from local cache
  Future<Store?> getLocalStore(String storeId) async {
    final local = await _hive.getStoreByFirestoreId(storeId);
    return local != null ? localToStore(local) : null;
  }

  // ==================== Location Conversions ====================

  /// Convert Firebase StoreLocation to LocalStoreLocation
  LocalStoreLocation locationToLocal(StoreLocation location) {
    return LocalStoreLocation(
      firestoreId: location.id,
      storeId: location.storeId,
      name: location.name,
      address: location.address,
      phone: location.phone,
      isDefault: location.isDefault,
      isActive: location.isActive,
      createdAt: location.createdAt,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Convert LocalStoreLocation to Firebase StoreLocation
  StoreLocation localToLocation(LocalStoreLocation local) {
    return StoreLocation(
      id: local.firestoreId,
      storeId: local.storeId,
      name: local.name,
      address: local.address,
      phone: local.phone,
      isDefault: local.isDefault,
      isActive: local.isActive,
      createdAt: local.createdAt,
    );
  }

  /// Cache locations locally
  Future<void> cacheLocations(List<StoreLocation> locations) async {
    final localLocations = locations.map(locationToLocal).toList();
    await _hive.saveLocations(localLocations);
    debugPrint('📦 Offline: Cached ${locations.length} locations');
  }

  /// Get locations from local cache
  Future<List<StoreLocation>> getLocalLocations(String storeId) async {
    final localLocations = await _hive.getLocationsForStore(storeId);
    return localLocations.map(localToLocation).toList();
  }

  // ==================== Transaction Operations ====================

  /// Create offline transaction
  Future<LocalTransaction> createOfflineTransaction({
    required String storeId,
    required String locationId,
    required CartState cart,
    required double amountReceived,
    required String staffId,
    required String staffName,
    String paymentMethod = 'cash',
  }) async {
    // Generate offline receipt number
    final offlineReceiptNumber = _hive.generateOfflineReceiptNumber();

    // Convert cart items
    final items = cart.items.map((item) => TransactionItemData(
      productId: item.productId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      subtotal: item.subtotal,
    )).toList();

    final transaction = LocalTransaction(
      firestoreId: '',
      storeId: storeId,
      locationId: locationId,
      receiptNumber: offlineReceiptNumber,
      offlineReceiptNumber: offlineReceiptNumber,
      customerId: cart.customerId,
      customerName: cart.customerName,
      staffId: staffId,
      staffName: staffName,
      items: items,
      subtotal: cart.subtotal,
      taxRate: cart.taxRate,
      tax: cart.tax,
      total: cart.total,
      paymentMethod: paymentMethod,
      amountReceived: amountReceived,
      change: amountReceived - cart.total,
      createdAt: DateTime.now(),
      isOfflineTransaction: true,
      needsSync: true,
    );

    await _hive.saveTransaction(transaction);

    // Update local product stock
    for (final item in cart.items) {
      await _decrementLocalStock(item.productId, locationId, item.quantity);
    }

    debugPrint('📦 Offline: Created transaction $offlineReceiptNumber');
    return transaction;
  }

  /// Decrement local stock for a product
  Future<void> _decrementLocalStock(String productId, String locationId, int quantity) async {
    final local = await _hive.getProductByFirestoreId(productId);
    if (local != null) {
      final stockMap = Map<String, int>.from(local.stockByLocation);
      final currentStock = stockMap[locationId] ?? 0;
      stockMap[locationId] = (currentStock - quantity).clamp(0, double.infinity).toInt();
      final updated = local.copyWith(stockByLocation: stockMap);
      await _hive.saveProduct(updated);
    }
  }

  /// Convert LocalTransaction to SaleTransaction
  SaleTransaction localToTransaction(LocalTransaction local) {
    return SaleTransaction(
      id: local.firestoreId.isNotEmpty ? local.firestoreId : 'local_${local.receiptNumber}',
      storeId: local.storeId,
      locationId: local.locationId,
      receiptNumber: local.receiptNumber,
      customerId: local.customerId,
      customerName: local.customerName,
      staffId: local.staffId,
      staffName: local.staffName,
      items: local.items.map((e) => TransactionItem(
        productId: e.productId,
        name: e.name,
        price: e.price,
        quantity: e.quantity,
        subtotal: e.subtotal,
      )).toList(),
      subtotal: local.subtotal,
      taxRate: local.taxRate,
      tax: local.tax,
      total: local.total,
      paymentMethod: local.paymentMethod,
      amountReceived: local.amountReceived,
      change: local.change,
      createdAt: local.createdAt,
    );
  }

  /// Get today's transactions from local cache
  Future<List<SaleTransaction>> getLocalTodayTransactions(String storeId) async {
    final localTransactions = await _hive.getTodayTransactions(storeId);
    return localTransactions.map(localToTransaction).toList();
  }

  // ==================== Stock History Operations ====================

  /// Create offline stock history entry
  Future<void> createOfflineStockHistory({
    required Product product,
    required String locationId,
    required String locationName,
    required int quantityAdded,
    required int previousStock,
    required int newStock,
    String? notes,
    String? userId,
    String? userName,
  }) async {
    final history = LocalStockHistory(
      firestoreId: '',
      productId: product.id,
      productName: product.name,
      locationId: locationId,
      locationName: locationName,
      quantityAdded: quantityAdded,
      previousStock: previousStock,
      newStock: newStock,
      notes: notes,
      userId: userId,
      userName: userName,
      createdAt: DateTime.now(),
      needsSync: true,
    );

    await _hive.saveStockHistory(history);

    // Update local product stock
    await updateLocalProductStock(product.id, locationId, newStock);

    debugPrint('📦 Offline: Created stock history for ${product.name}');
  }

  /// Convert LocalStockHistory to StockHistory
  StockHistory localToStockHistory(LocalStockHistory local) {
    return StockHistory(
      id: local.firestoreId.isNotEmpty ? local.firestoreId : 'local_${local.createdAt.millisecondsSinceEpoch}',
      productId: local.productId,
      productName: local.productName,
      locationId: local.locationId,
      locationName: local.locationName,
      quantityAdded: local.quantityAdded,
      previousStock: local.previousStock,
      newStock: local.newStock,
      notes: local.notes,
      userId: local.userId,
      userName: local.userName,
      createdAt: local.createdAt,
    );
  }

  /// Get stock history for a product from local cache
  Future<List<StockHistory>> getLocalStockHistory(String productId) async {
    final localHistory = await _hive.getStockHistoryForProduct(productId);
    return localHistory.map(localToStockHistory).toList();
  }

  // ==================== Cart Persistence ====================

  /// Save cart to local storage
  Future<void> persistCart(String storeId, CartState cart) async {
    final cartItems = cart.items.map((item) => CartItemData(
      productId: item.productId,
      name: item.name,
      price: item.price,
      image: item.image,
      quantity: item.quantity,
    )).toList();

    final localCart = LocalCart(
      storeId: storeId,
      items: cartItems,
      customerId: cart.customerId,
      customerName: cart.customerName,
      taxRate: cart.taxRate,
      updatedAt: DateTime.now(),
    );

    await _hive.saveCart(localCart);
    debugPrint('📦 Offline: Persisted cart with ${cart.items.length} items');
  }

  /// Restore cart from local storage
  Future<List<CartItem>> restoreCart(String storeId) async {
    final localCart = await _hive.getCart(storeId);
    if (localCart == null) return [];

    return localCart.items.map((data) => CartItem(
      productId: data.productId,
      name: data.name,
      price: data.price,
      image: data.image,
      quantity: data.quantity,
    )).toList();
  }

  /// Clear persisted cart
  Future<void> clearPersistedCart(String storeId) async {
    await _hive.clearCart(storeId);
    debugPrint('📦 Offline: Cleared persisted cart');
  }

  // ==================== User Session ====================

  /// Cache user session for offline access
  Future<void> cacheUserSession({
    required String uid,
    required String email,
    String? fullName,
    String? displayName,
    String? role,
    String? storeId,
    String? defaultLocationId,
  }) async {
    final session = LocalUserSession(
      uid: uid,
      email: email,
      fullName: fullName,
      displayName: displayName,
      role: role,
      storeId: storeId,
      defaultLocationId: defaultLocationId,
      cachedAt: DateTime.now(),
    );

    await _hive.saveUserSession(session);
    debugPrint('📦 Offline: Cached user session for $email');
  }

  /// Get cached user session
  Future<Map<String, dynamic>?> getCachedUserSession(String uid) async {
    final session = await _hive.getUserSession(uid);
    if (session == null) return null;

    return {
      'uid': session.uid,
      'email': session.email,
      'fullName': session.fullName,
      'displayName': session.displayName,
      'role': session.role,
      'storeId': session.storeId,
      'defaultLocationId': session.defaultLocationId,
    };
  }

  /// Clear all cached data on logout
  Future<void> clearAllCache() async {
    await _hive.clearAll();
    debugPrint('📦 Offline: Cleared all cached data');
  }

  // ==================== Sync Status ====================

  /// Get pending sync counts
  Future<Map<String, int>> getPendingSyncCounts() async {
    final transactions = await _hive.countPendingSyncTransactions();
    final operations = await _hive.countPendingSyncOperations();

    return {
      'transactions': transactions,
      'operations': operations,
      'total': transactions + operations,
    };
  }
}

/// Provider for offline data service
final offlineDataServiceProvider = Provider<OfflineDataService>((ref) {
  return OfflineDataService();
});
