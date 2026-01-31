import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_data_service.dart';
import 'product_provider.dart';
import 'store_provider.dart';

// CartItem Model
class CartItem {
  final String productId;
  final String name;
  final double price;
  final double? cost;
  final String? image;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.cost,
    this.image,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;
  double get totalCost => (cost ?? 0) * quantity;

  CartItem copyWith({
    String? productId,
    String? name,
    double? price,
    double? cost,
    String? image,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory CartItem.fromProduct(Product product) {
    return CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      cost: product.cost,
      image: product.image,
      quantity: 1,
    );
  }
}

// CartState Model
class CartState {
  final List<CartItem> items;
  final String? customerId;
  final String? customerName;
  final double taxRate;
  final bool isProcessing;
  final String? error;

  const CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.taxRate = 0.12,
    this.isProcessing = false,
    this.error,
  });

  // Computed properties
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? customerId,
    String? customerName,
    double? taxRate,
    bool? isProcessing,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      taxRate: taxRate ?? this.taxRate,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

// Cart Notifier - with offline persistence
class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;
  String? _currentStoreId;
  OfflineDataService? _offlineService;

  CartNotifier(this._ref) : super(const CartState()) {
    _init();
  }

  /// Get offline service
  OfflineDataService get _offline {
    _offlineService ??= _ref.read(offlineDataServiceProvider);
    return _offlineService!;
  }

  void _init() {
    // Load tax rate from store settings if available
    _updateTaxRateFromStore();

    // Listen for store changes to update tax rate and restore cart
    _ref.listen<Store?>(currentStoreProvider, (previous, next) {
      if (next != null) {
        _currentStoreId = next.id;

        if (next.settings['taxRate'] != null) {
          final taxRate = (next.settings['taxRate'] as num).toDouble();
          // Only update if tax rate is reasonable (should be decimal like 0.12, not 12)
          final normalizedRate = taxRate > 1 ? taxRate / 100 : taxRate;
          if (state.taxRate != normalizedRate) {
            state = state.copyWith(taxRate: normalizedRate);
            debugPrint('🛒 Cart: Tax rate updated to ${(normalizedRate * 100).toStringAsFixed(0)}%');
          }
        }

        // Restore persisted cart if empty
        if (state.isEmpty && previous?.id != next.id) {
          _restorePersistedCart();
        }
      }
    });
  }

  /// Restore cart from local storage
  Future<void> _restorePersistedCart() async {
    if (_currentStoreId == null) return;

    try {
      final restoredItems = await _offline.restoreCart(_currentStoreId!);
      if (restoredItems.isNotEmpty) {
        state = state.copyWith(items: restoredItems);
        debugPrint('🛒 Cart: Restored ${restoredItems.length} items from storage');
      }
    } catch (e) {
      debugPrint('🛒 Cart: Failed to restore persisted cart: $e');
    }
  }

  /// Persist cart to local storage
  Future<void> _persistCart() async {
    if (_currentStoreId == null) return;

    try {
      await _offline.persistCart(_currentStoreId!, state);
    } catch (e) {
      debugPrint('🛒 Cart: Failed to persist cart: $e');
    }
  }

  void _updateTaxRateFromStore() {
    final store = _ref.read(currentStoreProvider);
    if (store != null && store.settings['taxRate'] != null) {
      final taxRate = (store.settings['taxRate'] as num).toDouble();
      // Normalize: if > 1, assume it's a percentage (like 12) and convert to decimal (0.12)
      final normalizedRate = taxRate > 1 ? taxRate / 100 : taxRate;
      state = state.copyWith(taxRate: normalizedRate);
      debugPrint('🛒 Cart: Initial tax rate ${(normalizedRate * 100).toStringAsFixed(0)}%');
    }
  }

  // Add product to cart (with persistence)
  void addProduct(Product product, {int quantity = 1}) {
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id,
    );

    // Haptic feedback
    HapticFeedback.lightImpact();

    if (existingIndex >= 0) {
      // Increment quantity
      final updatedItems = List<CartItem>.from(state.items);
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
      state = state.copyWith(items: updatedItems);
      debugPrint('🛒 Cart: Increased ${product.name} to ${existing.quantity + quantity}');
    } else {
      // Add new item
      state = state.copyWith(
        items: [...state.items, CartItem.fromProduct(product).copyWith(quantity: quantity)],
      );
      debugPrint('🛒 Cart: Added ${product.name} x$quantity');
    }

    // Persist cart for offline recovery
    _persistCart();
  }

  // Add product by barcode scan
  Future<bool> addProductByBarcode(String barcode) async {
    final product = await _ref.read(productProvider.notifier).findByBarcode(barcode);
    if (product != null) {
      addProduct(product);
      return true;
    }
    debugPrint('🛒 Cart: Product not found for barcode $barcode');
    return false;
  }

  // Increase item quantity
  void increaseQuantity(String productId) {
    final index = state.items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final updatedItems = List<CartItem>.from(state.items);
      final item = updatedItems[index];
      updatedItems[index] = item.copyWith(quantity: item.quantity + 1);
      state = state.copyWith(items: updatedItems);
      _persistCart();
    }
  }

  // Decrease item quantity (removes if quantity becomes 0)
  void decreaseQuantity(String productId) {
    final index = state.items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = state.items[index];
      if (item.quantity > 1) {
        final updatedItems = List<CartItem>.from(state.items);
        updatedItems[index] = item.copyWith(quantity: item.quantity - 1);
        state = state.copyWith(items: updatedItems);
        _persistCart();
      } else {
        removeItem(productId);
      }
    }
  }

  // Remove item from cart
  void removeItem(String productId) {
    HapticFeedback.mediumImpact();
    final updatedItems = state.items.where((item) => item.productId != productId).toList();
    state = state.copyWith(items: updatedItems);
    debugPrint('🛒 Cart: Removed item $productId');
    _persistCart();
  }

  // Set specific quantity
  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = state.items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
      state = state.copyWith(items: updatedItems);
      _persistCart();
    }
  }

  // Clear entire cart
  void clearCart() {
    HapticFeedback.heavyImpact();
    state = state.copyWith(
      items: [],
      customerId: null,
      customerName: null,
    );
    debugPrint('🛒 Cart: Cleared');
    // Clear persisted cart
    if (_currentStoreId != null) {
      _offline.clearPersistedCart(_currentStoreId!);
    }
  }

  // Set customer (for future credit feature)
  void setCustomer(String? customerId, String? customerName) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
    );
  }

  // Set processing state
  void setProcessing(bool isProcessing) {
    state = state.copyWith(isProcessing: isProcessing);
  }

  // Set error
  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

// Providers
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});

// Convenience providers
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});

final cartTaxProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).tax;
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

final isCartEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).items;
});
