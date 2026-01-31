import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'hive_models.dart';

/// Box names for Hive storage
class HiveBoxes {
  static const String products = 'products';
  static const String categories = 'categories';
  static const String stores = 'stores';
  static const String locations = 'locations';
  static const String transactions = 'transactions';
  static const String stockHistory = 'stockHistory';
  static const String syncQueue = 'syncQueue';
  static const String cart = 'cart';
  static const String syncStatus = 'syncStatus';
  static const String userSession = 'userSession';
}

/// Service for managing the local Hive database
class HiveService {
  static HiveService? _instance;
  static bool _initialized = false;
  final _uuid = const Uuid();

  HiveService._();

  /// Get the singleton instance
  static HiveService get instance {
    _instance ??= HiveService._();
    return _instance!;
  }

  /// Check if database is initialized
  bool get isInitialized => _initialized;

  /// Initialize the Hive database
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('📦 Hive: Already initialized');
      return;
    }

    try {
      await Hive.initFlutter();

      // Open all boxes
      await Future.wait([
        Hive.openBox<String>(HiveBoxes.products),
        Hive.openBox<String>(HiveBoxes.categories),
        Hive.openBox<String>(HiveBoxes.stores),
        Hive.openBox<String>(HiveBoxes.locations),
        Hive.openBox<String>(HiveBoxes.transactions),
        Hive.openBox<String>(HiveBoxes.stockHistory),
        Hive.openBox<String>(HiveBoxes.syncQueue),
        Hive.openBox<String>(HiveBoxes.cart),
        Hive.openBox<String>(HiveBoxes.syncStatus),
        Hive.openBox<String>(HiveBoxes.userSession),
      ]);

      _initialized = true;
      debugPrint('📦 Hive: Database initialized');
    } catch (e) {
      debugPrint('❌ Hive: Failed to initialize database: $e');
      rethrow;
    }
  }

  /// Close the database
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
    debugPrint('📦 Hive: Database closed');
  }

  /// Clear all data (use for logout)
  Future<void> clearAll() async {
    await Hive.box<String>(HiveBoxes.products).clear();
    await Hive.box<String>(HiveBoxes.categories).clear();
    await Hive.box<String>(HiveBoxes.stores).clear();
    await Hive.box<String>(HiveBoxes.locations).clear();
    await Hive.box<String>(HiveBoxes.transactions).clear();
    await Hive.box<String>(HiveBoxes.stockHistory).clear();
    await Hive.box<String>(HiveBoxes.syncQueue).clear();
    await Hive.box<String>(HiveBoxes.cart).clear();
    await Hive.box<String>(HiveBoxes.syncStatus).clear();
    await Hive.box<String>(HiveBoxes.userSession).clear();
    debugPrint('📦 Hive: All data cleared');
  }

  /// Clear only sync-related data
  Future<void> clearSyncQueue() async {
    await Hive.box<String>(HiveBoxes.syncQueue).clear();
    debugPrint('📦 Hive: Sync queue cleared');
  }

  // ==================== Product Operations ====================

  Box<String> get _productsBox => Hive.box<String>(HiveBoxes.products);

  /// Save a product to local storage
  Future<void> saveProduct(LocalProduct product) async {
    await _productsBox.put(product.firestoreId, jsonEncode(product.toJson()));
  }

  /// Save multiple products
  Future<void> saveProducts(List<LocalProduct> products) async {
    final map = <String, String>{};
    for (final product in products) {
      map[product.firestoreId] = jsonEncode(product.toJson());
    }
    await _productsBox.putAll(map);
  }

  /// Get product by Firestore ID
  Future<LocalProduct?> getProductByFirestoreId(String firestoreId) async {
    final json = _productsBox.get(firestoreId);
    if (json == null) return null;
    return LocalProduct.fromJson(jsonDecode(json));
  }

  /// Get all products for a store
  Future<List<LocalProduct>> getProductsForStore(String storeId) async {
    final products = <LocalProduct>[];
    for (final json in _productsBox.values) {
      final product = LocalProduct.fromJson(jsonDecode(json));
      if (product.storeId == storeId && product.isActive) {
        products.add(product);
      }
    }
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }

  /// Get product by barcode
  Future<LocalProduct?> getProductByBarcode(String storeId, String barcode) async {
    for (final json in _productsBox.values) {
      final product = LocalProduct.fromJson(jsonDecode(json));
      if (product.storeId == storeId &&
          product.barcode == barcode &&
          product.isActive) {
        return product;
      }
    }
    return null;
  }

  /// Get products needing sync
  Future<List<LocalProduct>> getProductsNeedingSync() async {
    final products = <LocalProduct>[];
    for (final json in _productsBox.values) {
      final product = LocalProduct.fromJson(jsonDecode(json));
      if (product.needsSync) {
        products.add(product);
      }
    }
    return products;
  }

  /// Delete product
  Future<void> deleteProduct(String firestoreId) async {
    await _productsBox.delete(firestoreId);
  }

  // ==================== Category Operations ====================

  Box<String> get _categoriesBox => Hive.box<String>(HiveBoxes.categories);

  /// Save categories
  Future<void> saveCategories(List<LocalCategory> categories) async {
    final map = <String, String>{};
    for (final category in categories) {
      map[category.firestoreId] = jsonEncode(category.toJson());
    }
    await _categoriesBox.putAll(map);
  }

  /// Get categories for a store
  Future<List<LocalCategory>> getCategoriesForStore(String storeId) async {
    final categories = <LocalCategory>[];
    for (final json in _categoriesBox.values) {
      final category = LocalCategory.fromJson(jsonDecode(json));
      if (category.storeId == storeId) {
        categories.add(category);
      }
    }
    categories.sort((a, b) => a.order.compareTo(b.order));
    return categories;
  }

  // ==================== Store Operations ====================

  Box<String> get _storesBox => Hive.box<String>(HiveBoxes.stores);

  /// Save store
  Future<void> saveStore(LocalStore store) async {
    await _storesBox.put(store.firestoreId, jsonEncode(store.toJson()));
  }

  /// Get store by Firestore ID
  Future<LocalStore?> getStoreByFirestoreId(String firestoreId) async {
    final json = _storesBox.get(firestoreId);
    if (json == null) return null;
    return LocalStore.fromJson(jsonDecode(json));
  }

  // ==================== Location Operations ====================

  Box<String> get _locationsBox => Hive.box<String>(HiveBoxes.locations);

  /// Save locations
  Future<void> saveLocations(List<LocalStoreLocation> locations) async {
    final map = <String, String>{};
    for (final location in locations) {
      map[location.firestoreId] = jsonEncode(location.toJson());
    }
    await _locationsBox.putAll(map);
  }

  /// Get locations for a store
  Future<List<LocalStoreLocation>> getLocationsForStore(String storeId) async {
    final locations = <LocalStoreLocation>[];
    for (final json in _locationsBox.values) {
      final location = LocalStoreLocation.fromJson(jsonDecode(json));
      if (location.storeId == storeId && location.isActive) {
        locations.add(location);
      }
    }
    return locations;
  }

  // ==================== Transaction Operations ====================

  Box<String> get _transactionsBox => Hive.box<String>(HiveBoxes.transactions);

  /// Save transaction
  Future<String> saveTransaction(LocalTransaction transaction) async {
    final id = transaction.firestoreId.isNotEmpty
        ? transaction.firestoreId
        : 'local_${_uuid.v4()}';
    await _transactionsBox.put(id, jsonEncode(transaction.toJson()));
    return id;
  }

  /// Get transactions for a store (today's)
  Future<List<LocalTransaction>> getTodayTransactions(String storeId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final transactions = <LocalTransaction>[];
    for (final json in _transactionsBox.values) {
      final transaction = LocalTransaction.fromJson(jsonDecode(json));
      if (transaction.storeId == storeId &&
          transaction.createdAt.isAfter(startOfDay)) {
        transactions.add(transaction);
      }
    }
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  /// Get pending sync transactions
  Future<List<LocalTransaction>> getPendingSyncTransactions() async {
    final transactions = <LocalTransaction>[];
    for (final json in _transactionsBox.values) {
      final transaction = LocalTransaction.fromJson(jsonDecode(json));
      if (transaction.needsSync) {
        transactions.add(transaction);
      }
    }
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return transactions;
  }

  /// Get transaction by receipt number
  Future<LocalTransaction?> getTransactionByReceipt(String receiptNumber) async {
    for (final json in _transactionsBox.values) {
      final transaction = LocalTransaction.fromJson(jsonDecode(json));
      if (transaction.receiptNumber == receiptNumber) {
        return transaction;
      }
    }
    return null;
  }

  /// Count pending sync transactions
  Future<int> countPendingSyncTransactions() async {
    int count = 0;
    for (final json in _transactionsBox.values) {
      final transaction = LocalTransaction.fromJson(jsonDecode(json));
      if (transaction.needsSync) {
        count++;
      }
    }
    return count;
  }

  /// Update transaction
  Future<void> updateTransaction(String id, LocalTransaction transaction) async {
    await _transactionsBox.put(id, jsonEncode(transaction.toJson()));
  }

  // ==================== Stock History Operations ====================

  Box<String> get _stockHistoryBox => Hive.box<String>(HiveBoxes.stockHistory);

  /// Save stock history
  Future<String> saveStockHistory(LocalStockHistory history) async {
    final id = history.firestoreId.isNotEmpty
        ? history.firestoreId
        : 'local_${_uuid.v4()}';
    await _stockHistoryBox.put(id, jsonEncode(history.toJson()));
    return id;
  }

  /// Get stock history for product
  Future<List<LocalStockHistory>> getStockHistoryForProduct(String productId, {int limit = 50}) async {
    final history = <LocalStockHistory>[];
    for (final json in _stockHistoryBox.values) {
      final entry = LocalStockHistory.fromJson(jsonDecode(json));
      if (entry.productId == productId) {
        history.add(entry);
      }
    }
    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return history.take(limit).toList();
  }

  /// Get pending sync stock history
  Future<List<LocalStockHistory>> getPendingSyncStockHistory() async {
    final history = <LocalStockHistory>[];
    for (final json in _stockHistoryBox.values) {
      final entry = LocalStockHistory.fromJson(jsonDecode(json));
      if (entry.needsSync) {
        history.add(entry);
      }
    }
    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return history;
  }

  /// Update stock history
  Future<void> updateStockHistory(String id, LocalStockHistory history) async {
    await _stockHistoryBox.put(id, jsonEncode(history.toJson()));
  }

  // ==================== Sync Queue Operations ====================

  Box<String> get _syncQueueBox => Hive.box<String>(HiveBoxes.syncQueue);

  /// Add operation to sync queue
  Future<String> addToSyncQueue(SyncOperation operation) async {
    final id = operation.id.isNotEmpty ? operation.id : _uuid.v4();
    final op = SyncOperation(
      id: id,
      operationType: operation.operationType,
      entityType: operation.entityType,
      entityId: operation.entityId,
      firestoreId: operation.firestoreId,
      data: operation.data,
      retryCount: operation.retryCount,
      lastError: operation.lastError,
      createdAt: operation.createdAt,
      lastAttemptAt: operation.lastAttemptAt,
      status: operation.status,
    );
    await _syncQueueBox.put(id, jsonEncode(op.toJson()));
    return id;
  }

  /// Get pending sync operations
  Future<List<SyncOperation>> getPendingSyncOperations({int limit = 50}) async {
    final operations = <SyncOperation>[];
    for (final json in _syncQueueBox.values) {
      final op = SyncOperation.fromJson(jsonDecode(json));
      if (op.status == 'PENDING') {
        operations.add(op);
      }
    }
    operations.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return operations.take(limit).toList();
  }

  /// Update sync operation status
  Future<void> updateSyncOperationStatus(String id, String status, {String? error}) async {
    final json = _syncQueueBox.get(id);
    if (json != null) {
      final op = SyncOperation.fromJson(jsonDecode(json));
      final updated = op.copyWith(
        status: status,
        lastAttemptAt: DateTime.now(),
        lastError: error,
        retryCount: error != null ? op.retryCount + 1 : op.retryCount,
      );
      await _syncQueueBox.put(id, jsonEncode(updated.toJson()));
    }
  }

  /// Remove completed sync operations
  Future<void> removeCompletedSyncOperations() async {
    final keysToRemove = <String>[];
    for (final entry in _syncQueueBox.toMap().entries) {
      final op = SyncOperation.fromJson(jsonDecode(entry.value));
      if (op.status == 'COMPLETED') {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      await _syncQueueBox.delete(key);
    }
  }

  /// Count pending sync operations
  Future<int> countPendingSyncOperations() async {
    int count = 0;
    for (final json in _syncQueueBox.values) {
      final op = SyncOperation.fromJson(jsonDecode(json));
      if (op.status == 'PENDING') {
        count++;
      }
    }
    return count;
  }

  // ==================== Cart Operations ====================

  Box<String> get _cartBox => Hive.box<String>(HiveBoxes.cart);

  /// Save cart state
  Future<void> saveCart(LocalCart cart) async {
    await _cartBox.put(cart.storeId, jsonEncode(cart.toJson()));
  }

  /// Get cart for store
  Future<LocalCart?> getCart(String storeId) async {
    final json = _cartBox.get(storeId);
    if (json == null) return null;
    return LocalCart.fromJson(jsonDecode(json));
  }

  /// Clear cart
  Future<void> clearCart(String storeId) async {
    await _cartBox.delete(storeId);
  }

  // ==================== Sync Status Operations ====================

  Box<String> get _syncStatusBox => Hive.box<String>(HiveBoxes.syncStatus);

  /// Get or create sync status for store
  Future<SyncStatus> getSyncStatus(String storeId) async {
    final json = _syncStatusBox.get(storeId);
    if (json != null) {
      return SyncStatus.fromJson(jsonDecode(json));
    }

    final status = SyncStatus(storeId: storeId);
    await _syncStatusBox.put(storeId, jsonEncode(status.toJson()));
    return status;
  }

  /// Update sync status
  Future<void> updateSyncStatus(SyncStatus status) async {
    await _syncStatusBox.put(status.storeId, jsonEncode(status.toJson()));
  }

  // ==================== User Session Operations ====================

  Box<String> get _userSessionBox => Hive.box<String>(HiveBoxes.userSession);

  /// Save user session
  Future<void> saveUserSession(LocalUserSession session) async {
    await _userSessionBox.put(session.uid, jsonEncode(session.toJson()));
  }

  /// Get cached user session
  Future<LocalUserSession?> getUserSession(String uid) async {
    final json = _userSessionBox.get(uid);
    if (json == null) return null;
    return LocalUserSession.fromJson(jsonDecode(json));
  }

  /// Clear all user sessions
  Future<void> clearUserSessions() async {
    await _userSessionBox.clear();
  }

  // ==================== Utility Methods ====================

  /// Generate offline receipt number
  String generateOfflineReceiptNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'OFF-${now.year}-$timestamp';
  }
}
