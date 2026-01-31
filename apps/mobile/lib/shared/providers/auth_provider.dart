import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

// Auth State
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final Map<String, dynamic>? userData;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.userData,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Map<String, dynamic>? userData,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      userData: userData ?? this.userData,
      error: error,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthNotifier({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        super(const AuthState()) {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final userData = await _getUserData(user.uid);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          userData: userData,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      final data = doc.data();
      debugPrint('📋 User data from Firestore: $data');

      // If document doesn't exist or is missing key fields, create/update it
      if (data == null || data['fullName'] == null) {
        final user = _auth.currentUser;
        if (user != null) {
          final newData = {
            'uid': user.uid,
            'email': user.email,
            'fullName': user.displayName ?? user.email?.split('@').first ?? 'User',
            'role': data?['role'] ?? AppConstants.roleStoreOwner,
            'createdAt': data?['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            ...?data, // Keep existing data
          };

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .set(newData, SetOptions(merge: true));

          debugPrint('📝 Created/updated user document with: $newData');
          return newData;
        }
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      debugPrint('🔐 Attempting sign in for: $email');
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Sign in successful');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.code),
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

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ User created: ${credential.user?.uid}');

      if (credential.user != null) {
        // Create user document in Firestore
        debugPrint('📄 Creating Firestore document...');
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(credential.user!.uid)
            .set({
          'uid': credential.user!.uid,
          'email': email,
          'fullName': fullName,
          'role': AppConstants.roleStoreOwner,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Firestore document created');

        // Update display name
        await credential.user!.updateDisplayName(fullName);
        debugPrint('✅ Display name updated');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.code),
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
      await _auth.sendPasswordResetEmail(email: email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _getErrorMessage(e.code),
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
      await _auth.signOut();
    } catch (e) {
      state = state.copyWith(error: 'Failed to sign out');
    }
  }

  /// Refresh user data from Firestore (call after store setup or profile updates)
  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint('🔄 Refreshing user data for: ${user.uid}');
      final userData = await _getUserData(user.uid);
      debugPrint('📦 User data refreshed, storeId: ${userData?['storeId']}');
      state = state.copyWith(
        userData: userData,
      );
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed';
    }
  }
}

// Providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
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
