import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/product_provider.dart';
import '../../../../shared/providers/store_provider.dart';
import '../../../../shared/services/image_upload_service.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? scannedBarcode;

  const AddProductScreen({super.key, this.scannedBarcode});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _lowStockThresholdController = TextEditingController(text: '10');
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.scannedBarcode != null) {
      _barcodeController.text = widget.scannedBarcode!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _descriptionController.dispose();
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
            if (_selectedImage != null || _uploadedImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remove Image', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _uploadedImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _uploadedImageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        debugPrint('🖼️ Image selected, starting upload...');
        debugPrint('   Path: ${_selectedImage!.path}');
        setState(() => _isUploadingImage = true);
        try {
          final uploadService = ImageUploadService();
          final result = await uploadService.uploadProductImage(_selectedImage!);
          debugPrint('🖼️ Upload result: success=${result.success}, url=${result.url}, error=${result.error}');
          if (result.success && result.url != null) {
            imageUrl = result.url;
            debugPrint('✅ Image URL set: $imageUrl');
          } else {
            debugPrint('❌ Upload failed: ${result.error}');
            throw Exception(result.error ?? 'Upload failed');
          }
        } catch (e) {
          debugPrint('❌ Upload exception: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: $e'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          // Continue without image
        }
        setState(() => _isUploadingImage = false);
      } else {
        debugPrint('🖼️ No image selected');
      }

      // Get current location
      final currentLocation = ref.read(currentLocationProvider);
      if (currentLocation == null) {
        throw Exception('No location selected');
      }

      // Add product
      await ref.read(productProvider.notifier).addProduct(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            price: double.parse(_priceController.text),
            cost: _costController.text.isEmpty
                ? null
                : double.parse(_costController.text),
            barcode: _barcodeController.text.trim().isEmpty
                ? null
                : _barcodeController.text.trim(),
            categoryId: _selectedCategoryId,
            subcategoryId: _selectedSubcategoryId,
            locationId: currentLocation.id,
            stock: int.parse(_stockController.text),
            lowStockThreshold: int.tryParse(_lowStockThresholdController.text) ?? 10,
            image: imageUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
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
    final topLevelCategories = ref.watch(topLevelCategoriesProvider);
    final subcategories = _selectedCategoryId != null
        ? ref.watch(subcategoriesProvider(_selectedCategoryId!))
        : <Category>[];
    final currentLocation = ref.watch(currentLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
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

            // Stock and Low Stock Threshold Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: currentLocation != null
                          ? 'Stock @ ${currentLocation.name}'
                          : 'Stock Quantity *',
                      hintText: '0',
                      prefixIcon: const Icon(Icons.inventory),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lowStockThresholdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Low Stock Alert',
                      hintText: '10',
                      prefixIcon: Icon(Icons.warning_amber),
                    ),
                  ),
                ),
              ],
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
                    : const Text('Add Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
