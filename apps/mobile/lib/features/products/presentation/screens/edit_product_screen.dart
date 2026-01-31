import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/product_provider.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/services/image_upload_service.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final String productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();

  File? _selectedImage;
  String? _existingImageUrl;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isDeleting = false;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  void _loadProduct() {
    final productState = ref.read(productProvider);
    final currentLocation = ref.read(currentLocationProvider);
    final product = productState.products.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => throw Exception('Product not found'),
    );

    _product = product;
    _nameController.text = product.name;
    _barcodeController.text = product.barcode ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _costController.text = product.cost?.toStringAsFixed(2) ?? '';
    // Get stock for current location
    _stockController.text = product.getStockForLocation(currentLocation?.id).toString();
    _descriptionController.text = product.description ?? '';
    _lowStockThresholdController.text = (product.lowStockThreshold ?? 10).toString();
    _existingImageUrl = product.image;

    // Handle category and subcategory assignment
    // The product might have categoryId pointing to a subcategory (old data)
    // We need to resolve this to set proper parent category and subcategory
    if (product.categoryId != null) {
      final allCategories = productState.categories;
      final category = allCategories.firstWhere(
        (c) => c.id == product.categoryId,
        orElse: () => Category(id: '', storeId: '', name: '', order: 0),
      );

      if (category.id.isNotEmpty) {
        if (category.isSubcategory) {
          // The categoryId is actually a subcategory - find its parent
          _selectedCategoryId = category.parentId;
          _selectedSubcategoryId = category.id;
        } else {
          // It's a top-level category
          _selectedCategoryId = product.categoryId;
          _selectedSubcategoryId = product.subcategoryId;
        }
      } else {
        // Category not found - clear both
        _selectedCategoryId = null;
        _selectedSubcategoryId = null;
      }
    } else {
      _selectedCategoryId = null;
      _selectedSubcategoryId = product.subcategoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null || _existingImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remove Image', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _existingImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    debugPrint('💾 _handleSave called');
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      return;
    }
    if (_product == null) {
      debugPrint('❌ Product is null');
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('💾 Starting save process...');

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        debugPrint('🖼️ Uploading new image...');
        setState(() => _isUploadingImage = true);
        try {
          final uploadService = ImageUploadService();
          final result = await uploadService.uploadProductImage(_selectedImage!);
          if (result.success && result.url != null) {
            imageUrl = result.url;
            debugPrint('✅ Image uploaded: $imageUrl');
          } else {
            throw Exception(result.error ?? 'Upload failed');
          }
        } catch (e) {
          debugPrint('❌ Image upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: $e'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
        setState(() => _isUploadingImage = false);
      }

      // Update product WITHOUT modifying stock (stock is managed via Restock feature)
      final updatedProduct = _product!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        cost: _costController.text.isEmpty ? null : double.parse(_costController.text),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
        lowStockThreshold: int.tryParse(_lowStockThresholdController.text) ?? 10,
        image: imageUrl,
        // Keep existing stock - do not modify
        stockByLocation: _product!.stockByLocation,
      );

      debugPrint('📝 Updated product stockByLocation: ${updatedProduct.stockByLocation}');
      debugPrint('📝 Calling updateProduct...');

      await ref.read(productProvider.notifier).updateProduct(updatedProduct);

      debugPrint('✅ updateProduct completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _handleSave: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      debugPrint('💾 _handleSave finally block');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${_product?.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    if (_product == null) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(productProvider.notifier).deleteProduct(_product!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLevelCategories = ref.watch(topLevelCategoriesProvider);
    final subcategories = _selectedCategoryId != null
        ? ref.watch(subcategoriesProvider(_selectedCategoryId!))
        : <Category>[];
    final currentLocation = ref.watch(currentLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _isDeleting ? null : _showDeleteDialog,
          ),
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Image
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                              ),
                            )
                          : _existingImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: _existingImageUrl!,
                                    fit: BoxFit.cover,
                                    width: 150,
                                    height: 150,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    errorWidget: (context, url, error) => Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 40,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to change',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Photo',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Barcode Section
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode / SKU',
                      hintText: 'Scan or enter manually',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    onPressed: () async {
                      final result = await context.push<String>('/products/scan');
                      if (result != null) {
                        _barcodeController.text = result;
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Product Name
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'Enter product name',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Category Dropdown (Top-level categories only)
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No Category'),
                ),
                ...topLevelCategories.map((category) => DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(category.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                  // Clear subcategory when category changes
                  _selectedSubcategoryId = null;
                });
              },
            ),

            // Subcategory Dropdown (only shown when a category is selected and has subcategories)
            if (_selectedCategoryId != null && subcategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSubcategoryId,
                decoration: const InputDecoration(
                  labelText: 'Subcategory / Brand (Optional)',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No Subcategory'),
                  ),
                  ...subcategories.map((subcategory) => DropdownMenuItem<String>(
                    value: subcategory.id,
                    child: Text(subcategory.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedSubcategoryId = value);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Price and Cost Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Selling Price *',
                      hintText: '0.00',
                      prefixText: '${AppConstants.currencySymbol} ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cost (Optional)',
                      hintText: '0.00',
                      prefixText: '${AppConstants.currencySymbol} ',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stock Display (Read-only) and Restock Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Stock @ ${currentLocation?.name ?? 'Current Location'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_stockController.text} units',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use Restock to add inventory',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_product != null) {
                            context.push('/products/${_product!.id}/restock');
                          }
                        },
                        icon: const Icon(Icons.add_box, size: 18),
                        label: const Text('Restock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Low Stock Threshold
            TextFormField(
              controller: _lowStockThresholdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert Threshold',
                hintText: '10',
                prefixIcon: Icon(Icons.warning_amber),
                helperText: 'Alert when stock falls below this number',
              ),
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter product description',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),

            const SizedBox(height: 16),

            // Delete Button
            OutlinedButton(
              onPressed: _isDeleting ? null : _showDeleteDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Text('Delete Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
