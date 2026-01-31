import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/hive_service.dart';
import '../../core/database/hive_models.dart';
import 'connectivity_service.dart';

/// Types of sync operations
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Types of entities that can be synced
enum SyncEntityType {
  transaction,
  stockHistory,
  product,
  category,
}

/// Sync result for a single operation
class SyncResult {
  final bool success;
  final String? error;
  final String? firestoreId;

  SyncResult({
    required this.success,
    this.error,
    this.firestoreId,
  });
}

/// Overall sync status
class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final int completedCount;
  final int failedCount;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
    this.lastSyncAt,
    this.lastError,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pendingCount,
    int? completedCount,
    int? failedCount,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError,
    );
  }
}

/// Service for managing offline-to-online synchronization
class SyncService {
  static SyncService? _instance;
  final FirebaseFirestore _firestore;
  final HiveService _hive;

  Timer? _syncTimer;
  bool _isSyncing = false;
  final _stateController = StreamController<SyncState>.broadcast();

  SyncState _currentState = const SyncState();

  SyncService._({
    FirebaseFirestore? firestore,
    HiveService? isar,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _hive = isar ?? HiveService.instance;

  /// Get singleton instance
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  /// Stream of sync state changes
  Stream<SyncState> get stateStream => _stateController.stream;

  /// Current sync state
  SyncState get currentState => _currentState;

  /// Whether sync is in progress
  bool get isSyncing => _isSyncing;

  /// Initialize the sync service
  Future<void> initialize() async {
    // Count pending operations
    final pendingCount = await _hive.countPendingSyncOperations();
    _updateState(_currentState.copyWith(pendingCount: pendingCount));

    debugPrint('🔄 Sync: Initialized with $pendingCount pending operations');
  }

  /// Start periodic sync (call when online)
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      syncAll();
    });
    debugPrint('🔄 Sync: Started periodic sync every ${interval.inMinutes} minutes');
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('🔄 Sync: Stopped periodic sync');
  }

  /// Queue an operation for sync
  Future<void> queueOperation({
    required SyncOperationType operationType,
    required SyncEntityType entityType,
    required String entityId,
    String? firestoreId,
    required Map<String, dynamic> data,
  }) async {
    final operation = SyncOperation(
      id: '',
      operationType: operationType.name.toUpperCase(),
      entityType: entityType.name.toUpperCase(),
      entityId: entityId,
      firestoreId: firestoreId,
      data: data,
      retryCount: 0,
      createdAt: DateTime.now(),
      status: 'PENDING',
    );

    await _hive.addToSyncQueue(operation);

    final pendingCount = await _hive.countPendingSyncOperations();
    _updateState(_currentState.copyWith(pendingCount: pendingCount));

    debugPrint('🔄 Sync: Queued ${operationType.name} for ${entityType.name}');
  }

  /// Sync all pending operations
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('🔄 Sync: Already syncing, skipping...');
      return;
    }

    _isSyncing = true;
    _updateState(_currentState.copyWith(isSyncing: true));

    try {
      debugPrint('🔄 Sync: Starting sync...');

      // Sync transactions first (most important)
      await _syncTransactions();

      // Sync stock history
      await _syncStockHistory();

      // Process queued operations
      await _processQueuedOperations();

      // Update counts
      final pendingCount = await _hive.countPendingSyncOperations();
      _updateState(_currentState.copyWith(
        isSyncing: false,
        pendingCount: pendingCount,
        lastSyncAt: DateTime.now(),
        lastError: null,
      ));

      // Clean up completed operations
      await _hive.removeCompletedSyncOperations();

      debugPrint('🔄 Sync: Completed successfully');
    } catch (e) {
      debugPrint('❌ Sync: Error during sync: $e');
      _updateState(_currentState.copyWith(
        isSyncing: false,
        lastError: e.toString(),
      ));
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending transactions
  Future<void> _syncTransactions() async {
    final pendingTransactions = await _hive.getPendingSyncTransactions();

    for (final transaction in pendingTransactions) {
      try {
        final result = await _syncTransaction(transaction);
        if (result.success) {
          // Update transaction as synced using copyWith
          final updatedTransaction = transaction.copyWith(
            firestoreId: result.firestoreId ?? transaction.firestoreId,
            needsSync: false,
            syncedAt: DateTime.now(),
          );
          await _hive.saveTransaction(updatedTransaction);

          _updateState(_currentState.copyWith(
            completedCount: _currentState.completedCount + 1,
          ));
        }
      } catch (e) {
        debugPrint('❌ Sync: Failed to sync transaction ${transaction.id}: $e');
        _updateState(_currentState.copyWith(
          failedCount: _currentState.failedCount + 1,
        ));
      }
    }
  }

  /// Sync a single transaction to Firestore
  Future<SyncResult> _syncTransaction(LocalTransaction transaction) async {
    try {
      // Create document reference
      final docRef = _firestore
          .collection('stores')
          .doc(transaction.storeId)
          .collection('transactions')
          .doc();

      // Generate proper receipt number
      final receiptNumber = await _generateReceiptNumber(transaction.storeId);

      await docRef.set({
        'storeId': transaction.storeId,
        'locationId': transaction.locationId,
        'receiptNumber': receiptNumber,
        'customerId': transaction.customerId,
        'customerName': transaction.customerName,
        'staffId': transaction.staffId,
        'staffName': transaction.staffName,
        'items': transaction.items.map((e) => e.toJson()).toList(),
        'subtotal': transaction.subtotal,
        'taxRate': transaction.taxRate,
        'tax': transaction.tax,
        'total': transaction.total,
        'paymentMethod': transaction.paymentMethod,
        'amountReceived': transaction.amountReceived,
        'change': transaction.change,
        'createdAt': Timestamp.fromDate(transaction.createdAt),
        'offlineCreatedAt': Timestamp.fromDate(transaction.createdAt),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Sync: Transaction synced with receipt $receiptNumber');

      return SyncResult(success: true, firestoreId: docRef.id);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Generate receipt number for synced transaction
  Future<String> _generateReceiptNumber(String storeId) async {
    final year = DateTime.now().year;
    final yearStart = DateTime(year, 1, 1);

    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .count()
        .get();

    final sequenceNumber = (snapshot.count ?? 0) + 1;
    return 'INV-$year-${sequenceNumber.toString().padLeft(4, '0')}';
  }

  /// Sync pending stock history
  Future<void> _syncStockHistory() async {
    final pendingHistory = await _hive.getPendingSyncStockHistory();

    for (final history in pendingHistory) {
      try {
        final result = await _syncStockHistoryEntry(history);
        if (result.success) {
          // Update stock history as synced using copyWith
          final updatedHistory = history.copyWith(
            firestoreId: result.firestoreId ?? history.firestoreId,
            needsSync: false,
            syncedAt: DateTime.now(),
          );
          await _hive.saveStockHistory(updatedHistory);

          _updateState(_currentState.copyWith(
            completedCount: _currentState.completedCount + 1,
          ));
        }
      } catch (e) {
        debugPrint('❌ Sync: Failed to sync stock history ${history.id}: $e');
        _updateState(_currentState.copyWith(
          failedCount: _currentState.failedCount + 1,
        ));
      }
    }
  }

  /// Sync a single stock history entry
  Future<SyncResult> _syncStockHistoryEntry(LocalStockHistory history) async {
    try {
      // Find the store ID from the product
      final product = await _hive.getProductByFirestoreId(history.productId);

      if (product == null) {
        return SyncResult(success: false, error: 'Product not found');
      }

      final docRef = _firestore
          .collection('stores')
          .doc(product.storeId)
          .collection('stockHistory')
          .doc();

      await docRef.set({
        'productId': history.productId,
        'productName': history.productName,
        'locationId': history.locationId,
        'locationName': history.locationName,
        'quantityAdded': history.quantityAdded,
        'previousStock': history.previousStock,
        'newStock': history.newStock,
        'notes': history.notes,
        'userId': history.userId,
        'userName': history.userName,
        'createdAt': Timestamp.fromDate(history.createdAt),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      // Also update product stock in Firestore
      await _firestore
          .collection('stores')
          .doc(product.storeId)
          .collection('products')
          .doc(history.productId)
          .update({
        'stockByLocation.${history.locationId}': history.newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return SyncResult(success: true, firestoreId: docRef.id);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Process generic queued operations
  Future<void> _processQueuedOperations() async {
    final operations = await _hive.getPendingSyncOperations();

    for (final operation in operations) {
      try {
        await _hive.updateSyncOperationStatus(operation.id, 'IN_PROGRESS');

        // Process based on entity type
        bool success = false;
        switch (operation.entityType) {
          case 'PRODUCT':
            success = await _processProductOperation(operation, operation.data);
            break;
          case 'CATEGORY':
            success = await _processCategoryOperation(operation, operation.data);
            break;
          default:
            debugPrint('⚠️ Sync: Unknown entity type ${operation.entityType}');
        }

        await _hive.updateSyncOperationStatus(
          operation.id,
          success ? 'COMPLETED' : 'FAILED',
          error: success ? null : 'Operation failed',
        );
      } catch (e) {
        await _hive.updateSyncOperationStatus(
          operation.id,
          'FAILED',
          error: e.toString(),
        );
      }
    }
  }

  /// Process product sync operation
  Future<bool> _processProductOperation(SyncOperation operation, Map<String, dynamic> data) async {
    // Product sync is typically server -> client, not client -> server
    // This is for edge cases where product was created/modified offline
    return true;
  }

  /// Process category sync operation
  Future<bool> _processCategoryOperation(SyncOperation operation, Map<String, dynamic> data) async {
    // Category sync is typically server -> client
    return true;
  }

  /// Update internal state and notify listeners
  void _updateState(SyncState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _stateController.close();
    debugPrint('🔄 Sync: Disposed');
  }
}

/// Riverpod provider for sync service
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService.instance;
});

/// Sync state notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncService _service;
  final ConnectivityService _connectivity;
  StreamSubscription<SyncState>? _syncSubscription;
  StreamSubscription<NetworkStatus>? _connectivitySubscription;

  SyncNotifier(this._service, this._connectivity) : super(const SyncState()) {
    _init();
  }

  void _init() {
    // Listen to sync state changes
    _syncSubscription = _service.stateStream.listen((syncState) {
      state = syncState;
    });

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.statusStream.listen((status) {
      if (status == NetworkStatus.online) {
        // Auto sync when back online
        _service.syncAll();
        _service.startPeriodicSync();
      } else {
        _service.stopPeriodicSync();
      }
    });

    // Start sync if online
    if (_connectivity.isOnline) {
      _service.startPeriodicSync();
    }
  }

  /// Trigger manual sync
  Future<void> syncNow() async {
    if (_connectivity.isOnline) {
      await _service.syncAll();
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Provider for sync state
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return SyncNotifier(syncService, connectivityService);
});

/// Provider for pending sync count
final syncPendingCountProvider = Provider<int>((ref) {
  return ref.watch(syncProvider).pendingCount;
});

/// Provider for sync status
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncProvider).isSyncing;
});

/// Provider for last sync time
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncProvider).lastSyncAt;
});
