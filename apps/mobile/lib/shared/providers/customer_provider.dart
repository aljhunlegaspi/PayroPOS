import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store_provider.dart';

/// Customer Model
class Customer {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double creditBalance; // Positive = customer owes, Negative = store owes
  final double creditLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.creditBalance = 0,
    this.creditLimit = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromSupabase(Map<String, dynamic> data) {
    return Customer(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      creditBalance: (data['credit_balance'] ?? 0).toDouble(),
      creditLimit: (data['credit_limit'] ?? 0).toDouble(),
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
      updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'credit_balance': creditBalance,
      'credit_limit': creditLimit,
    };
  }

  Customer copyWith({
    String? id,
    String? storeId,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? creditBalance,
    double? creditLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      creditBalance: creditBalance ?? this.creditBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether customer has outstanding balance
  bool get hasBalance => creditBalance != 0;

  /// Whether customer owes money
  bool get owesStore => creditBalance > 0;

  /// Whether store owes customer (overpayment/credit)
  bool get hasCredit => creditBalance < 0;

  /// Remaining credit before hitting limit
  double get availableCredit => creditLimit - creditBalance;

  /// Whether customer is over their credit limit
  bool get isOverLimit => creditBalance > creditLimit && creditLimit > 0;
}

/// Credit Transaction (tracks changes to customer balance)
class CreditTransaction {
  final String id;
  final String customerId;
  final String storeId;
  final String? transactionId; // Related sale transaction
  final double amount; // Positive = customer owes more, Negative = payment received
  final String type; // 'sale_credit', 'payment', 'adjustment'
  final String? notes;
  final String staffId;
  final String staffName;
  final DateTime createdAt;

  const CreditTransaction({
    required this.id,
    required this.customerId,
    required this.storeId,
    this.transactionId,
    required this.amount,
    required this.type,
    this.notes,
    required this.staffId,
    required this.staffName,
    required this.createdAt,
  });

  factory CreditTransaction.fromSupabase(Map<String, dynamic> data) {
    return CreditTransaction(
      id: data['id'] ?? '',
      customerId: data['customer_id'] ?? '',
      storeId: data['store_id'] ?? '',
      transactionId: data['transaction_id'],
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'adjustment',
      notes: data['notes'],
      staffId: data['staff_id'] ?? '',
      staffName: data['staff_name'] ?? '',
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'customer_id': customerId,
      'store_id': storeId,
      'transaction_id': transactionId,
      'amount': amount,
      'type': type,
      'notes': notes,
      'staff_id': staffId,
      'staff_name': staffName,
    };
  }
}

/// Customer State
class CustomerState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final Customer? selectedCustomer;
  final List<CreditTransaction> creditHistory;

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.selectedCustomer,
    this.creditHistory = const [],
  });

  CustomerState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    Customer? selectedCustomer,
    List<CreditTransaction>? creditHistory,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      creditHistory: creditHistory ?? this.creditHistory,
    );
  }

  /// Customers with outstanding balance
  List<Customer> get customersWithBalance =>
      customers.where((c) => c.hasBalance).toList();

  /// Total amount owed by all customers
  double get totalOwed =>
      customers.where((c) => c.owesStore).fold(0, (sum, c) => sum + c.creditBalance);
}

/// Customer Notifier
class CustomerNotifier extends StateNotifier<CustomerState> {
  final Ref _ref;
  final SupabaseClient _supabase;
  String? _currentStoreId;

  CustomerNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const CustomerState()) {
    _init();
  }

  void _init() {
    _ref.listen<StoreState>(storeProvider, (previous, next) {
      if (next.store != null && _currentStoreId != next.store!.id) {
        _currentStoreId = next.store!.id;
        loadCustomers();
      }
    }, fireImmediately: true);
  }

  Future<void> loadCustomers() async {
    if (_currentStoreId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _supabase
          .from('customers')
          .select()
          .eq('store_id', _currentStoreId!)
          .order('name');

      final customers = (response as List)
          .map((data) => Customer.fromSupabase(data))
          .toList();

      state = state.copyWith(
        customers: customers,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading customers: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<Customer?> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    double creditLimit = 0,
  }) async {
    if (_currentStoreId == null) return null;

    try {
      final response = await _supabase
          .from('customers')
          .insert({
            'store_id': _currentStoreId,
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'credit_limit': creditLimit,
            'credit_balance': 0,
          })
          .select()
          .single();

      final customer = Customer.fromSupabase(response);
      await loadCustomers();
      return customer;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    if (_currentStoreId == null) return false;

    try {
      await _supabase
          .from('customers')
          .update(customer.toSupabase())
          .eq('id', customer.id);

      await loadCustomers();
      return true;
    } catch (e) {
      debugPrint('Error updating customer: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    if (_currentStoreId == null) return false;

    try {
      await _supabase
          .from('customers')
          .delete()
          .eq('id', customerId);

      await loadCustomers();
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Add credit to customer (they owe money for a sale)
  Future<bool> addCredit({
    required String customerId,
    required double amount,
    String? transactionId,
    String? notes,
    required String staffId,
    required String staffName,
  }) async {
    if (_currentStoreId == null) return false;

    try {
      // Get current customer balance
      final customerData = await _supabase
          .from('customers')
          .select('credit_balance')
          .eq('id', customerId)
          .single();

      final currentBalance = (customerData['credit_balance'] ?? 0).toDouble();
      final newBalance = currentBalance + amount;

      // Update customer balance
      await _supabase
          .from('customers')
          .update({'credit_balance': newBalance})
          .eq('id', customerId);

      // Add credit transaction record
      await _supabase
          .from('credit_transactions')
          .insert({
            'customer_id': customerId,
            'store_id': _currentStoreId,
            'transaction_id': transactionId,
            'amount': amount,
            'type': 'sale_credit',
            'notes': notes,
            'staff_id': staffId,
            'staff_name': staffName,
          });

      await loadCustomers();
      return true;
    } catch (e) {
      debugPrint('Error adding credit: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Record payment from customer (reduces their balance)
  Future<bool> recordPayment({
    required String customerId,
    required double amount,
    String? notes,
    required String staffId,
    required String staffName,
  }) async {
    if (_currentStoreId == null) return false;

    try {
      // Get current customer balance
      final customerData = await _supabase
          .from('customers')
          .select('credit_balance')
          .eq('id', customerId)
          .single();

      final currentBalance = (customerData['credit_balance'] ?? 0).toDouble();
      final newBalance = currentBalance - amount;

      // Update customer balance (negative because they're paying)
      await _supabase
          .from('customers')
          .update({'credit_balance': newBalance})
          .eq('id', customerId);

      // Add credit transaction record
      await _supabase
          .from('credit_transactions')
          .insert({
            'customer_id': customerId,
            'store_id': _currentStoreId,
            'amount': -amount, // Negative = payment received
            'type': 'payment',
            'notes': notes,
            'staff_id': staffId,
            'staff_name': staffName,
          });

      await loadCustomers();
      return true;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Load credit history for a customer
  Future<void> loadCreditHistory(String customerId) async {
    if (_currentStoreId == null) return;

    try {
      final response = await _supabase
          .from('credit_transactions')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(50);

      final history = (response as List)
          .map((data) => CreditTransaction.fromSupabase(data))
          .toList();

      state = state.copyWith(creditHistory: history);
    } catch (e) {
      debugPrint('Error loading credit history: $e');
    }
  }

  /// Select a customer for checkout
  void selectCustomer(Customer? customer) {
    state = state.copyWith(selectedCustomer: customer);
    if (customer != null) {
      loadCreditHistory(customer.id);
    }
  }

  /// Clear selected customer
  void clearSelection() {
    state = state.copyWith(
      selectedCustomer: null,
      creditHistory: const [],
    );
  }

  /// Find customer by phone
  Customer? findByPhone(String phone) {
    try {
      return state.customers.firstWhere(
        (c) => c.phone?.replaceAll(RegExp(r'[^0-9]'), '') == phone.replaceAll(RegExp(r'[^0-9]'), ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// Search customers
  List<Customer> search(String query) {
    if (query.isEmpty) return state.customers;
    final q = query.toLowerCase();
    return state.customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.phone?.contains(q) ?? false) ||
        (c.email?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  Future<void> refresh() => loadCustomers();
}

// Providers
final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  return CustomerNotifier(ref);
});

final customersWithBalanceProvider = Provider<List<Customer>>((ref) {
  return ref.watch(customerProvider).customersWithBalance;
});

final totalOwedProvider = Provider<double>((ref) {
  return ref.watch(customerProvider).totalOwed;
});
