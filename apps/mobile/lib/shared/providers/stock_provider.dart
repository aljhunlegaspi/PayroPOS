import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
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

  factory StockHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockHistory(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      locationId: data['locationId'] ?? '',
      locationName: data['locationName'] ?? '',
      quantityAdded: data['quantityAdded'] ?? 0,
      previousStock: data['previousStock'] ?? 0,
      newStock: data['newStock'] ?? 0,
      notes: data['notes'],
      userId: data['userId'],
      userName: data['userName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'locationId': locationId,
      'locationName': locationName,
      'quantityAdded': quantityAdded,
      'previousStock': previousStock,
      'newStock': newStock,
      'notes': notes,
      'userId': userId,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
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
  final FirebaseFirestore _firestore;
  final Ref _ref;
  String? _currentStoreId;
  OfflineDataService? _offlineService;

  StockNotifier(this._ref, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
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
        // Online: load from Firestore
        final snapshot = await _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('stockHistory')
            .where('productId', isEqualTo: productId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        history = snapshot.docs
            .map((doc) => StockHistory.fromFirestore(doc))
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

      final snapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('stockHistory')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final history = snapshot.docs
          .map((doc) => StockHistory.fromFirestore(doc))
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

      final snapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('stockHistory')
          .where('locationId', isEqualTo: locationId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final history = snapshot.docs
          .map((doc) => StockHistory.fromFirestore(doc))
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
        // Online: save directly to Firestore
        final historyRef = _firestore
            .collection(AppConstants.storesCollection)
            .doc(_currentStoreId)
            .collection('stockHistory')
            .doc();

        final historyEntry = StockHistory(
          id: historyRef.id,
          productId: product.id,
          productName: product.name,
          locationId: locationId,
          locationName: locationName,
          quantityAdded: quantityToAdd,
          previousStock: previousStock,
          newStock: newStock,
          notes: notes,
          userId: userId,
          userName: userName,
          createdAt: DateTime.now(),
        );

        // Update product stock
        final updatedProduct = product.copyWithStockForLocation(locationId, newStock);

        // Use batch to update both atomically
        final batch = _firestore.batch();

        // Save stock history
        batch.set(historyRef, historyEntry.toMap());

        // Update product stock
        batch.update(
          _firestore
              .collection(AppConstants.storesCollection)
              .doc(_currentStoreId)
              .collection('products')
              .doc(product.id),
          {
            'stockByLocation': updatedProduct.stockByLocation,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();
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
