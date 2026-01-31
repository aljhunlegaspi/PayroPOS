import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../services/offline_data_service.dart';
import 'store_provider.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';
import 'product_provider.dart';

// TransactionItem Model
class TransactionItem {
  final String productId;
  final String name;
  final double price;
  final double? cost;
  final int quantity;
  final double subtotal;

  const TransactionItem({
    required this.productId,
    required this.name,
    required this.price,
    this.cost,
    required this.quantity,
    required this.subtotal,
  });

  double get totalCost => (cost ?? 0) * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      productId: map['product_id'] ?? map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      cost: map['cost']?.toDouble(),
      quantity: map['quantity'] ?? 0,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }

  factory TransactionItem.fromCartItem(CartItem item) {
    return TransactionItem(
      productId: item.productId,
      name: item.name,
      price: item.price,
      cost: item.cost,
      quantity: item.quantity,
      subtotal: item.subtotal,
    );
  }
}

// Transaction Model
class SaleTransaction {
  final String id;
  final String storeId;
  final String locationId;
  final String receiptNumber;
  final String? customerId;
  final String? customerName;
  final String staffId;
  final String staffName;
  final List<TransactionItem> items;
  final double subtotal;
  final double taxRate;
  final double tax;
  final double total;
  final String paymentMethod;
  final double amountReceived;
  final double change;
  final DateTime createdAt;

  const SaleTransaction({
    required this.id,
    required this.storeId,
    required this.locationId,
    required this.receiptNumber,
    this.customerId,
    this.customerName,
    required this.staffId,
    required this.staffName,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.amountReceived,
    required this.change,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'location_id': locationId,
      'receipt_number': receiptNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'staff_id': staffId,
      'staff_name': staffName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'amount_received': amountReceived,
      'change': change,
    };
  }

  factory SaleTransaction.fromSupabase(Map<String, dynamic> data) {
    return SaleTransaction(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      locationId: data['location_id'] ?? '',
      receiptNumber: data['receipt_number'] ?? '',
      customerId: data['customer_id'],
      customerName: data['customer_name'],
      staffId: data['staff_id'] ?? '',
      staffName: data['staff_name'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      taxRate: (data['tax_rate'] ?? 0.12).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      paymentMethod: data['payment_method'] ?? 'cash',
      amountReceived: (data['amount_received'] ?? 0).toDouble(),
      change: (data['change'] ?? 0).toDouble(),
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
    );
  }

  // Generate receipt number
  static String generateReceiptNumber(int sequenceNumber) {
    final year = DateTime.now().year;
    return 'INV-$year-${sequenceNumber.toString().padLeft(4, '0')}';
  }
}

// Transaction State
class TransactionState {
  final List<SaleTransaction> transactions;
  final SaleTransaction? lastTransaction;
  final bool isLoading;
  final String? error;
  final double todaySales;
  final int todayTransactionCount;

  const TransactionState({
    this.transactions = const [],
    this.lastTransaction,
    this.isLoading = false,
    this.error,
    this.todaySales = 0,
    this.todayTransactionCount = 0,
  });

  TransactionState copyWith({
    List<SaleTransaction>? transactions,
    SaleTransaction? lastTransaction,
    bool? isLoading,
    String? error,
    double? todaySales,
    int? todayTransactionCount,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      todaySales: todaySales ?? this.todaySales,
      todayTransactionCount: todayTransactionCount ?? this.todayTransactionCount,
    );
  }
}

// Transaction Notifier
class TransactionNotifier extends StateNotifier<TransactionState> {
  final SupabaseClient _supabase;
  final Ref _ref;
  String? _currentStoreId;
  String? _currentLocationId;
  OfflineDataService? _offlineService;

  TransactionNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const TransactionState()) {
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
      if (next.store != null) {
        _currentStoreId = next.store!.id;
        _currentLocationId = next.currentLocation?.id;
        loadTodayTransactions();
      }
    }, fireImmediately: true);

    // Listen to connectivity changes
    _ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (previous?.isOffline == true && next.isOnline && _currentStoreId != null) {
        debugPrint('💳 Back online - refreshing transactions');
        loadTodayTransactions();
      }
    });
  }

  // Get next receipt number
  Future<String> _getNextReceiptNumber() async {
    if (_currentStoreId == null) {
      throw Exception('No store selected');
    }

    final year = DateTime.now().year;
    final yearStart = DateTime(year, 1, 1).toIso8601String();

    // Get total transaction count for the year for sequence
    final response = await _supabase
        .from('transactions')
        .select('id')
        .eq('store_id', _currentStoreId!)
        .gte('created_at', yearStart);

    final count = (response as List).length;
    final sequenceNumber = count + 1;
    return SaleTransaction.generateReceiptNumber(sequenceNumber);
  }

  // Complete a transaction (checkout) - supports offline mode
  Future<SaleTransaction> completeTransaction({
    required CartState cart,
    required double amountReceived,
    String paymentMethod = 'cash',
  }) async {
    if (_currentStoreId == null || _currentLocationId == null) {
      throw Exception('No store or location selected');
    }

    if (cart.isEmpty) {
      throw Exception('Cart is empty');
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      debugPrint('💳 Starting transaction (${_isOnline ? 'online' : 'offline'})...');

      // Get user info
      final userData = _ref.read(userDataProvider);
      final staffId = userData?['uid'] ?? '';
      final staffName = userData?['fullName'] ?? userData?['displayName'] ?? 'Staff';

      SaleTransaction transaction;

      if (_isOnline) {
        // Online: save directly to Supabase
        final receiptNumber = await _getNextReceiptNumber();
        debugPrint('💳 Receipt number: $receiptNumber');

        final transactionData = {
          'store_id': _currentStoreId,
          'location_id': _currentLocationId,
          'receipt_number': receiptNumber,
          'customer_id': cart.customerId,
          'customer_name': cart.customerName,
          'staff_id': staffId,
          'staff_name': staffName,
          'items': cart.items.map((item) => TransactionItem.fromCartItem(item).toMap()).toList(),
          'subtotal': cart.subtotal,
          'tax_rate': cart.taxRate,
          'tax': cart.tax,
          'total': cart.total,
          'payment_method': paymentMethod,
          'amount_received': amountReceived,
          'change': amountReceived - cart.total,
        };

        final response = await _supabase
            .from('transactions')
            .insert(transactionData)
            .select()
            .single();

        transaction = SaleTransaction.fromSupabase(response);
        debugPrint('💳 Transaction saved to Supabase: ${transaction.id}');

        // Decrease stock online
        await _decreaseStock(cart.items);
      } else {
        // Offline: save locally for later sync
        debugPrint('💳 Creating offline transaction...');

        final localTransaction = await _offline.createOfflineTransaction(
          storeId: _currentStoreId!,
          locationId: _currentLocationId!,
          cart: cart,
          amountReceived: amountReceived,
          staffId: staffId,
          staffName: staffName,
          paymentMethod: paymentMethod,
        );

        // Convert to SaleTransaction for UI
        transaction = _offline.localToTransaction(localTransaction);
        debugPrint('💳 Offline transaction created: ${transaction.receiptNumber}');
      }

      debugPrint('💳 Stock updated');

      // Clear cart (also clears persisted cart)
      _ref.read(cartProvider.notifier).clearCart();
      await _offline.clearPersistedCart(_currentStoreId!);
      debugPrint('💳 Cart cleared');

      // Update state
      state = state.copyWith(
        lastTransaction: transaction,
        isLoading: false,
        todaySales: state.todaySales + transaction.total,
        todayTransactionCount: state.todayTransactionCount + 1,
      );

      debugPrint('✅ Transaction completed: ${transaction.receiptNumber}');
      return transaction;
    } catch (e, stackTrace) {
      debugPrint('❌ Transaction failed: $e');
      debugPrint('   Stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // Decrease stock for sold items
  Future<void> _decreaseStock(List<CartItem> items) async {
    if (_currentStoreId == null || _currentLocationId == null) return;

    for (final item in items) {
      // Get current product to update stock
      final productData = await _supabase
          .from('products')
          .select('stock_by_location')
          .eq('id', item.productId)
          .single();

      final stockByLocation = Map<String, dynamic>.from(productData['stock_by_location'] ?? {});
      final currentStock = (stockByLocation[_currentLocationId] as num?)?.toInt() ?? 0;
      final newStock = currentStock - item.quantity;
      stockByLocation[_currentLocationId!] = newStock < 0 ? 0 : newStock;

      await _supabase
          .from('products')
          .update({'stock_by_location': stockByLocation})
          .eq('id', item.productId);
    }

    // Refresh products
    await _ref.read(productProvider.notifier).refreshProducts();
  }

  // Load today's transactions - supports offline mode
  Future<void> loadTodayTransactions() async {
    if (_currentStoreId == null) return;

    try {
      state = state.copyWith(isLoading: true);

      List<SaleTransaction> transactions;

      if (_isOnline) {
        // Online: load from Supabase
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

        final response = await _supabase
            .from('transactions')
            .select()
            .eq('store_id', _currentStoreId!)
            .gte('created_at', startOfDay)
            .order('created_at', ascending: false);

        transactions = (response as List)
            .map((data) => SaleTransaction.fromSupabase(data))
            .toList();
      } else {
        // Offline: load from local cache
        debugPrint('📊 Loading transactions from local cache (offline)');
        transactions = await _offline.getLocalTodayTransactions(_currentStoreId!);
      }

      final todaySales = transactions.fold<double>(0, (sum, t) => sum + t.total);

      debugPrint('📊 Loaded ${transactions.length} transactions for today (${_isOnline ? 'online' : 'offline'}), total: $todaySales');

      state = state.copyWith(
        transactions: transactions,
        isLoading: false,
        todaySales: todaySales,
        todayTransactionCount: transactions.length,
      );
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');

      // Fallback to local cache
      if (_isOnline) {
        try {
          final transactions = await _offline.getLocalTodayTransactions(_currentStoreId!);
          final todaySales = transactions.fold<double>(0, (sum, t) => sum + t.total);
          state = state.copyWith(
            transactions: transactions,
            isLoading: false,
            todaySales: todaySales,
            todayTransactionCount: transactions.length,
          );
          return;
        } catch (_) {}
      }

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Get transaction by ID
  Future<SaleTransaction?> getTransaction(String transactionId) async {
    if (_currentStoreId == null) return null;

    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .maybeSingle();

      if (response != null) {
        return SaleTransaction.fromSupabase(response);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting transaction: $e');
      return null;
    }
  }

  // Refresh transactions
  Future<void> refresh() async {
    await loadTodayTransactions();
  }
}

// Providers
final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  return TransactionNotifier(ref);
});

final lastTransactionProvider = Provider<SaleTransaction?>((ref) {
  return ref.watch(transactionProvider).lastTransaction;
});

final todaySalesProvider = Provider<double>((ref) {
  return ref.watch(transactionProvider).todaySales;
});

final todayTransactionCountProvider = Provider<int>((ref) {
  return ref.watch(transactionProvider).todayTransactionCount;
});

final recentTransactionsProvider = Provider<List<SaleTransaction>>((ref) {
  return ref.watch(transactionProvider).transactions;
});

// Alias for compatibility
typedef Transaction = SaleTransaction;
