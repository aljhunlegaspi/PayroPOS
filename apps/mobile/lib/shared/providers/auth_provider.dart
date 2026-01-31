import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

// Auth State
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final Map<String, dynamic>? userData;
  final String? error;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.userData,
    this.error,
  });

  AppAuthState copyWith({
    AuthStatus? status,
    User? user,
    Map<String, dynamic>? userData,
    String? error,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      userData: userData ?? this.userData,
      error: error,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AppAuthState> {
  final SupabaseClient _supabase;

  AuthNotifier({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const AppAuthState()) {
    _init();
  }

  void _init() {
    // Check current session on startup
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _handleAuthChange(session.user);
    } else {
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    }

    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final user = data.session?.user;

      debugPrint('🔐 Auth state changed: $event');

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        if (user != null) {
          _handleAuthChange(user);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AppAuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _handleAuthChange(User user) async {
    final userData = await _getUserData(user.id);
    state = AppAuthState(
      status: AuthStatus.authenticated,
      user: user,
      userData: userData,
    );
  }

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      debugPrint('📋 User data from Supabase: $response');

      if (response == null) {
        // Profile should be auto-created by trigger, but create if missing
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final newData = {
            'id': user.id,
            'email': user.email,
            'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
            'role': AppConstants.roleStoreOwner,
          };

          await _supabase.from('profiles').upsert(newData);
          debugPrint('📝 Created profile: $newData');

          // Convert to app format
          return {
            'uid': user.id,
            'email': user.email,
            'fullName': newData['full_name'],
            'role': newData['role'],
          };
        }
        return null;
      }

      // Convert Supabase snake_case to app camelCase format
      final data = response;
      return {
        'uid': data['id'],
        'email': data['email'],
        'fullName': data['full_name'],
        'phone': data['phone'],
        'role': data['role'] ?? AppConstants.roleStoreOwner,
        'storeId': data['store_id'],
        'locationId': data['location_id'],
      };
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      debugPrint('🔐 Attempting sign in for: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Sign in successful');
        // Auth state listener will handle the rest
      }
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.message),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Sign in error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      debugPrint('📝 Starting signup for: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      debugPrint('✅ User created: ${response.user?.id}');

      if (response.user != null) {
        // Profile is auto-created by database trigger
        // Wait a moment for the trigger to complete, then update with full_name
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          await _supabase
              .from('profiles')
              .update({
                'full_name': fullName,
                'role': AppConstants.roleStoreOwner,
              })
              .eq('id', response.user!.id);
          debugPrint('✅ Profile updated');
        } catch (e) {
          // Profile update failed, but user is created - that's OK
          debugPrint('⚠️ Profile update skipped: $e');
        }
      }
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.message),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Signup error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      await _supabase.auth.resetPasswordForEmail(email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'An unexpected error occurred',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      state = state.copyWith(error: 'Failed to sign out');
    }
  }

  /// Refresh user data from Supabase (call after store setup or profile updates)
  Future<void> refreshUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      debugPrint('🔄 Refreshing user data for: ${user.id}');
      final userData = await _getUserData(user.id);
      debugPrint('📦 User data refreshed, storeId: ${userData?['storeId']}');
      state = state.copyWith(userData: userData);
    }
  }

  String _getErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('user not found') || lowerMessage.contains('invalid login')) {
      return 'Invalid email or password';
    } else if (lowerMessage.contains('email already')) {
      return 'Email is already registered';
    } else if (lowerMessage.contains('invalid email')) {
      return 'Invalid email address';
    } else if (lowerMessage.contains('weak password') || lowerMessage.contains('password')) {
      return 'Password must be at least 6 characters';
    } else if (lowerMessage.contains('too many requests')) {
      return 'Too many attempts. Please try again later';
    }
    return message;
  }
}

// Providers
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final userDataProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(authProvider).userData;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
