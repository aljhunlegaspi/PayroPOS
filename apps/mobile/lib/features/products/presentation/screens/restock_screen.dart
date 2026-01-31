import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/product_provider.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/providers/stock_provider.dart';
import '../../../../shared/providers/auth_provider.dart';

class RestockScreen extends ConsumerStatefulWidget {
  final String productId;

  const RestockScreen({super.key, required this.productId});

  @override
  ConsumerState<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedLocationId;
  bool _isLoading = false;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load product
    final productState = ref.read(productProvider);
    _product = productState.products.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => throw Exception('Product not found'),
    );

    // Set default location
    final currentLocation = ref.read(currentLocationProvider);
    _selectedLocationId = currentLocation?.id;

    // Load stock history for this product
    ref.read(stockProvider.notifier).loadProductHistory(widget.productId);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int _getCurrentStock() {
    if (_product == null || _selectedLocationId == null) return 0;
    return _product!.getStockForLocation(_selectedLocationId);
  }

  Future<void> _handleRestock() async {
    if (!_formKey.currentState!.validate()) return;
    if (_product == null || _selectedLocationId == null) return;

    setState(() => _isLoading = true);

    try {
      final locations = ref.read(storeLocationsProvider);
      final location = locations.firstWhere((l) => l.id == _selectedLocationId);
      final currentUser = ref.read(currentUserProvider);
      final userData = ref.read(userDataProvider);

      await ref.read(stockProvider.notifier).restockProduct(
        product: _product!,
        locationId: _selectedLocationId!,
        locationName: location.name,
        quantityToAdd: int.parse(_quantityController.text),
        notes: _notesController.text.isEmpty ? null : _notesController.text.trim(),
        userId: currentUser?.uid,
        userName: userData?['firstName'] ?? 'Unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restocked ${_quantityController.text} units of ${_product!.name}'),
            backgroundColor: AppColors.success,
          ),
        );

        // Clear form for another restock
        _quantityController.clear();
        _notesController.clear();

        // Reload product data
        _loadData();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    final locations = ref.watch(storeLocationsProvider);
    final stockState = ref.watch(stockProvider);
    final currentStock = _getCurrentStock();

    // Refresh product data when stock changes
    final productState = ref.watch(productProvider);
    _product = productState.products.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => _product!,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Restock Product'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _product?.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _product!.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.inventory_2,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : const Icon(Icons.inventory_2, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _product?.name ?? 'Loading...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_product?.barcode != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${_product!.barcode}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location Selector
            Text(
              'Select Location',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLocationId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: 'Select location',
              ),
              items: locations.map((location) {
                final stock = _product?.getStockForLocation(location.id) ?? 0;
                return DropdownMenuItem<String>(
                  value: location.id,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(location.name),
                      Text(
                        '$stock in stock',
                        style: TextStyle(
                          color: stock <= 0 ? AppColors.error : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedLocationId = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a location';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Current Stock Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentStock <= 0
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    currentStock <= 0 ? Icons.warning_amber : Icons.inventory,
                    color: currentStock <= 0 ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Stock',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$currentStock units',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: currentStock <= 0 ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quantity Input
            Text(
              'Quantity to Add',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.add_box_outlined),
                suffixText: 'units',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) {
                  return 'Quantity must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 8),

            // Quick quantity buttons
            Wrap(
              spacing: 8,
              children: [10, 25, 50, 100].map((qty) => ActionChip(
                label: Text('+$qty'),
                onPressed: () => _quantityController.text = qty.toString(),
              )).toList(),
            ),

            const SizedBox(height: 24),

            // Notes Input
            Text(
              'Notes (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g., Received from supplier, inventory adjustment...',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),

            // Restock Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleRestock,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_box),
              label: Text(_isLoading ? 'Processing...' : 'Restock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            // Stock History Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restock History',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (stockState.history.isNotEmpty)
                  Text(
                    '${stockState.history.length} entries',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (stockState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (stockState.history.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No restock history yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...stockState.history.map((entry) => _StockHistoryTile(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _StockHistoryTile extends StatelessWidget {
  final StockHistory entry;

  const _StockHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${entry.quantityAdded}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.locationName,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                '${entry.previousStock} -> ${entry.newStock}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormat.format(entry.createdAt),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              if (entry.userName != null)
                Text(
                  'by ${entry.userName}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.notes!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
