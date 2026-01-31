import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/hive_service.dart';
import '../../core/database/hive_models.dart';

/// Service for initial data sync (first launch or login)
class InitialSyncService {
  final FirebaseFirestore _firestore;
  final HiveService _hive;

  InitialSyncService({
    FirebaseFirestore? firestore,
    HiveService? hive,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _hive = hive ?? HiveService.instance;

  /// Perform initial sync for a store
  Future<void> syncStore(String storeId, {String? locationId}) async {
    debugPrint('🔄 Initial Sync: Starting for store $storeId');

    try {
      // Sync store data
      await _syncStoreData(storeId);

      // Sync locations
      await _syncLocations(storeId);

      // Sync products
      await _syncProducts(storeId);

      // Sync categories
      await _syncCategories(storeId);

      // Sync recent transactions
      await _syncRecentTransactions(storeId);

      // Update sync status
      final syncStatus = await _hive.getSyncStatus(storeId);
      final updated = syncStatus.copyWith(lastFullSync: DateTime.now());
      await _hive.updateSyncStatus(updated);

      debugPrint('✅ Initial Sync: Completed for store $storeId');
    } catch (e) {
      debugPrint('❌ Initial Sync: Failed for store $storeId: $e');
      rethrow;
    }
  }

  /// Sync store data
  Future<void> _syncStoreData(String storeId) async {
    final doc = await _firestore.collection('stores').doc(storeId).get();

    if (!doc.exists) {
      throw Exception('Store not found: $storeId');
    }

    final data = doc.data()!;
    final store = LocalStore(
      firestoreId: doc.id,
      name: data['name'] ?? '',
      businessType: data['businessType'] ?? 'retail',
      hasMultipleLocations: data['hasMultipleLocations'] ?? false,
      logo: data['logo'],
      ownerId: data['ownerId'] ?? '',
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSyncedAt: DateTime.now(),
    );

    await _hive.saveStore(store);
    debugPrint('   ✓ Store data synced');
  }

  /// Sync locations
  Future<void> _syncLocations(String storeId) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('locations')
        .where('isActive', isEqualTo: true)
        .get();

    final locations = <LocalStoreLocation>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      locations.add(LocalStoreLocation(
        firestoreId: doc.id,
        storeId: storeId,
        name: data['name'] ?? '',
        address: data['address'] ?? '',
        phone: data['phone'] ?? '',
        isDefault: data['isDefault'] ?? false,
        isActive: data['isActive'] ?? true,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        lastSyncedAt: DateTime.now(),
      ));
    }

    await _hive.saveLocations(locations);
    debugPrint('   ✓ ${locations.length} locations synced');
  }

  /// Sync products
  Future<void> _syncProducts(String storeId) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .get();

    final products = <LocalProduct>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Handle stockByLocation map
      Map<String, int> stockByLocation = {};
      if (data['stockByLocation'] != null) {
        final rawMap = data['stockByLocation'] as Map<String, dynamic>;
        stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
      }

      final product = LocalProduct(
        firestoreId: doc.id,
        storeId: storeId,
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
        lastSyncedAt: DateTime.now(),
        needsSync: false,
      );

      products.add(product);
    }

    await _hive.saveProducts(products);
    debugPrint('   ✓ ${products.length} products synced');
  }

  /// Sync categories
  Future<void> _syncCategories(String storeId) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .get();

    final categories = <LocalCategory>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      categories.add(LocalCategory(
        firestoreId: doc.id,
        storeId: storeId,
        name: data['name'] ?? '',
        parentId: data['parentId'],
        order: data['order'] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        lastSyncedAt: DateTime.now(),
        needsSync: false,
      ));
    }

    await _hive.saveCategories(categories);
    debugPrint('   ✓ ${categories.length} categories synced');
  }

  /// Sync recent transactions (last 30 days)
  Future<void> _syncRecentTransactions(String storeId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('createdAt', descending: true)
        .limit(500) // Limit to prevent too much data
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Parse items
      final itemsList = (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItemData.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          [];

      final transaction = LocalTransaction(
        firestoreId: doc.id,
        storeId: storeId,
        locationId: data['locationId'] ?? '',
        receiptNumber: data['receiptNumber'] ?? '',
        customerId: data['customerId'],
        customerName: data['customerName'],
        staffId: data['staffId'] ?? '',
        staffName: data['staffName'] ?? '',
        items: itemsList,
        subtotal: (data['subtotal'] ?? 0).toDouble(),
        taxRate: (data['taxRate'] ?? 0.12).toDouble(),
        tax: (data['tax'] ?? 0).toDouble(),
        total: (data['total'] ?? 0).toDouble(),
        paymentMethod: data['paymentMethod'] ?? 'cash',
        amountReceived: (data['amountReceived'] ?? 0).toDouble(),
        change: (data['change'] ?? 0).toDouble(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isOfflineTransaction: false,
        needsSync: false,
        syncedAt: DateTime.now(),
      );

      await _hive.saveTransaction(transaction);
    }

    debugPrint('   ✓ ${snapshot.docs.length} transactions synced');
  }

  /// Perform incremental sync (delta changes)
  Future<void> incrementalSync(String storeId, DateTime since) async {
    debugPrint('🔄 Incremental Sync: Since $since for store $storeId');

    try {
      // Sync products updated since last sync
      await _syncProductsUpdatedSince(storeId, since);

      // Sync categories updated since last sync
      await _syncCategoriesUpdatedSince(storeId, since);

      // Update sync status
      final syncStatus = await _hive.getSyncStatus(storeId);
      final updated = syncStatus.copyWith(lastIncrementalSync: DateTime.now());
      await _hive.updateSyncStatus(updated);

      debugPrint('✅ Incremental Sync: Completed');
    } catch (e) {
      debugPrint('❌ Incremental Sync: Failed: $e');
      rethrow;
    }
  }

  /// Sync products updated since a given time
  Future<void> _syncProductsUpdatedSince(String storeId, DateTime since) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      Map<String, int> stockByLocation = {};
      if (data['stockByLocation'] != null) {
        final rawMap = data['stockByLocation'] as Map<String, dynamic>;
        stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
      }

      final product = LocalProduct(
        firestoreId: doc.id,
        storeId: storeId,
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
        lastSyncedAt: DateTime.now(),
        needsSync: false,
      );

      await _hive.saveProduct(product);
    }

    if (snapshot.docs.isNotEmpty) {
      debugPrint('   ✓ ${snapshot.docs.length} products updated');
    }
  }

  /// Sync categories updated since a given time
  Future<void> _syncCategoriesUpdatedSince(String storeId, DateTime since) async {
    // Categories don't have updatedAt typically, so we just re-sync all
    await _syncCategories(storeId);
  }
}
