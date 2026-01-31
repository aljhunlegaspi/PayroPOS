import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';

// Store Model
class Store {
  final String id;
  final String name;
  final String businessType;
  final bool hasMultipleLocations;
  final String? logo;
  final String ownerId;
  final Map<String, dynamic> settings;
  final bool isActive;
  final DateTime? createdAt;

  Store({
    required this.id,
    required this.name,
    required this.businessType,
    required this.hasMultipleLocations,
    this.logo,
    required this.ownerId,
    required this.settings,
    required this.isActive,
    this.createdAt,
  });

  factory Store.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Store(
      id: doc.id,
      name: data['name'] ?? '',
      businessType: data['businessType'] ?? 'retail',
      hasMultipleLocations: data['hasMultipleLocations'] ?? false,
      logo: data['logo'],
      ownerId: data['ownerId'] ?? '',
      settings: data['settings'] ?? {},
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'businessType': businessType,
      'hasMultipleLocations': hasMultipleLocations,
      'logo': logo,
      'ownerId': ownerId,
      'settings': settings,
      'isActive': isActive,
    };
  }
}

// Location Model
class StoreLocation {
  final String id;
  final String storeId;
  final String name;
  final String address;
  final String phone;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;

  StoreLocation({
    required this.id,
    required this.storeId,
    required this.name,
    required this.address,
    required this.phone,
    required this.isDefault,
    required this.isActive,
    this.createdAt,
  });

  factory StoreLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreLocation(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      isDefault: data['isDefault'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'address': address,
      'phone': phone,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }
}

// Store State
class StoreState {
  final Store? store;
  final List<StoreLocation> locations;
  final StoreLocation? currentLocation;
  final bool isLoading;
  final String? error;

  const StoreState({
    this.store,
    this.locations = const [],
    this.currentLocation,
    this.isLoading = false,
    this.error,
  });

  StoreState copyWith({
    Store? store,
    List<StoreLocation>? locations,
    StoreLocation? currentLocation,
    bool? isLoading,
    String? error,
  }) {
    return StoreState(
      store: store ?? this.store,
      locations: locations ?? this.locations,
      currentLocation: currentLocation ?? this.currentLocation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Store Notifier
class StoreNotifier extends StateNotifier<StoreState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  StoreNotifier(this._ref, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const StoreState()) {
    _init();
  }

  void _init() {
    // Check current auth state immediately
    final currentAuth = _ref.read(authProvider);
    if (currentAuth.status == AuthStatus.authenticated && currentAuth.userData != null) {
      final storeId = currentAuth.userData!['storeId'] as String?;
      final locationId = currentAuth.userData!['defaultLocationId'] as String?;
      if (storeId != null) {
        debugPrint('📦 Loading store on init: $storeId');
        loadStore(storeId, locationId);
      }
    }

    // Listen to auth changes for future updates
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated && next.userData != null) {
        final storeId = next.userData!['storeId'] as String?;
        final locationId = next.userData!['defaultLocationId'] as String?;
        if (storeId != null && state.store?.id != storeId) {
          debugPrint('📦 Loading store on auth change: $storeId');
          loadStore(storeId, locationId);
        }
      } else if (next.status == AuthStatus.unauthenticated) {
        state = const StoreState();
      }
    });
  }

  Future<void> loadStore(String storeId, [String? defaultLocationId]) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Load store
      final storeDoc = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(storeId)
          .get();

      if (!storeDoc.exists) {
        state = state.copyWith(isLoading: false, error: 'Store not found');
        return;
      }

      final store = Store.fromFirestore(storeDoc);

      // Load locations
      final locationsSnapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(storeId)
          .collection('locations')
          .orderBy('createdAt')
          .get();

      final locations = locationsSnapshot.docs
          .map((doc) => StoreLocation.fromFirestore(doc))
          .toList();

      // Find current/default location
      StoreLocation? currentLocation;
      if (defaultLocationId != null) {
        currentLocation = locations.firstWhere(
          (l) => l.id == defaultLocationId,
          orElse: () => locations.isNotEmpty ? locations.first : locations.first,
        );
      } else if (locations.isNotEmpty) {
        currentLocation = locations.firstWhere(
          (l) => l.isDefault,
          orElse: () => locations.first,
        );
      }

