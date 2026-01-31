import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  factory Store.fromSupabase(Map<String, dynamic> data) {
    return Store(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      businessType: data['business_type'] ?? 'retail',
      hasMultipleLocations: data['has_multiple_locations'] ?? false,
      logo: data['logo'],
      ownerId: data['owner_id'] ?? '',
      settings: data['settings'] ?? {},
      isActive: data['is_active'] ?? true,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'name': name,
      'business_type': businessType,
      'has_multiple_locations': hasMultipleLocations,
      'logo': logo,
      'owner_id': ownerId,
      'settings': settings,
      'is_active': isActive,
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

  factory StoreLocation.fromSupabase(Map<String, dynamic> data) {
    return StoreLocation(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      isDefault: data['is_default'] ?? false,
      isActive: data['is_active'] ?? true,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'name': name,
      'address': address,
      'phone': phone,
      'is_default': isDefault,
      'is_active': isActive,
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
  final SupabaseClient _supabase;
  final Ref _ref;

  StoreNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const StoreState()) {
    _init();
  }

  void _init() {
    // Check current auth state immediately
    final currentAuth = _ref.read(authProvider);
    if (currentAuth.status == AuthStatus.authenticated && currentAuth.userData != null) {
      final storeId = currentAuth.userData!['storeId'] as String?;
      final locationId = currentAuth.userData!['locationId'] as String?;
      if (storeId != null) {
        debugPrint('📦 Loading store on init: $storeId');
        loadStore(storeId, locationId);
      }
    }

    // Listen to auth changes for future updates
    _ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated && next.userData != null) {
        final storeId = next.userData!['storeId'] as String?;
        final locationId = next.userData!['locationId'] as String?;
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
      final storeData = await _supabase
          .from('stores')
          .select()
          .eq('id', storeId)
          .maybeSingle();

      if (storeData == null) {
        state = state.copyWith(isLoading: false, error: 'Store not found');
        return;
      }

      final store = Store.fromSupabase(storeData);

      // Load locations
      final locationsData = await _supabase
          .from('locations')
          .select()
          .eq('store_id', storeId)
          .order('created_at');

      final locations = (locationsData as List)
          .map((data) => StoreLocation.fromSupabase(data))
          .toList();

      // Find current/default location
      StoreLocation? currentLocation;
      if (defaultLocationId != null && locations.isNotEmpty) {
        currentLocation = locations.firstWhere(
          (l) => l.id == defaultLocationId,
          orElse: () => locations.first,
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

      await _supabase
          .from('stores')
          .update({
            'name': name,
            'business_type': businessType,
            if (logo != null) 'logo': logo,
          })
          .eq('id', state.store!.id);

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

      await _supabase
          .from('stores')
          .update({'settings': currentSettings})
          .eq('id', state.store!.id);

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

      await _supabase
          .from('stores')
          .update({'has_multiple_locations': true})
          .eq('id', state.store!.id);

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

      // If this is the first additional location, enable multiple locations
      if (!state.store!.hasMultipleLocations) {
        await _supabase
            .from('stores')
            .update({'has_multiple_locations': true})
            .eq('id', storeId);
      }

      // If setting as default, unset other defaults
      if (isDefault && state.locations.isNotEmpty) {
        await _supabase
            .from('locations')
            .update({'is_default': false})
            .eq('store_id', storeId);
      }

      // Insert new location
      final response = await _supabase
          .from('locations')
          .insert({
            'store_id': storeId,
            'name': name,
            'address': address,
            'phone': phone,
            'is_default': isDefault,
            'is_active': true,
          })
          .select()
          .single();

      // Reload store
      await loadStore(storeId, state.currentLocation?.id);

      return StoreLocation.fromSupabase(response);
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

      await _supabase
          .from('locations')
          .update({
            'name': name,
            'address': address,
            'phone': phone,
          })
          .eq('id', locationId);

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

      // Unset all defaults
      await _supabase
          .from('locations')
          .update({'is_default': false})
          .eq('store_id', storeId);

      // Set new default
      await _supabase
          .from('locations')
          .update({'is_default': true})
          .eq('id', locationId);

      // Update user's default location
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({'location_id': locationId})
            .eq('id', user.id);
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
