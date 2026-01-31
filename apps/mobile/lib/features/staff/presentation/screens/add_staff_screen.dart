import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/staff_provider.dart';
import '../../../../shared/providers/store_provider.dart';

enum AddStaffMode { invite, createAccount }

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final List<String> _selectedLocationIds = [];
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AddStaffMode _mode = AddStaffMode.createAccount; // Default to create account for simplicity

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addStaff() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one location'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success;
    if (_mode == AddStaffMode.createAccount) {
      success = await ref.read(staffProvider.notifier).createStaffAccount(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            assignedLocationIds: _selectedLocationIds,
          );
    } else {
      success = await ref.read(staffProvider.notifier).inviteStaff(
            email: _emailController.text.trim().toLowerCase(),
            assignedLocationIds: _selectedLocationIds,
          );
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        final message = _mode == AddStaffMode.createAccount
            ? 'Staff account created successfully! They can now login with their email and password.'
            : 'Staff member added/invited successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
        context.pop();
      } else {
        final error = ref.read(staffProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to add staff'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(staffProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(storeLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Staff Member'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        label: 'Create Account',
                        icon: Icons.person_add,
                        mode: AddStaffMode.createAccount,
                        description: 'Set login credentials',
                      ),
                    ),
                    Expanded(
                      child: _buildModeButton(
                        label: 'Invite by Email',
                        icon: Icons.mail_outline,
                        mode: AddStaffMode.invite,
                        description: 'They sign up later',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info card based on mode
              _buildInfoCard(),
              const SizedBox(height: 24),

              // Name field (only for create account mode)
              if (_mode == AddStaffMode.createAccount) ...[
                const Text(
                  'Staff Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Enter staff full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Email field
              const Text(
                'Email Address',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _mode == AddStaffMode.createAccount
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'staff@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password fields (only for create account mode)
              if (_mode == AddStaffMode.createAccount) ...[
                const Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Create a password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm the password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Location selection
              const Text(
                'Assigned Locations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select which locations this staff member can work at',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              if (locations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No locations available',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: locations.map((location) {
                      final isSelected = _selectedLocationIds.contains(location.id);
                      return CheckboxListTile(
                        title: Text(location.name),
                        subtitle: Text(
                          location.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: location.isDefault
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMuted.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedLocationIds.add(location.id);
                            } else {
                              _selectedLocationIds.remove(location.id);
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Quick select buttons
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedLocationIds.clear();
                        _selectedLocationIds.addAll(locations.map((l) => l.id));
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedLocationIds.clear();
                      });
                    },
                    icon: const Icon(Icons.deselect, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Role permissions info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text(
                          'Staff Permissions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionItem(Icons.point_of_sale, 'Make sales (POS)', true),
                    _buildPermissionItem(Icons.receipt_long, 'View own transactions', true),
                    _buildPermissionItem(Icons.qr_code_scanner, 'Scan barcodes', true),
                    _buildPermissionItem(Icons.inventory, 'Manage products', false),
                    _buildPermissionItem(Icons.people, 'Manage staff', false),
                    _buildPermissionItem(Icons.settings, 'Store settings', false),
                    _buildPermissionItem(Icons.analytics, 'View reports', false),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addStaff,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(_mode == AddStaffMode.createAccount
                          ? 'Create Staff Account'
                          : 'Send Invitation'),
                ),
              ),

              // Credentials reminder for create account mode
              if (_mode == AddStaffMode.createAccount) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Remember to share the login credentials with your staff member after creating their account.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required AddStaffMode mode,
    required String description,
  }) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    if (_mode == AddStaffMode.createAccount) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create an account for your staff with email and password. They can login immediately after you share the credentials.',
                style: TextStyle(
                  color: AppColors.success.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'If the email is already registered, they will be added as staff immediately. Otherwise, they will receive access when they sign up with this email.',
                style: TextStyle(
                  color: AppColors.info.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPermissionItem(IconData icon, String label, bool allowed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: allowed ? AppColors.success : AppColors.error.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: allowed ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
