import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum representing network connection status
enum NetworkStatus {
  online,
  offline,
}

/// Service for monitoring network connectivity
class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity = Connectivity();

  StreamController<NetworkStatus>? _statusController;
  StreamSubscription<ConnectivityResult>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.online;

  ConnectivityService._();

  /// Get singleton instance
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  /// Current network status
  NetworkStatus get currentStatus => _currentStatus;

  /// Whether device is currently online
  bool get isOnline => _currentStatus == NetworkStatus.online;

  /// Whether device is currently offline
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  /// Stream of network status changes
  Stream<NetworkStatus> get statusStream {
    _statusController ??= StreamController<NetworkStatus>.broadcast();
    return _statusController!.stream;
  }

  /// Initialize the connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateStatusFromResult(result);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateStatusFromResult(result);
    });

    debugPrint('🌐 Connectivity: Initialized, status: $_currentStatus');
  }

  /// Update the current status based on single connectivity result
  void _updateStatusFromResult(ConnectivityResult result) {
    final previousStatus = _currentStatus;

    // Check if we have a valid connection
    final hasConnection = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;

    _currentStatus = hasConnection ? NetworkStatus.online : NetworkStatus.offline;

    if (previousStatus != _currentStatus) {
      debugPrint('🌐 Connectivity: Status changed to $_currentStatus');
      _statusController?.add(_currentStatus);
    }
  }

  /// Check current connectivity (one-time check)
  Future<NetworkStatus> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatusFromResult(result);
    return _currentStatus;
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
    _statusController?.close();
    _statusController = null;
    _subscription = null;
    debugPrint('🌐 Connectivity: Disposed');
  }
}

/// Connectivity state for Riverpod
class ConnectivityState {
  final NetworkStatus status;
  final DateTime? lastOnlineAt;
  final int pendingSyncCount;

  const ConnectivityState({
    this.status = NetworkStatus.online,
    this.lastOnlineAt,
    this.pendingSyncCount = 0,
  });

  bool get isOnline => status == NetworkStatus.online;
  bool get isOffline => status == NetworkStatus.offline;

  ConnectivityState copyWith({
    NetworkStatus? status,
    DateTime? lastOnlineAt,
    int? pendingSyncCount,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}

/// Connectivity notifier for Riverpod
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final ConnectivityService _service;
  StreamSubscription<NetworkStatus>? _subscription;

  ConnectivityNotifier(this._service) : super(const ConnectivityState()) {
    _init();
  }

  void _init() {
    // Set initial state
    state = ConnectivityState(
      status: _service.currentStatus,
      lastOnlineAt: _service.isOnline ? DateTime.now() : null,
    );

    // Listen for changes
    _subscription = _service.statusStream.listen((status) {
      final now = DateTime.now();
      state = state.copyWith(
        status: status,
        lastOnlineAt: status == NetworkStatus.online ? now : state.lastOnlineAt,
      );

      if (status == NetworkStatus.online) {
        debugPrint('🌐 Connectivity: Back online, triggering sync...');
        // Trigger sync when back online (will be handled by sync service)
      }
    });
  }

  /// Update pending sync count
  void updatePendingSyncCount(int count) {
    state = state.copyWith(pendingSyncCount: count);
  }

  /// Force check connectivity
  Future<void> checkConnectivity() async {
    final status = await _service.checkConnectivity();
    state = state.copyWith(
      status: status,
      lastOnlineAt: status == NetworkStatus.online ? DateTime.now() : state.lastOnlineAt,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Provider for connectivity state
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(service);
});

/// Simple provider for checking if online
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isOnline;
});

/// Simple provider for checking if offline
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isOffline;
});

/// Provider for pending sync count
final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(connectivityProvider).pendingSyncCount;
});