      state = StoreState(
        store: store,
        locations: locations,
        currentLocation: currentLocation,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading store: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStore({
    required String name,
    required String businessType,
    String? logo,
  }) async {
    if (state.store == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(state.store!.id)
          .update({
        'name': name,
        'businessType': businessType,
        if (logo != null) 'logo': logo,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload store
      await loadStore(state.store!.id, state.currentLocation?.id);
    } catch (e) {
      debugPrint('❌ Error updating store: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStoreSettings(Map<String, dynamic> settings) async {
    if (state.store == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Merge new settings with existing settings
      final currentSettings = Map<String, dynamic>.from(state.store!.settings);
      currentSettings.addAll(settings);

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(state.store!.id)
          .update({
        'settings': currentSettings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload store
      await loadStore(state.store!.id, state.currentLocation?.id);
    } catch (e) {
      debugPrint('❌ Error updating store settings: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> enableMultipleLocations() async {
    if (state.store == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(state.store!.id)
          .update({
        'hasMultipleLocations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload store
      await loadStore(state.store!.id, state.currentLocation?.id);
    } catch (e) {
      debugPrint('❌ Error enabling multiple locations: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<StoreLocation> addLocation({
    required String name,
    required String address,
    required String phone,
    bool isDefault = false,
  }) async {
    if (state.store == null) throw Exception('No store loaded');

    try {
      state = state.copyWith(isLoading: true, error: null);

      final storeId = state.store!.id;
      final locationRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(storeId)
          .collection('locations')
          .doc();

      // If this is the first additional location, enable multiple locations
      if (!state.store!.hasMultipleLocations) {
        await _firestore
            .collection(AppConstants.storesCollection)
            .doc(storeId)
            .update({
          'hasMultipleLocations': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // If setting as default, unset other defaults
      if (isDefault && state.locations.isNotEmpty) {
        final batch = _firestore.batch();
        for (final loc in state.locations.where((l) => l.isDefault)) {
          batch.update(
            _firestore
                .collection(AppConstants.storesCollection)
                .doc(storeId)
                .collection('locations')
                .doc(loc.id),
            {'isDefault': false},
          );
        }
        await batch.commit();
      }

      await locationRef.set({
        'id': locationRef.id,
        'storeId': storeId,
        'name': name,
        'address': address,
        'phone': phone,
        'isDefault': isDefault,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload store
      await loadStore(storeId, state.currentLocation?.id);

      return state.locations.firstWhere((l) => l.id == locationRef.id);
    } catch (e) {
      debugPrint('❌ Error adding location: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateLocation({
    required String locationId,
    required String name,
    required String address,
    required String phone,
  }) async {
    if (state.store == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(state.store!.id)
          .collection('locations')
          .doc(locationId)
          .update({
        'name': name,
        'address': address,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload store
      await loadStore(state.store!.id, state.currentLocation?.id);
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> setDefaultLocation(String locationId) async {
    if (state.store == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final storeId = state.store!.id;

      // Unset all defaults and set new default
      final batch = _firestore.batch();
      for (final loc in state.locations) {
        batch.update(
          _firestore
              .collection(AppConstants.storesCollection)
              .doc(storeId)
              .collection('locations')
              .doc(loc.id),
          {'isDefault': loc.id == locationId},
        );
      }
      await batch.commit();

      // Update user's default location
      final user = _ref.read(currentUserProvider);
      if (user != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .update({'defaultLocationId': locationId});
      }

      // Reload store
      await loadStore(storeId, locationId);
    } catch (e) {
      debugPrint('❌ Error setting default location: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void switchLocation(String locationId) {
    final location = state.locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => state.locations.first,
    );
    state = state.copyWith(currentLocation: location);
  }
}

// Providers
final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  return StoreNotifier(ref);
});

final currentStoreProvider = Provider<Store?>((ref) {
  return ref.watch(storeProvider).store;
});

final storeLocationsProvider = Provider<List<StoreLocation>>((ref) {
  return ref.watch(storeProvider).locations;
});

final currentLocationProvider = Provider<StoreLocation?>((ref) {
  return ref.watch(storeProvider).currentLocation;
});

// POS Settings providers
final requireQuantityInputProvider = Provider<bool>((ref) {
  final store = ref.watch(currentStoreProvider);
  return store?.settings['requireQuantityInput'] ?? false;
});
