import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// View mode for product display
enum ProductViewMode { card, list }

/// User preferences state
class UserPreferencesState {
  final ProductViewMode posViewMode;
  final bool isLoaded;

  const UserPreferencesState({
    this.posViewMode = ProductViewMode.card,
    this.isLoaded = false,
  });

  UserPreferencesState copyWith({
    ProductViewMode? posViewMode,
    bool? isLoaded,
  }) {
    return UserPreferencesState(
      posViewMode: posViewMode ?? this.posViewMode,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

/// User preferences notifier
class UserPreferencesNotifier extends StateNotifier<UserPreferencesState> {
  UserPreferencesNotifier() : super(const UserPreferencesState()) {
    _loadPreferences();
  }

  static const String _posViewModeKey = 'pos_view_mode';

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final viewModeString = prefs.getString(_posViewModeKey);

    ProductViewMode viewMode = ProductViewMode.card;
    if (viewModeString == 'list') {
      viewMode = ProductViewMode.list;
    }

    state = state.copyWith(
      posViewMode: viewMode,
      isLoaded: true,
    );
  }

  Future<void> setPosViewMode(ProductViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_posViewModeKey, mode == ProductViewMode.list ? 'list' : 'card');
    state = state.copyWith(posViewMode: mode);
  }

  void togglePosViewMode() {
    final newMode = state.posViewMode == ProductViewMode.card
        ? ProductViewMode.list
        : ProductViewMode.card;
    setPosViewMode(newMode);
  }
}

/// Provider for user preferences
final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferencesState>((ref) {
  return UserPreferencesNotifier();
});

/// Convenience provider for POS view mode
final posViewModeProvider = Provider<ProductViewMode>((ref) {
  return ref.watch(userPreferencesProvider).posViewMode;
});
