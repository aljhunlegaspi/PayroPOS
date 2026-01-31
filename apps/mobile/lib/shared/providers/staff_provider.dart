import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';
import 'store_provider.dart';

/// Staff member model
class StaffMember {
  final String id;
  final String storeId;
  final String uid; // Firebase user ID
  final String email;
  final String fullName;
  final String? phone;
  final List<String> assignedLocationIds; // Locations this staff can work at
  final bool isActive;
  final String? pin; // Optional PIN for quick login
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  StaffMember({
    required this.id,
    required this.storeId,
    required this.uid,
    required this.email,
    required this.fullName,
    this.phone,
    required this.assignedLocationIds,
    this.isActive = true,
    this.pin,
    this.createdAt,
    this.lastLoginAt,
  });

  factory StaffMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffMember(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'],
      assignedLocationIds: List<String>.from(data['assignedLocationIds'] ?? []),
      isActive: data['isActive'] ?? true,
      pin: data['pin'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'storeId': storeId,
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'assignedLocationIds': assignedLocationIds,
      'isActive': isActive,
      'pin': pin,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  StaffMember copyWith({
    String? id,
    String? storeId,
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    List<String>? assignedLocationIds,
    bool? isActive,
    String? pin,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return StaffMember(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      assignedLocationIds: assignedLocationIds ?? this.assignedLocationIds,
      isActive: isActive ?? this.isActive,
      pin: pin ?? this.pin,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

/// Staff invitation model (for pending invitations)
class StaffInvitation {
  final String id;
  final String storeId;
  final String storeName;
  final String email;
  final String invitedByUid;
  final String invitedByName;
  final List<String> assignedLocationIds;
  final String status; // pending, accepted, expired
  final DateTime createdAt;
  final DateTime? acceptedAt;

  StaffInvitation({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.email,
    required this.invitedByUid,
    required this.invitedByName,
    required this.assignedLocationIds,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  factory StaffInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffInvitation(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      storeName: data['storeName'] ?? '',
      email: data['email'] ?? '',
      invitedByUid: data['invitedByUid'] ?? '',
      invitedByName: data['invitedByName'] ?? '',
      assignedLocationIds: List<String>.from(data['assignedLocationIds'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'email': email,
      'invitedByUid': invitedByUid,
      'invitedByName': invitedByName,
      'assignedLocationIds': assignedLocationIds,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }
}

/// Staff state
class StaffState {
  final List<StaffMember> staffMembers;
  final List<StaffInvitation> pendingInvitations;
  final bool isLoading;
  final String? error;

  const StaffState({
    this.staffMembers = const [],
    this.pendingInvitations = const [],
    this.isLoading = false,
    this.error,
  });

  StaffState copyWith({
    List<StaffMember>? staffMembers,
    List<StaffInvitation>? pendingInvitations,
    bool? isLoading,
    String? error,
  }) {
    return StaffState(
      staffMembers: staffMembers ?? this.staffMembers,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Staff notifier for managing staff operations
class StaffNotifier extends StateNotifier<StaffState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  StaffNotifier(this._ref)
      : _firestore = FirebaseFirestore.instance,
        super(const StaffState());

  /// Load staff members for a store
  Future<void> loadStaff(String storeId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Load staff members
      final staffSnapshot = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(storeId)
          .collection(AppConstants.staffCollection)
          .orderBy('fullName')
          .get();

      final staff = staffSnapshot.docs
          .map((doc) => StaffMember.fromFirestore(doc))
          .toList();

      // Load pending invitations
      final invitationsSnapshot = await _firestore
          .collection('staffInvitations')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: 'pending')
          .get();

      final invitations = invitationsSnapshot.docs
          .map((doc) => StaffInvitation.fromFirestore(doc))
          .toList();

      state = state.copyWith(
        staffMembers: staff,
        pendingInvitations: invitations,
        isLoading: false,
      );

      debugPrint('✅ Loaded ${staff.length} staff members and ${invitations.length} pending invitations');
    } catch (e) {
      debugPrint('❌ Error loading staff: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Invite a new staff member
  Future<bool> inviteStaff({
    required String email,
    required List<String> assignedLocationIds,
  }) async {
    try {
      final store = _ref.read(currentStoreProvider);
      final userData = _ref.read(userDataProvider);

      if (store == null || userData == null) {
        state = state.copyWith(error: 'Store or user data not available');
        return false;
      }

      // Check if email is already a staff member or has a pending invitation
      final existingStaff = state.staffMembers.where((s) => s.email == email);
      if (existingStaff.isNotEmpty) {
        state = state.copyWith(error: 'This email is already a staff member');
        return false;
      }

      final existingInvitation = state.pendingInvitations.where((i) => i.email == email);
      if (existingInvitation.isNotEmpty) {
        state = state.copyWith(error: 'An invitation is already pending for this email');
        return false;
      }

      // Check if user exists in the system
      final userQuery = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        // User exists, add them directly as staff
        final existingUser = userQuery.docs.first;
        final existingUserData = existingUser.data();

        // Check if user already has a store
        if (existingUserData['storeId'] != null && existingUserData['storeId'] != store.id) {
          state = state.copyWith(error: 'This user is already associated with another store');
          return false;
        }

        // Create staff member
        final staffRef = _firestore
            .collection(AppConstants.storesCollection)
            .doc(store.id)
            .collection(AppConstants.staffCollection)
            .doc();

        final newStaff = StaffMember(
          id: staffRef.id,
          storeId: store.id,
          uid: existingUser.id,
          email: email,
          fullName: existingUserData['fullName'] ?? email.split('@').first,
          assignedLocationIds: assignedLocationIds,
        );

        await staffRef.set(newStaff.toFirestore());

        // Update user document with staff role and store reference
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(existingUser.id)
            .update({
          'role': AppConstants.roleStoreStaff,
          'storeId': store.id,
          'defaultLocationId': assignedLocationIds.isNotEmpty ? assignedLocationIds.first : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        state = state.copyWith(
          staffMembers: [...state.staffMembers, newStaff],
        );

        debugPrint('✅ Staff member added directly: ${newStaff.email}');
        return true;
      } else {
        // User doesn't exist, create an invitation
        final invitationRef = _firestore.collection('staffInvitations').doc();

        final invitation = StaffInvitation(
          id: invitationRef.id,
          storeId: store.id,
          storeName: store.name,
          email: email,
          invitedByUid: userData['uid'] ?? '',
          invitedByName: userData['fullName'] ?? '',
          assignedLocationIds: assignedLocationIds,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        await invitationRef.set(invitation.toFirestore());

        state = state.copyWith(
          pendingInvitations: [...state.pendingInvitations, invitation],
        );

        debugPrint('✅ Staff invitation created for: $email');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error inviting staff: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update staff member's assigned locations
  Future<bool> updateStaffLocations(String staffId, List<String> locationIds) async {
    try {
      final store = _ref.read(currentStoreProvider);
      if (store == null) return false;

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .update({
        'assignedLocationIds': locationIds,
      });

      // Update local state
      final updatedStaff = state.staffMembers.map((staff) {
        if (staff.id == staffId) {
          return staff.copyWith(assignedLocationIds: locationIds);
        }
        return staff;
      }).toList();

      state = state.copyWith(staffMembers: updatedStaff);

      debugPrint('✅ Updated staff locations for: $staffId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating staff locations: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Set staff PIN for quick login
  Future<bool> setStaffPin(String staffId, String pin) async {
    try {
      final store = _ref.read(currentStoreProvider);
      if (store == null) return false;

      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .update({
        'pin': pin,
      });

      // Update local state
      final updatedStaff = state.staffMembers.map((staff) {
        if (staff.id == staffId) {
          return staff.copyWith(pin: pin);
        }
        return staff;
      }).toList();

      state = state.copyWith(staffMembers: updatedStaff);

      debugPrint('✅ Updated staff PIN for: $staffId');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting staff PIN: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Deactivate a staff member
  Future<bool> deactivateStaff(String staffId) async {
    try {
      final store = _ref.read(currentStoreProvider);
      if (store == null) return false;

      // Get staff member to find their uid
      final staffDoc = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .get();

      if (!staffDoc.exists) return false;

      final staffData = staffDoc.data()!;
      final uid = staffData['uid'] as String?;

      // Deactivate staff member
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .update({'isActive': false});

      // Update user document to remove store association
      if (uid != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({
          'role': AppConstants.roleCustomer, // Reset to basic role
          'storeId': FieldValue.delete(),
          'defaultLocationId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update local state
      final updatedStaff = state.staffMembers.map((staff) {
        if (staff.id == staffId) {
          return staff.copyWith(isActive: false);
        }
        return staff;
      }).toList();

      state = state.copyWith(staffMembers: updatedStaff);

      debugPrint('✅ Deactivated staff: $staffId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deactivating staff: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reactivate a staff member
  Future<bool> reactivateStaff(String staffId) async {
    try {
      final store = _ref.read(currentStoreProvider);
      if (store == null) return false;

      // Get staff member
      final staffDoc = await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .get();

      if (!staffDoc.exists) return false;

      final staffData = staffDoc.data()!;
      final uid = staffData['uid'] as String?;
      final locationIds = List<String>.from(staffData['assignedLocationIds'] ?? []);

      // Reactivate staff member
      await _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc(staffId)
          .update({'isActive': true});

      // Update user document with store association
      if (uid != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({
          'role': AppConstants.roleStoreStaff,
          'storeId': store.id,
          'defaultLocationId': locationIds.isNotEmpty ? locationIds.first : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update local state
      final updatedStaff = state.staffMembers.map((staff) {
        if (staff.id == staffId) {
          return staff.copyWith(isActive: true);
        }
        return staff;
      }).toList();

      state = state.copyWith(staffMembers: updatedStaff);

      debugPrint('✅ Reactivated staff: $staffId');
      return true;
    } catch (e) {
      debugPrint('❌ Error reactivating staff: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Cancel a pending invitation
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      await _firestore
          .collection('staffInvitations')
          .doc(invitationId)
          .delete();

      // Update local state
      final updatedInvitations = state.pendingInvitations
          .where((inv) => inv.id != invitationId)
          .toList();

      state = state.copyWith(pendingInvitations: updatedInvitations);

      debugPrint('✅ Cancelled invitation: $invitationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling invitation: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Accept a staff invitation (called when a new user signs up with invited email)
  Future<bool> acceptInvitation(String email, String uid, String fullName) async {
    try {
      // Find pending invitation for this email
      final invitationQuery = await _firestore
          .collection('staffInvitations')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .get();

      if (invitationQuery.docs.isEmpty) {
        debugPrint('No pending invitation found for: $email');
        return false;
      }

      final invitation = StaffInvitation.fromFirestore(invitationQuery.docs.first);

      // Create staff member
      final staffRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(invitation.storeId)
          .collection(AppConstants.staffCollection)
          .doc();

      final newStaff = StaffMember(
        id: staffRef.id,
        storeId: invitation.storeId,
        uid: uid,
        email: email,
        fullName: fullName,
        assignedLocationIds: invitation.assignedLocationIds,
      );

      await staffRef.set(newStaff.toFirestore());

      // Update user document
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'role': AppConstants.roleStoreStaff,
        'storeId': invitation.storeId,
        'defaultLocationId': invitation.assignedLocationIds.isNotEmpty
            ? invitation.assignedLocationIds.first
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update invitation status
      await _firestore
          .collection('staffInvitations')
          .doc(invitation.id)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Staff invitation accepted for: $email');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      return false;
    }
  }

  /// Create a staff account directly with email/password
  /// This creates a Firebase Auth user and adds them as staff immediately
  Future<bool> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required List<String> assignedLocationIds,
  }) async {
    try {
      final store = _ref.read(currentStoreProvider);
      final userData = _ref.read(userDataProvider);

      if (store == null || userData == null) {
        state = state.copyWith(error: 'Store or user data not available');
        return false;
      }

      // Check if email is already a staff member
      final existingStaff = state.staffMembers.where((s) => s.email.toLowerCase() == email.toLowerCase());
      if (existingStaff.isNotEmpty) {
        state = state.copyWith(error: 'This email is already a staff member');
        return false;
      }

      // Check if email already exists in the system
      final existingUserQuery = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        state = state.copyWith(error: 'An account with this email already exists');
        return false;
      }

      // Create a secondary Firebase app to create the user account
      // This keeps the current owner logged in
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('staffCreation');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'staffCreation',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create the auth user
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final newUid = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(fullName);

      // Sign out from secondary auth immediately
      await secondaryAuth.signOut();

      // Create user document in Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(newUid)
          .set({
        'uid': newUid,
        'email': email.trim().toLowerCase(),
        'fullName': fullName,
        'role': AppConstants.roleStoreStaff,
        'storeId': store.id,
        'defaultLocationId': assignedLocationIds.isNotEmpty ? assignedLocationIds.first : null,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create staff member document
      final staffRef = _firestore
          .collection(AppConstants.storesCollection)
          .doc(store.id)
          .collection(AppConstants.staffCollection)
          .doc();

      final newStaff = StaffMember(
        id: staffRef.id,
        storeId: store.id,
        uid: newUid,
        email: email.trim().toLowerCase(),
        fullName: fullName,
        assignedLocationIds: assignedLocationIds,
      );

      await staffRef.set(newStaff.toFirestore());

      // Update local state
      state = state.copyWith(
        staffMembers: [...state.staffMembers, newStaff],
      );

      debugPrint('✅ Staff account created: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account with this email already exists';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak (minimum 6 characters)';
          break;
        default:
          errorMessage = e.message ?? 'Failed to create account';
      }
      debugPrint('❌ Firebase Auth error creating staff: ${e.code} - ${e.message}');
      state = state.copyWith(error: errorMessage);
      return false;
    } catch (e) {
      debugPrint('❌ Error creating staff account: $e');
      state = state.copyWith(error: 'Failed to create staff account: ${e.toString()}');
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers

final staffProvider = StateNotifierProvider<StaffNotifier, StaffState>((ref) {
  return StaffNotifier(ref);
});

/// Provider for active staff members only
final activeStaffProvider = Provider<List<StaffMember>>((ref) {
  return ref.watch(staffProvider).staffMembers.where((s) => s.isActive).toList();
});

/// Provider for inactive staff members
final inactiveStaffProvider = Provider<List<StaffMember>>((ref) {
  return ref.watch(staffProvider).staffMembers.where((s) => !s.isActive).toList();
});

/// Provider for pending invitations
final pendingInvitationsProvider = Provider<List<StaffInvitation>>((ref) {
  return ref.watch(staffProvider).pendingInvitations;
});

/// Provider to check if current user is a store owner
final isStoreOwnerProvider = Provider<bool>((ref) {
  final userData = ref.watch(userDataProvider);
  return userData?['role'] == AppConstants.roleStoreOwner;
});

/// Provider to check if current user is a staff member
final isStaffProvider = Provider<bool>((ref) {
  final userData = ref.watch(userDataProvider);
  return userData?['role'] == AppConstants.roleStoreStaff;
});

/// Provider for current user's role
final userRoleProvider = Provider<String>((ref) {
  final userData = ref.watch(userDataProvider);
  return userData?['role'] ?? AppConstants.roleCustomer;
});

/// Provider to get staff member's assigned locations
final staffAssignedLocationsProvider = Provider<List<String>>((ref) {
  final userData = ref.watch(userDataProvider);
  final staffState = ref.watch(staffProvider);

  if (userData == null) return [];

  final uid = userData['uid'] as String?;
  if (uid == null) return [];

  final staff = staffState.staffMembers.where((s) => s.uid == uid).firstOrNull;
  return staff?.assignedLocationIds ?? [];
});
