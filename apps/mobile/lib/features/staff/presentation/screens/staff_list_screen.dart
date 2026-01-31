import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/staff_provider.dart';
import '../../../../shared/providers/store_provider.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load staff after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaff();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    final store = ref.read(currentStoreProvider);
    if (store != null) {
      await ref.read(staffProvider.notifier).loadStaff(store.id);
    } else {
      // If store is not loaded yet, listen for it
      final storeState = ref.read(storeProvider);
      if (storeState.isLoading) {
        // Wait for store to load and try again
        await Future.delayed(const Duration(milliseconds: 500));
        _loadStaff();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffState = ref.watch(staffProvider);
    final activeStaff = ref.watch(activeStaffProvider);
    final inactiveStaff = ref.watch(inactiveStaffProvider);
    final pendingInvitations = ref.watch(pendingInvitationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Decorative shapes
                  Positioned(
                    top: -20,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 50,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryMuted.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Staff Management',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${activeStaff.length} active members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(text: 'Active (${activeStaff.length})'),
                    Tab(text: 'Inactive (${inactiveStaff.length})'),
                    Tab(text: 'Pending (${pendingInvitations.length})'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: staffState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveStaffList(activeStaff),
                  _buildInactiveStaffList(inactiveStaff),
                  _buildPendingInvitationsList(pendingInvitations),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/staff/add'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildActiveStaffList(List<StaffMember> staff) {
    if (staff.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Active Staff',
        subtitle: 'Add staff members to help manage your store',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: staff.length,
        itemBuilder: (context, index) => _buildStaffCard(staff[index]),
      ),
    );
  }

  Widget _buildInactiveStaffList(List<StaffMember> staff) {
    if (staff.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_outlined,
        title: 'No Inactive Staff',
        subtitle: 'Deactivated staff members will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: staff.length,
        itemBuilder: (context, index) => _buildStaffCard(staff[index], isInactive: true),
      ),
    );
  }

  Widget _buildPendingInvitationsList(List<StaffInvitation> invitations) {
    if (invitations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mail_outline,
        title: 'No Pending Invitations',
        subtitle: 'Staff invitations waiting to be accepted will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: invitations.length,
        itemBuilder: (context, index) => _buildInvitationCard(invitations[index]),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffMember staff, {bool isInactive = false}) {
    final locations = ref.watch(storeLocationsProvider);
    final assignedLocationNames = staff.assignedLocationIds
        .map((id) => locations.firstWhere(
              (loc) => loc.id == id,
              orElse: () => StoreLocation(
                id: id,
                storeId: '',
                name: 'Unknown',
                address: '',
                phone: '',
                isDefault: false,
                isActive: true,
              ),
            ).name)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStaffDetails(staff),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isInactive
                        ? AppColors.textMuted.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isInactive ? AppColors.textMuted : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              staff.fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isInactive ? AppColors.textMuted : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isInactive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staff.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (assignedLocationNames.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: assignedLocationNames
                              .map((name) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceTint,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.more_horiz, color: AppColors.textSecondary, size: 18),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) => _handleStaffAction(value, staff),
                  itemBuilder: (context) => [
                    _buildPopupMenuItem('edit_locations', Icons.location_on_outlined, 'Edit Locations'),
                    _buildPopupMenuItem('set_pin', Icons.pin_outlined, 'Set PIN'),
                    const PopupMenuDivider(),
                    if (isInactive)
                      _buildPopupMenuItem('reactivate', Icons.person_add, 'Reactivate', color: AppColors.success)
                    else
                      _buildPopupMenuItem('deactivate', Icons.person_off, 'Deactivate', color: AppColors.error),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(StaffInvitation invitation) {
    final locations = ref.watch(storeLocationsProvider);
    final assignedLocationNames = invitation.assignedLocationIds
        .map((id) => locations.firstWhere(
              (loc) => loc.id == id,
              orElse: () => StoreLocation(
                id: id,
                storeId: '',
                name: 'Unknown',
                address: '',
                phone: '',
                isDefault: false,
                isActive: true,
              ),
            ).name)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.mail_outline, color: AppColors.warning, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invitation.email,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invited by ${invitation.invitedByName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (assignedLocationNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: assignedLocationNames
                          .map((name) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceTint,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _cancelInvitation(invitation),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, color: AppColors.error, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDetails(StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StaffDetailsSheet(staff: staff),
    );
  }

  void _handleStaffAction(String action, StaffMember staff) {
    switch (action) {
      case 'edit_locations':
        _showEditLocationsDialog(staff);
        break;
      case 'set_pin':
        _showSetPinDialog(staff);
        break;
      case 'deactivate':
        _showDeactivateConfirmation(staff);
        break;
      case 'reactivate':
        _reactivateStaff(staff);
        break;
    }
  }

  void _showEditLocationsDialog(StaffMember staff) {
    final locations = ref.read(storeLocationsProvider);
    final selectedIds = List<String>.from(staff.assignedLocationIds);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Assigned Locations'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select locations where ${staff.fullName} can work:',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ...locations.map((location) => CheckboxListTile(
                      title: Text(location.name),
                      subtitle: location.isDefault ? const Text('Default location', style: TextStyle(fontSize: 12)) : null,
                      value: selectedIds.contains(location.id),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedIds.add(location.id);
                          } else {
                            selectedIds.remove(location.id);
                          }
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final success = await ref.read(staffProvider.notifier).updateStaffLocations(staff.id, selectedIds);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Locations updated' : 'Failed to update locations'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetPinDialog(StaffMember staff) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set Staff PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a 4-digit PIN for ${staff.fullName}:',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: '****',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                hintText: '****',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits')),
                );
                return;
              }
              if (pinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              Navigator.pop(context);
              final success = await ref.read(staffProvider.notifier).setStaffPin(staff.id, pinController.text);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'PIN set successfully' : 'Failed to set PIN'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateConfirmation(StaffMember staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Deactivate Staff'),
        content: Text(
          'Are you sure you want to deactivate ${staff.fullName}? They will no longer be able to access the store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(staffProvider.notifier).deactivateStaff(staff.id);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '${staff.fullName} has been deactivated' : 'Failed to deactivate staff'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _reactivateStaff(StaffMember staff) async {
    final success = await ref.read(staffProvider.notifier).reactivateStaff(staff.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '${staff.fullName} has been reactivated' : 'Failed to reactivate staff'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _cancelInvitation(StaffInvitation invitation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Invitation'),
        content: Text('Are you sure you want to cancel the invitation for ${invitation.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(staffProvider.notifier).cancelInvitation(invitation.id);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Invitation cancelled' : 'Failed to cancel invitation'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Cancel Invitation'),
          ),
        ],
      ),
    );
  }
}

class _StaffDetailsSheet extends ConsumerWidget {
  final StaffMember staff;

  const _StaffDetailsSheet({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(storeLocationsProvider);
    final assignedLocations = staff.assignedLocationIds
        .map((id) => locations.firstWhere(
              (loc) => loc.id == id,
              orElse: () => StoreLocation(
                id: id,
                storeId: '',
                name: 'Unknown',
                address: '',
                phone: '',
                isDefault: false,
                isActive: true,
              ),
            ))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  staff.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  staff.email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: staff.isActive
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    staff.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: staff.isActive ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 24),
              const Text(
                'Assigned Locations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              if (assignedLocations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No locations assigned',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...assignedLocations.map((location) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (location.address.isNotEmpty)
                                  Text(
                                    location.address,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (location.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentLime,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.phone_outlined, 'Phone', staff.phone ?? 'Not set'),
              _buildInfoRow(Icons.pin_outlined, 'PIN', staff.pin != null ? 'Set' : 'Not set'),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'Joined',
                staff.createdAt != null
                    ? '${staff.createdAt!.day}/${staff.createdAt!.month}/${staff.createdAt!.year}'
                    : 'Unknown',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
