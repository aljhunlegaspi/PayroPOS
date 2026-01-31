import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
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

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      creditBalance: (data['creditBalance'] ?? 0).toDouble(),
      creditLimit: (data['creditLimit'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'creditBalance': creditBalance,
      'creditLimit': creditLimit,
      'updatedAt': FieldValue.serverTimestamp(),
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

  factory CreditTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditTransaction(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      storeId: data['storeId'] ?? '',
      transactionId: data['transactionId'],
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'adjustment',
      notes: data['notes'],
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'transactionId': transactionId,
      'amount': amount,
      'type': type,
      'notes': notes,
      'staffId': staffId,
      'staffName': staffName,
      'createdAt': FieldValue.serverTimestamp(),
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
  final FirebaseFirestore _firestore;
  String? _currentStoreId;

  CustomerNotifier(this._ref)
      : _firestore = FirebaseFirestore.instance,
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
      final snapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .orderBy('name')
          .get();

      final customers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
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
      final docRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .doc();

      final customer = Customer(
        id: docRef.id,
        storeId: _currentStoreId!,
        name: name,
        phone: phone,
        email: email,
        address: address,
        creditLimit: creditLimit,
        createdAt: DateTime.now(),
      );

      await docRef.set({
        ...customer.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

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
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .doc(customer.id)
          .update(customer.toMap());

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
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .doc(customerId)
          .delete();

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
      final batch = _firestore.batch();

      // Update customer balance
      final customerRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .doc(customerId);

      batch.update(customerRef, {
        'creditBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add credit transaction record
      final creditRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('credit_transactions')
          .doc();

      batch.set(creditRef, {
        'customerId': customerId,
        'storeId': _currentStoreId,
        'transactionId': transactionId,
        'amount': amount,
        'type': 'sale_credit',
        'notes': notes,
        'staffId': staffId,
        'staffName': staffName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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
      final batch = _firestore.batch();

      // Update customer balance (negative because they're paying)
      final customerRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('customers')
          .doc(customerId);

      batch.update(customerRef, {
        'creditBalance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add credit transaction record
      final creditRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('credit_transactions')
          .doc();

      batch.set(creditRef, {
        'customerId': customerId,
        'storeId': _currentStoreId,
        'amount': -amount, // Negative = payment received
        'type': 'payment',
        'notes': notes,
        'staffId': staffId,
        'staffName': staffName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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
      final snapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(_currentStoreId)
          .collection('credit_transactions')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final history = snapshot.docs
          .map((doc) => CreditTransaction.fromFirestore(doc))
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
