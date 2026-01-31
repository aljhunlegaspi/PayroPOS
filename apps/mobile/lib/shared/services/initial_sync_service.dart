import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/hive_service.dart';
import '../../core/database/hive_models.dart';

/// Service for initial data sync (first launch or login)
class InitialSyncService {
  final SupabaseClient _supabase;
  final HiveService _hive;

  InitialSyncService({
    SupabaseClient? supabase,
    HiveService? hive,
  })  : _supabase = supabase ?? Supabase.instance.client,
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
    final data = await _supabase
        .from('stores')
        .select()
        .eq('id', storeId)
        .single();

    final store = LocalStore(
      firestoreId: data['id'],
      name: data['name'] ?? '',
      businessType: data['business_type'] ?? 'retail',
      hasMultipleLocations: data['has_multiple_locations'] ?? false,
      logo: data['logo'],
      ownerId: data['owner_id'] ?? '',
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
      isActive: data['is_active'] ?? true,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
      lastSyncedAt: DateTime.now(),
    );

    await _hive.saveStore(store);
    debugPrint('   ✓ Store data synced');
  }

  /// Sync locations
  Future<void> _syncLocations(String storeId) async {
    final response = await _supabase
        .from('locations')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true);

    final locations = <LocalStoreLocation>[];
    for (final data in (response as List)) {
      locations.add(LocalStoreLocation(
        firestoreId: data['id'],
        storeId: storeId,
        name: data['name'] ?? '',
        address: data['address'] ?? '',
        phone: data['phone'] ?? '',
        isDefault: data['is_default'] ?? false,
        isActive: data['is_active'] ?? true,
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
        lastSyncedAt: DateTime.now(),
      ));
    }

    await _hive.saveLocations(locations);
    debugPrint('   ✓ ${locations.length} locations synced');
  }

  /// Sync products
  Future<void> _syncProducts(String storeId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('store_id', storeId);

    final products = <LocalProduct>[];
    for (final data in (response as List)) {
      // Handle stockByLocation map
      Map<String, int> stockByLocation = {};
      if (data['stock_by_location'] != null) {
        final rawMap = data['stock_by_location'] as Map<String, dynamic>;
        stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
      }

      final product = LocalProduct(
        firestoreId: data['id'],
        storeId: storeId,
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
    final response = await _supabase
        .from('categories')
        .select()
        .eq('store_id', storeId);

    final categories = <LocalCategory>[];
    for (final data in (response as List)) {
      categories.add(LocalCategory(
        firestoreId: data['id'],
        storeId: storeId,
        name: data['name'] ?? '',
        parentId: data['parent_id'],
        order: data['sort_order'] ?? 0,
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
        lastSyncedAt: DateTime.now(),
        needsSync: false,
      ));
    }

    await _hive.saveCategories(categories);
    debugPrint('   ✓ ${categories.length} categories synced');
  }

  /// Sync recent transactions (last 30 days)
  Future<void> _syncRecentTransactions(String storeId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final response = await _supabase
        .from('transactions')
        .select()
        .eq('store_id', storeId)
        .gte('created_at', thirtyDaysAgo)
        .order('created_at', ascending: false)
        .limit(500); // Limit to prevent too much data

    for (final data in (response as List)) {
      // Parse items
      final itemsList = (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItemData.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          [];

      final transaction = LocalTransaction(
        firestoreId: data['id'],
        storeId: storeId,
        locationId: data['location_id'] ?? '',
        receiptNumber: data['receipt_number'] ?? '',
        customerId: data['customer_id'],
        customerName: data['customer_name'],
        staffId: data['staff_id'] ?? '',
        staffName: data['staff_name'] ?? '',
        items: itemsList,
        subtotal: (data['subtotal'] ?? 0).toDouble(),
        taxRate: (data['tax_rate'] ?? 0.12).toDouble(),
        tax: (data['tax'] ?? 0).toDouble(),
        total: (data['total'] ?? 0).toDouble(),
        paymentMethod: data['payment_method'] ?? 'cash',
        amountReceived: (data['amount_received'] ?? 0).toDouble(),
        change: (data['change'] ?? 0).toDouble(),
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
        isOfflineTransaction: false,
        needsSync: false,
        syncedAt: DateTime.now(),
      );

      await _hive.saveTransaction(transaction);
    }

    debugPrint('   ✓ ${(response as List).length} transactions synced');
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
    final response = await _supabase
        .from('products')
        .select()
        .eq('store_id', storeId)
        .gt('updated_at', since.toIso8601String());

    for (final data in (response as List)) {
      Map<String, int> stockByLocation = {};
      if (data['stock_by_location'] != null) {
        final rawMap = data['stock_by_location'] as Map<String, dynamic>;
        stockByLocation = rawMap.map((key, value) => MapEntry(key, (value as num).toInt()));
      }

      final product = LocalProduct(
        firestoreId: data['id'],
        storeId: storeId,
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
        lastSyncedAt: DateTime.now(),
        needsSync: false,
      );

      await _hive.saveProduct(product);
    }

    if ((response as List).isNotEmpty) {
      debugPrint('   ✓ ${response.length} products updated');
    }
  }

  /// Sync categories updated since a given time
  Future<void> _syncCategoriesUpdatedSince(String storeId, DateTime since) async {
    // Categories don't have updatedAt typically, so we just re-sync all
    await _syncCategories(storeId);
  }
}
