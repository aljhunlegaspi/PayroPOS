import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';
import 'store_provider.dart';

/// Staff member model
class StaffMember {
  final String id;
  final String storeId;
  final String uid; // Supabase user ID
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

  factory StaffMember.fromSupabase(Map<String, dynamic> data) {
    return StaffMember(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      phone: data['phone'],
      assignedLocationIds: List<String>.from(data['assigned_location_ids'] ?? []),
      isActive: data['is_active'] ?? true,
      pin: data['pin'],
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
      lastLoginAt: data['last_login_at'] != null ? DateTime.parse(data['last_login_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'uid': uid,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'assigned_location_ids': assignedLocationIds,
      'is_active': isActive,
      'pin': pin,
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

  factory StaffInvitation.fromSupabase(Map<String, dynamic> data) {
    return StaffInvitation(
      id: data['id'] ?? '',
      storeId: data['store_id'] ?? '',
      storeName: data['store_name'] ?? '',
      email: data['email'] ?? '',
      invitedByUid: data['invited_by_uid'] ?? '',
      invitedByName: data['invited_by_name'] ?? '',
      assignedLocationIds: List<String>.from(data['assigned_location_ids'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
      acceptedAt: data['accepted_at'] != null ? DateTime.parse(data['accepted_at']) : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'email': email,
      'invited_by_uid': invitedByUid,
      'invited_by_name': invitedByName,
      'assigned_location_ids': assignedLocationIds,
      'status': status,
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
  final SupabaseClient _supabase;
  final Ref _ref;

  StaffNotifier(this._ref, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        super(const StaffState());

  /// Load staff members for a store
  Future<void> loadStaff(String storeId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Load staff members
      final staffResponse = await _supabase
          .from('staff')
          .select()
          .eq('store_id', storeId)
          .order('full_name');

      final staff = (staffResponse as List)
          .map((data) => StaffMember.fromSupabase(data))
          .toList();

      // Load pending invitations
      final invitationsResponse = await _supabase
          .from('staff_invitations')
          .select()
          .eq('store_id', storeId)
          .eq('status', 'pending');

      final invitations = (invitationsResponse as List)
          .map((data) => StaffInvitation.fromSupabase(data))
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

      // Check if user exists in the system (profiles table)
      final userQuery = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (userQuery != null) {
        // User exists, add them directly as staff
        final existingUserData = userQuery;

        // Check if user already has a store
        if (existingUserData['store_id'] != null && existingUserData['store_id'] != store.id) {
          state = state.copyWith(error: 'This user is already associated with another store');
          return false;
        }

        // Create staff member
        final response = await _supabase
            .from('staff')
            .insert({
              'store_id': store.id,
              'uid': existingUserData['id'],
              'email': email,
              'full_name': existingUserData['full_name'] ?? email.split('@').first,
              'assigned_location_ids': assignedLocationIds,
              'is_active': true,
            })
            .select()
            .single();

        final newStaff = StaffMember.fromSupabase(response);

        // Update user profile with staff role and store reference
        await _supabase
            .from('profiles')
            .update({
              'role': AppConstants.roleStoreStaff,
              'store_id': store.id,
              'location_id': assignedLocationIds.isNotEmpty ? assignedLocationIds.first : null,
            })
            .eq('id', existingUserData['id']);

        state = state.copyWith(
          staffMembers: [...state.staffMembers, newStaff],
        );

        debugPrint('✅ Staff member added directly: ${newStaff.email}');
        return true;
      } else {
        // User doesn't exist, create an invitation
        final response = await _supabase
            .from('staff_invitations')
            .insert({
              'store_id': store.id,
              'store_name': store.name,
              'email': email,
              'invited_by_uid': userData['uid'] ?? '',
              'invited_by_name': userData['fullName'] ?? '',
              'assigned_location_ids': assignedLocationIds,
              'status': 'pending',
            })
            .select()
            .single();

        final invitation = StaffInvitation.fromSupabase(response);

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

      await _supabase
          .from('staff')
          .update({'assigned_location_ids': locationIds})
          .eq('id', staffId);

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

      await _supabase
          .from('staff')
          .update({'pin': pin})
          .eq('id', staffId);

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
      final staffData = await _supabase
          .from('staff')
          .select()
          .eq('id', staffId)
          .single();

      final uid = staffData['uid'] as String?;

      // Deactivate staff member
      await _supabase
          .from('staff')
          .update({'is_active': false})
          .eq('id', staffId);

      // Update user profile to remove store association
      if (uid != null) {
        await _supabase
            .from('profiles')
            .update({
              'role': AppConstants.roleCustomer,
              'store_id': null,
              'location_id': null,
            })
            .eq('id', uid);
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
      final staffData = await _supabase
          .from('staff')
          .select()
          .eq('id', staffId)
          .single();

      final uid = staffData['uid'] as String?;
      final locationIds = List<String>.from(staffData['assigned_location_ids'] ?? []);

      // Reactivate staff member
      await _supabase
          .from('staff')
          .update({'is_active': true})
          .eq('id', staffId);

      // Update user profile with store association
      if (uid != null) {
        await _supabase
            .from('profiles')
            .update({
              'role': AppConstants.roleStoreStaff,
              'store_id': store.id,
              'location_id': locationIds.isNotEmpty ? locationIds.first : null,
            })
            .eq('id', uid);
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
      await _supabase
          .from('staff_invitations')
          .delete()
          .eq('id', invitationId);

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
      final invitationQuery = await _supabase
          .from('staff_invitations')
          .select()
          .eq('email', email)
          .eq('status', 'pending')
          .maybeSingle();

      if (invitationQuery == null) {
        debugPrint('No pending invitation found for: $email');
        return false;
      }

      final invitation = StaffInvitation.fromSupabase(invitationQuery);

      // Create staff member
      final response = await _supabase
          .from('staff')
          .insert({
            'store_id': invitation.storeId,
            'uid': uid,
            'email': email,
            'full_name': fullName,
            'assigned_location_ids': invitation.assignedLocationIds,
            'is_active': true,
          })
          .select()
          .single();

      // Update user profile
      await _supabase
          .from('profiles')
          .update({
            'role': AppConstants.roleStoreStaff,
            'store_id': invitation.storeId,
            'location_id': invitation.assignedLocationIds.isNotEmpty
                ? invitation.assignedLocationIds.first
                : null,
          })
          .eq('id', uid);

      // Update invitation status
      await _supabase
          .from('staff_invitations')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invitation.id);

      debugPrint('✅ Staff invitation accepted for: $email');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      return false;
    }
  }

  /// Create a staff account directly with email/password
  /// With Supabase, we use the signUp method and then add as staff
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
      final existingUserQuery = await _supabase
          .from('profiles')
          .select()
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (existingUserQuery != null) {
        state = state.copyWith(error: 'An account with this email already exists');
        return false;
      }

      // Create the auth user using Supabase auth admin (requires service role key)
      // For client-side, we'll create an invitation instead and let the user sign up
      // This is a limitation without service role access

      // Create an invitation that includes the password hint
      final response = await _supabase
          .from('staff_invitations')
          .insert({
            'store_id': store.id,
            'store_name': store.name,
            'email': email.trim().toLowerCase(),
            'invited_by_uid': userData['uid'] ?? '',
            'invited_by_name': userData['fullName'] ?? '',
            'assigned_location_ids': assignedLocationIds,
            'status': 'pending',
            'temp_password': password, // Store temporarily for manual setup
          })
          .select()
          .single();

      final invitation = StaffInvitation.fromSupabase(response);

      state = state.copyWith(
        pendingInvitations: [...state.pendingInvitations, invitation],
      );

      debugPrint('✅ Staff invitation created (user needs to sign up): $email');
      state = state.copyWith(
        error: 'Invitation sent. Staff member needs to sign up with this email.',
      );
      return true;
    } on AuthException catch (e) {
      String errorMessage;
      if (e.message.contains('already')) {
        errorMessage = 'An account with this email already exists';
      } else if (e.message.contains('invalid')) {
        errorMessage = 'Invalid email address';
      } else if (e.message.contains('weak') || e.message.contains('password')) {
        errorMessage = 'Password is too weak (minimum 6 characters)';
      } else {
        errorMessage = e.message;
      }
      debugPrint('❌ Auth error creating staff: ${e.message}');
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
