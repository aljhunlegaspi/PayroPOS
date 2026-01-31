import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/services/image_upload_service.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Try to load store if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureStoreLoaded();
    });
  }

  void _ensureStoreLoaded() {
    final storeState = ref.read(storeProvider);
    if (storeState.store == null && !storeState.isLoading) {
      final userData = ref.read(userDataProvider);
      final storeId = userData?['storeId'] as String?;
      final locationId = userData?['defaultLocationId'] as String?;
      if (storeId != null) {
        ref.read(storeProvider.notifier).loadStore(storeId, locationId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeProvider);
    final store = storeState.store;
    final locations = storeState.locations;

    if (storeState.isLoading && store == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Store Settings'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (store == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Store Settings'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'No store found',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete the store setup first',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/store-setup'),
                child: const Text('Setup Store'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _ensureStoreLoaded,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Details Section
          _SectionHeader(title: 'Business Details'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.store,
                title: store.name,
                subtitle: _getBusinessTypeLabel(store.businessType),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/store-settings/edit-store'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Locations Section
          _SectionHeader(
            title: 'Locations',
            trailing: store.hasMultipleLocations || locations.length > 1
                ? TextButton.icon(
                    onPressed: () => context.push('/store-settings/add-location'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  )
                : null,
          ),
          const SizedBox(height: 8),

          if (!store.hasMultipleLocations && locations.length == 1) ...[
            // Single location - show upgrade option
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.location_on,
                  title: locations.first.name,
                  subtitle: locations.first.address,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/store-settings/edit-location/${locations.first.id}',
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.add_location_alt,
                  iconColor: AppColors.primary,
                  title: 'Expand to Multiple Locations',
                  subtitle: 'Add branches or additional stores',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                  onTap: () => _showExpandLocationsDialog(context, ref),
                ),
              ],
            ),
          ] else ...[
            // Multiple locations
            _SettingsCard(
              children: [
                for (int i = 0; i < locations.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LocationTile(
                    location: locations[i],
                    onTap: () => context.push(
                      '/store-settings/edit-location/${locations[i].id}',
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Business Settings Section
          _SectionHeader(title: 'Business Settings'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.attach_money,
                title: 'Currency',
                subtitle: '${store.settings['currencySymbol'] ?? '₱'} ${store.settings['currency'] ?? 'PHP'}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCurrencyDialog(context, ref, store),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.percent,
                title: 'Tax Rate',
                subtitle: '${_formatTaxRate(store.settings['taxRate'])}%',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTaxRateDialog(context, ref, store),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.receipt_long,
                title: 'Receipt Footer',
                subtitle: store.settings['receiptFooter'] ?? 'Thank you for your purchase!',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showReceiptFooterDialog(context, ref, store),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // POS Settings Section
          _SectionHeader(title: 'POS Settings'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchSettingsTile(
                icon: Icons.dialpad,
                title: 'Require Quantity Input',
                subtitle: 'Show quantity dialog when adding products',
                value: store.settings['requireQuantityInput'] ?? false,
                onChanged: (value) async {
                  try {
                    await ref.read(storeProvider.notifier).updateStoreSettings({
                      'requireQuantityInput': value,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value
                              ? 'Quantity input enabled'
                              : 'Quantity input disabled'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Payment Methods Section
          _SectionHeader(title: 'Payment QR Codes'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _QRCodeSettingsTile(
                icon: Icons.phone_android,
                iconColor: const Color(0xFF007DFE), // GCash blue
                title: 'GCash QR Code',
                subtitle: store.settings['gcashQrCode'] != null
                    ? 'QR code uploaded'
                    : 'Upload your GCash QR code',
                qrCodeUrl: store.settings['gcashQrCode'],
                onUpload: () => _uploadQRCode(context, ref, store, 'gcash'),
                onRemove: store.settings['gcashQrCode'] != null
                    ? () => _removeQRCode(context, ref, 'gcash')
                    : null,
              ),
              const Divider(height: 1),
              _QRCodeSettingsTile(
                icon: Icons.phone_android,
                iconColor: const Color(0xFF00B140), // Maya green
                title: 'Maya QR Code',
                subtitle: store.settings['mayaQrCode'] != null
                    ? 'QR code uploaded'
                    : 'Upload your Maya QR code',
                qrCodeUrl: store.settings['mayaQrCode'],
                onUpload: () => _uploadQRCode(context, ref, store, 'maya'),
                onRemove: store.settings['mayaQrCode'] != null
                    ? () => _removeQRCode(context, ref, 'maya')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Upload your e-wallet QR codes so customers can scan to pay during checkout.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _uploadQRCode(BuildContext context, WidgetRef ref, Store store, String type) async {
    final picker = ImagePicker();
    final uploadService = ImageUploadService();

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!context.mounted) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading QR code...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Upload to Cloudinary
      final file = File(pickedFile.path);
      final result = await uploadService.uploadImage(
        file,
        folder: 'payropos/stores/${store.id}/payment_qr',
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Upload failed');
      }

      // Update store settings
      await ref.read(storeProvider.notifier).updateStoreSettings({
        '${type}QrCode': result.url,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == 'gcash' ? 'GCash' : 'Maya'} QR code uploaded'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading QR code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeQRCode(BuildContext context, WidgetRef ref, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${type == 'gcash' ? 'GCash' : 'Maya'} QR Code?'),
        content: const Text('Customers will not be able to pay using this method at checkout.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(storeProvider.notifier).updateStoreSettings({
        '${type}QrCode': null,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == 'gcash' ? 'GCash' : 'Maya'} QR code removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getBusinessTypeLabel(String type) {
    switch (type) {
      case 'retail':
        return 'Retail Store';
      case 'restaurant':
        return 'Restaurant/Cafe';
      case 'grocery':
        return 'Grocery/Sari-sari';
      case 'pharmacy':
        return 'Pharmacy';
      case 'hardware':
        return 'Hardware Store';
      default:
        return 'Other';
    }
  }

  String _formatTaxRate(dynamic taxRate) {
    if (taxRate == null) return '12';
    final rate = (taxRate as num).toDouble();
    // If rate > 1, it's stored as percentage (12.0), otherwise as decimal (0.12)
    if (rate > 1) {
      return rate.toStringAsFixed(0);
    } else {
      return (rate * 100).toStringAsFixed(0);
    }
  }

  void _showTaxRateDialog(BuildContext context, WidgetRef ref, dynamic store) {
    final currentRateDisplay = _formatTaxRate(store.settings['taxRate']);
    final controller = TextEditingController(text: currentRateDisplay);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tax Rate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the tax rate percentage for your store.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tax Rate',
                  suffixText: '%',
                  hintText: 'e.g., 12',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value == null || value < 0 || value > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid percentage (0-100)'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              try {
                // Update store settings with new tax rate (convert to decimal)
                final newTaxRate = value / 100;
                await ref.read(storeProvider.notifier).updateStoreSettings({
                  'taxRate': newTaxRate,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tax rate updated to ${value.toStringAsFixed(0)}%'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating tax rate: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref, dynamic store) {
    final currencies = [
      {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
      {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
      {'code': 'KRW', 'symbol': '₩', 'name': 'Korean Won'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
      {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
      {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
      {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
      {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
      {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
      {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    ];

    final currentCode = store.settings['currency'] ?? 'PHP';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              final isSelected = currency['code'] == currentCode;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      currency['symbol']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  currency['code']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                subtitle: Text(currency['name']!),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref.read(storeProvider.notifier).updateStoreSettings({
                      'currency': currency['code'],
                      'currencySymbol': currency['symbol'],
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Currency changed to ${currency['code']}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showReceiptFooterDialog(BuildContext context, WidgetRef ref, dynamic store) {
    final currentFooter = store.settings['receiptFooter'] ?? 'Thank you for your purchase!';
    final controller = TextEditingController(text: currentFooter);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Footer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This message appears at the bottom of every receipt.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Footer Message',
                  hintText: 'e.g., Thank you for shopping with us!',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // Quick suggestions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FooterSuggestionChip(
                    label: 'Thank you!',
                    onTap: () => controller.text = 'Thank you for your purchase!',
                  ),
                  _FooterSuggestionChip(
                    label: 'Come again',
                    onTap: () => controller.text = 'Thank you! Please come again.',
                  ),
                  _FooterSuggestionChip(
                    label: 'With contact',
                    onTap: () => controller.text = 'Thank you for your purchase!\nQuestions? Contact us anytime.',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final footer = controller.text.trim();
              Navigator.pop(context);

              try {
                await ref.read(storeProvider.notifier).updateStoreSettings({
                  'receiptFooter': footer.isEmpty ? 'Thank you for your purchase!' : footer,
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt footer updated'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExpandLocationsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expand to Multiple Locations?'),
        content: const Text(
          'This will allow you to add multiple branches or store locations. '
          'Each location can have its own address, phone, and inventory.\n\n'
          'Your current store will become your first location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(storeProvider.notifier).enableMultipleLocations();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Multiple locations enabled! You can now add more locations.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.push('/store-settings/add-location');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.textSecondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.textSecondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final StoreLocation location;
  final VoidCallback? onTap;

  const _LocationTile({required this.location, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: location.isDefault
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.location_on,
          color: location.isDefault ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(location.name)),
          if (location.isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Default',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        location.address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _FooterSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterSuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _QRCodeSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String? qrCodeUrl;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  const _QRCodeSettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.qrCodeUrl,
    required this.onUpload,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.textSecondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qrCodeUrl != null) ...[
            // Preview button
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: () => _showQRCodePreview(context),
              tooltip: 'Preview',
              color: AppColors.primary,
            ),
            // Remove button
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onRemove,
                tooltip: 'Remove',
                color: AppColors.error,
              ),
          ] else
            // Upload button
            TextButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload, size: 18),
              label: const Text('Upload'),
            ),
        ],
      ),
      onTap: qrCodeUrl != null ? () => _showQRCodePreview(context) : onUpload,
    );
  }

  void _showQRCodePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // QR Code Image
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: qrCodeUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 200,
                    height: 200,
                    color: AppColors.surfaceVariant,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        SizedBox(height: 8),
                        Text('Failed to load image'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onUpload,
                      icon: const Icon(Icons.upload),
                      label: const Text('Replace'),
                    ),
                  ),
                  if (onRemove != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onRemove!();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
