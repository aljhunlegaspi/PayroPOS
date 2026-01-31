import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../services/offline_data_service.dart';
import 'store_provider.dart';
import 'product_provider.dart';

/// Stock History Entry - Records each restock event
class StockHistory {
  final String id;
  final String productId;
  final String productName;
  final String locationId;
  final String locationName;
  final int quantityAdded;
  final int previousStock;
  final int newStock;
  final String? notes;
  final String? userId;
  final String? userName;
  final DateTime createdAt;

  StockHistory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.locationId,
    required this.locationName,
    required this.quantityAdded,
    required this.previousStock,
    required this.newStock,
    this.notes,
    this.userId,
    this.userName,
    required this.createdAt,
  });

  factory StockHistory.fromSupabase(Map<String, dynamic> data) {
    return StockHistory(
      id: data['id'] ?? '',
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? '',
      locationId: data['location_id'] ?? '',
      locationName: data['location_name'] ?? '',
      quantityAdded: data['quantity_added'] ?? 0,
      previousStock: data['previous_stock'] ?? 0,
      newStock: data['new_stock'] ?? 0,
      notes: data['notes'],
      userId: data['user_id'],
      userName: data['user_name'],
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'product_id': productId,
      'product_name': productName,
      'location_id': locationId,
      'location_name': locationName,
      'quantity_added': quantityAdded,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'notes': notes,
      'user_id': userId,
      'user_name': userName,
    };
  }
}

/// Stock State
class StockState {
  final List<StockHistory> history;
  final bool isLoading;
  final String? error;

  const StockState({
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  StockState copyWith({
    List<StockHistory>? history,
    bool? isLoading,
    String? error,
  }) {
    return StockState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Stock Notifier - Handles restocking operations (supports offline)
class StockNotifier extends StateNotifier<StockState> {
  final SupabaseClient _supabase;
  final Ref _ref;
  String? _currentStoreId;
  OfflineDataService? _offlineService;

  StockNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const StockState()) {
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
    _ref.listen<StoreState>(storeProvider, (previous, next) {
      if (next.store != null && next.store!.id != _currentStoreId) {
        _currentStoreId = next.store!.id;
      }
    }, fireImmediately: true);
  }

  /// Load stock history for a specific product (supports offline)
  Future<void> loadProductHistory(String productId) async {
    if (_currentStoreId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      List<StockHistory> history;

      if (_isOnline) {
        // Online: load from Supabase
        final response = await _supabase
            .from('stock_history')
            .select()
            .eq('product_id', productId)
            .order('created_at', ascending: false)
            .limit(50);

        history = (response as List)
            .map((data) => StockHistory.fromSupabase(data))
            .toList();
      } else {
        // Offline: load from local cache
        history = await _offline.getLocalStockHistory(productId);
      }

      state = state.copyWith(history: history, isLoading: false);
      debugPrint('📦 Loaded ${history.length} stock history entries (${_isOnline ? 'online' : 'offline'})');
    } catch (e) {
      debugPrint('❌ Error loading stock history: $e');

      // Fallback to local cache
      if (_isOnline) {
        try {
          final history = await _offline.getLocalStockHistory(productId);
          state = state.copyWith(history: history, isLoading: false);
          return;
        } catch (_) {}
      }

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load all stock history (for overview)
  Future<void> loadAllHistory({int limit = 50}) async {
    if (_currentStoreId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await _supabase
          .from('stock_history')
          .select()
          .eq('store_id', _currentStoreId!)
          .order('created_at', ascending: false)
          .limit(limit);

      final history = (response as List)
          .map((data) => StockHistory.fromSupabase(data))
          .toList();

      state = state.copyWith(history: history, isLoading: false);
      debugPrint('📦 Loaded ${history.length} stock history entries (all)');
    } catch (e) {
      debugPrint('❌ Error loading all stock history: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load stock history for a specific location
  Future<void> loadLocationHistory(String locationId, {int limit = 50}) async {
    if (_currentStoreId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final response = await _supabase
          .from('stock_history')
          .select()
          .eq('location_id', locationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final history = (response as List)
          .map((data) => StockHistory.fromSupabase(data))
          .toList();

      state = state.copyWith(history: history, isLoading: false);
      debugPrint('📦 Loaded ${history.length} stock history entries for location');
    } catch (e) {
      debugPrint('❌ Error loading location stock history: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Restock a product at a specific location (supports offline)
  Future<void> restockProduct({
    required Product product,
    required String locationId,
    required String locationName,
    required int quantityToAdd,
    String? notes,
    String? userId,
    String? userName,
  }) async {
    if (_currentStoreId == null) throw Exception('No store selected');
    if (quantityToAdd <= 0) throw Exception('Quantity must be greater than 0');

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Get current stock for this location
      final previousStock = product.getStockForLocation(locationId);
      final newStock = previousStock + quantityToAdd;

      if (_isOnline) {
        // Online: save directly to Supabase

        // Save stock history
        await _supabase
            .from('stock_history')
            .insert({
              'store_id': _currentStoreId,
              'product_id': product.id,
              'product_name': product.name,
              'location_id': locationId,
              'location_name': locationName,
              'quantity_added': quantityToAdd,
              'previous_stock': previousStock,
              'new_stock': newStock,
              'notes': notes,
              'user_id': userId,
              'user_name': userName,
            });

        // Update product stock
        final updatedProduct = product.copyWithStockForLocation(locationId, newStock);

        await _supabase
            .from('products')
            .update({'stock_by_location': updatedProduct.stockByLocation})
            .eq('id', product.id);

        debugPrint('✅ Restocked ${product.name} (online): +$quantityToAdd at $locationName ($previousStock -> $newStock)');
      } else {
        // Offline: save locally for later sync
        await _offline.createOfflineStockHistory(
          product: product,
          locationId: locationId,
          locationName: locationName,
          quantityAdded: quantityToAdd,
          previousStock: previousStock,
          newStock: newStock,
          notes: notes,
          userId: userId,
          userName: userName,
        );
        debugPrint('✅ Restocked ${product.name} (offline): +$quantityToAdd at $locationName ($previousStock -> $newStock)');
      }

      // Refresh products to reflect new stock
      await _ref.read(productProvider.notifier).refreshProducts();

      // Reload history
      await loadProductHistory(product.id);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('❌ Error restocking product: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Clear history state
  void clearHistory() {
    state = const StockState();
  }
}

// Providers
final stockProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  return StockNotifier(ref);
});

final stockHistoryProvider = Provider<List<StockHistory>>((ref) {
  return ref.watch(stockProvider).history;
});

final isStockLoadingProvider = Provider<bool>((ref) {
  return ref.watch(stockProvider).isLoading;
});
