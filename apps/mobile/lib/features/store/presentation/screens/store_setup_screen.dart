import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';

class StoreSetupScreen extends ConsumerStatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  ConsumerState<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends ConsumerState<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedBusinessType = 'retail';
  bool _hasMultipleLocations = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _businessTypes = [
    {'value': 'retail', 'label': 'Retail Store', 'icon': Icons.storefront},
    {'value': 'restaurant', 'label': 'Restaurant/Cafe', 'icon': Icons.restaurant},
    {'value': 'grocery', 'label': 'Grocery/Sari-sari', 'icon': Icons.shopping_basket},
    {'value': 'pharmacy', 'label': 'Pharmacy', 'icon': Icons.medical_services},
    {'value': 'hardware', 'label': 'Hardware Store', 'icon': Icons.hardware},
    {'value': 'other', 'label': 'Other', 'icon': Icons.business},
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not authenticated');

      final firestore = FirebaseFirestore.instance;

      // Create the store document
      final storeRef = firestore.collection(AppConstants.storesCollection).doc();

      // Determine location name
      final locationName = _hasMultipleLocations
          ? _locationNameController.text.trim()
          : _storeNameController.text.trim(); // Use store name as location name for single location

      await storeRef.set({
        'id': storeRef.id,
        'ownerId': user.uid,
        'name': _storeNameController.text.trim(),
        'businessType': _selectedBusinessType,
        'hasMultipleLocations': _hasMultipleLocations,
        'logo': null,
        'settings': {
          'currency': 'PHP',
          'currencySymbol': '₱',
          'taxRate': 0.12,
          'receiptFooter': 'Thank you for your purchase!',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create the first location document
      final locationRef = storeRef.collection('locations').doc();
      await locationRef.set({
        'id': locationRef.id,
        'storeId': storeRef.id,
        'name': locationName,
        'address': _addressController.text.trim(),
        'phone': '+63 ${_phoneController.text.trim()}',
        'isDefault': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document with store and default location reference
      // Using set with merge to handle cases where user doc might not exist
      await firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': user.email,
        'storeId': storeRef.id,
        'defaultLocationId': locationRef.id,
        'hasCompletedSetup': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Refresh auth state to include new storeId
      await ref.read(authProvider.notifier).refreshUserData();

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create store: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we can go back
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.home_outlined, color: AppColors.textPrimary),
                onPressed: () => context.go('/home'),
              ),
      ),
      body: SafeArea(
        top: false, // AppBar handles top safe area
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.store,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Set Up Your Store',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us about your business to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Store/Brand Name
                TextFormField(
                  controller: _storeNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _hasMultipleLocations ? 'Brand/Company Name' : 'Store Name',
                    hintText: _hasMultipleLocations
                        ? 'Enter your brand or company name'
                        : 'Enter your store name',
                    prefixIcon: const Icon(Icons.store_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _hasMultipleLocations
                          ? 'Please enter your brand/company name'
                          : 'Please enter your store name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Business Type
                Text(
                  'Business Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _businessTypes.map((type) {
                    final isSelected = _selectedBusinessType == type['value'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(type['label'] as String),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedBusinessType = type['value'] as String;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Location Type Selection
                Text(
                  'Number of Locations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LocationOptionCard(
                        icon: Icons.location_on,
                        title: 'Single Location',
                        subtitle: 'I have one store',
                        isSelected: !_hasMultipleLocations,
                        onTap: () => setState(() => _hasMultipleLocations = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LocationOptionCard(
                        icon: Icons.location_city,
                        title: 'Multiple Locations',
                        subtitle: 'I have branches',
                        isSelected: _hasMultipleLocations,
                        onTap: () => setState(() => _hasMultipleLocations = true),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Location Name (only for multiple locations)
                if (_hasMultipleLocations) ...[
                  TextFormField(
                    controller: _locationNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Location/Branch Name',
                      hintText: 'e.g., Main Branch, SM Mall Branch',
                      prefixIcon: Icon(Icons.place_outlined),
                      helperText: 'You can add more locations later',
                    ),
                    validator: (value) {
                      if (_hasMultipleLocations && (value == null || value.isEmpty)) {
                        return 'Please enter a location name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Address
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _hasMultipleLocations ? 'Location Address' : 'Store Address',
                    hintText: 'Enter the complete address',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _hasMultipleLocations ? 'Location Phone' : 'Store Phone',
                    hintText: 'Enter contact number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    prefixText: '+63 ',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Create Store Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateStore,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_hasMultipleLocations
                          ? 'Create Store & First Location'
                          : 'Create Store'),
                ),

                const SizedBox(height: 16),

                // Skip for now (optional)
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for location type selection card
class _LocationOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocationOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
