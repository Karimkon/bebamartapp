// lib/features/vendor/screens/create_listing_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_crop_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vendor_provider.dart';
import '../../../shared/models/category_model.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  final int? listingId; // If provided, we're editing

  const CreateListingScreen({super.key, this.listingId});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

// Variant model for product variations
class ProductVariant {
  String? color;
  String? size;
  String sku;
  double price;
  double? salePrice;
  int stock;

  ProductVariant({
    this.color,
    this.size,
    this.sku = '',
    this.price = 0,
    this.salePrice,
    this.stock = 1,
  });

  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'sku': sku,
    'price': price,
    'sale_price': salePrice,
    'stock': stock,
  };
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _weightController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _taxDescriptionController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();

  CategoryModel? _selectedCategory;
  String _condition = 'new';
  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  List<int> _existingImageIds = []; // Tracks actual image IDs from API
  List<int> _deleteImageIds = [];
  bool _isLoading = false;

  // Variants
  bool _enableVariants = false;
  List<String> _colors = [];
  List<String> _sizes = [];
  List<ProductVariant> _variants = [];

  bool get isEditing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(createListingProvider.notifier).loadCategories();
      if (isEditing) {
        _loadExistingListing();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _taxAmountController.dispose();
    _taxDescriptionController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  void _addColor() {
    final color = _colorController.text.trim();
    if (color.isNotEmpty && !_colors.contains(color)) {
      setState(() {
        _colors.add(color);
        _colorController.clear();
      });
    }
  }

  void _removeColor(String color) {
    setState(() {
      _colors.remove(color);
      // Remove variants with this color
      _variants.removeWhere((v) => v.color == color);
    });
  }

  void _addSize() {
    final size = _sizeController.text.trim();
    if (size.isNotEmpty && !_sizes.contains(size)) {
      setState(() {
        _sizes.add(size);
        _sizeController.clear();
      });
    }
  }

  void _removeSize(String size) {
    setState(() {
      _sizes.remove(size);
      // Remove variants with this size
      _variants.removeWhere((v) => v.size == size);
    });
  }

  void _generateVariants() {
    if (_colors.isEmpty && _sizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one color or size')),
      );
      return;
    }

    final basePrice = double.tryParse(_priceController.text) ?? 0;
    final List<ProductVariant> newVariants = [];

    final colorsList = _colors.isEmpty ? [''] : _colors;
    final sizesList = _sizes.isEmpty ? [''] : _sizes;

    for (final color in colorsList) {
      for (final size in sizesList) {
        newVariants.add(ProductVariant(
          color: color.isEmpty ? null : color,
          size: size.isEmpty ? null : size,
          price: basePrice,
          stock: 1,
        ));
      }
    }

    setState(() {
      _variants = newVariants;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generated ${newVariants.length} variants')),
    );
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  Future<void> _loadExistingListing() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/api/vendor/listings/${widget.listingId}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final listing = response.data['listing'] as Map<String, dynamic>;

        setState(() {
          _titleController.text = listing['title'] ?? '';
          _descriptionController.text = listing['description'] ?? '';
          _priceController.text = (listing['price'] ?? '').toString().replaceAll(RegExp(r'\.0+$'), '');
          _quantityController.text = (listing['stock'] ?? 1).toString();
          _weightController.text = listing['weight_kg'] != null ? listing['weight_kg'].toString() : '';
          _taxAmountController.text = (listing['tax_amount'] != null && listing['tax_amount'] != 0) ? listing['tax_amount'].toString().replaceAll(RegExp(r'\.0+$'), '') : '';
          _taxDescriptionController.text = listing['tax_description'] ?? '';
          _condition = listing['condition'] ?? 'new';

          // Load existing images
          if (listing['images'] != null) {
            final images = listing['images'] as List;
            _existingImageUrls = images.map<String>((img) {
              final path = img['path'] ?? '';
              return '${AppConstants.storageUrl}/$path';
            }).toList();
            // Store image IDs for deletion tracking
            _existingImageIds = images.map<int>((img) => img['id'] as int).toList();
          }

          // Set selected category from the loaded listing (search 3 levels deep)
          if (listing['category'] != null) {
            final catData = listing['category'] as Map<String, dynamic>;
            final catId = catData['id'] as int;
            final categories = ref.read(createListingProvider).categories;
            for (final parent in categories) {
              if (parent.id == catId) { _selectedCategory = parent; break; }
              for (final child in parent.children) {
                if (child.id == catId) { _selectedCategory = child; break; }
                for (final grandchild in child.children) {
                  if (grandchild.id == catId) { _selectedCategory = grandchild; break; }
                }
                if (_selectedCategory != null) break;
              }
              if (_selectedCategory != null) break;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final List<File> croppedFiles = [];
        for (final xFile in images) {
          if (!mounted) break;
          final cropped = await ImageCropUtils.cropImage(
            File(xFile.path),
            CropStyle.freeForm,
            context,
          );
          if (cropped != null) {
            croppedFiles.add(cropped);
          }
        }
        if (croppedFiles.isNotEmpty && mounted) {
          setState(() {
            _selectedImages.addAll(croppedFiles);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final croppedFile = await ImageCropUtils.pickAndCropImage(
        source: ImageSource.camera,
        cropStyle: CropStyle.freeForm,
        context: context,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImages.add(croppedFile);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take picture: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
      if (index < _existingImageIds.length) {
        _deleteImageIds.add(_existingImageIds.removeAt(index));
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(createListingProvider.notifier);
      bool success;

      if (isEditing) {
        success = await notifier.updateListing(
          listingId: widget.listingId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          categoryId: _selectedCategory!.id,
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          condition: _condition,
          newImages: _selectedImages.isNotEmpty ? _selectedImages : null,
          deleteImageIds: _deleteImageIds.isNotEmpty ? _deleteImageIds : null,
          taxAmount: _taxAmountController.text.trim().isNotEmpty
              ? double.tryParse(_taxAmountController.text.trim())
              : 0,
          taxDescription: _taxDescriptionController.text.trim().isNotEmpty
              ? _taxDescriptionController.text.trim()
              : null,
        );
      } else {
        // Prepare variants if enabled
        List<Map<String, dynamic>>? variationsData;
        if (_enableVariants && _variants.isNotEmpty) {
          variationsData = _variants.map((v) => v.toJson()).toList();
        }

        success = await notifier.createListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          categoryId: _selectedCategory!.id,
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          condition: _condition,
          images: _selectedImages,
          weight: _weightController.text.trim().isNotEmpty
              ? double.tryParse(_weightController.text.trim())
              : null,
          variations: variationsData,
          taxAmount: _taxAmountController.text.trim().isNotEmpty
              ? double.tryParse(_taxAmountController.text.trim())
              : 0,
          taxDescription: _taxDescriptionController.text.trim().isNotEmpty
              ? _taxDescriptionController.text.trim()
              : null,
        );
      }

      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Product updated!' : 'Product created!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createListingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images Section
              _buildImagesSection(),
              const SizedBox(height: 24),

              // Product Details Section
              _buildSectionTitle('Product Details'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _titleController,
                label: 'Product Title',
                hint: 'Enter product name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a product title';
                  }
                  if (value.length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe your product...',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category Section
              _buildSectionTitle('Category'),
              const SizedBox(height: 12),
              _buildCategoryDropdown(createState.categories),
              const SizedBox(height: 24),

              // Pricing Section
              _buildSectionTitle('Pricing & Inventory'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Price (UGX)',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: 'Stock',
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty < 1) {
                          return 'Min 1';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weight field
              _buildTextField(
                controller: _weightController,
                label: 'Weight (kg)',
                hint: 'Optional - e.g., 0.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 24),

              // Tax / Import Charges Section
              _buildSectionTitle('Import / Tax Charges'),
              const SizedBox(height: 4),
              Text(
                'If this product has import duties or tax charges, specify them here.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _taxAmountController,
                label: 'Tax / Import Charge per unit (UGX)',
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _taxDescriptionController,
                label: 'Tax Description',
                hint: 'e.g., Import duty & customs clearance',
              ),
              const SizedBox(height: 24),

              // Condition Section
              _buildSectionTitle('Condition'),
              const SizedBox(height: 12),
              _buildConditionSelector(),
              const SizedBox(height: 24),

              // Variants Section
              _buildVariantsSection(),
              const SizedBox(height: 32),

              // Error Message
              if (createState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(createState.error!, style: TextStyle(color: AppColors.error)),
                ),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading || createState.isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading || createState.isLoading
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Update Product' : 'Create Product',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Product Images'),
        const SizedBox(height: 8),
        Text(
          'Add up to 5 images. First image will be the main photo.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add Image Button
              if (_selectedImages.length + _existingImageUrls.length < 5)
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
                        const SizedBox(height: 4),
                        Text('Add Photo', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // Existing Images
              ..._existingImageUrls.asMap().entries.map((entry) {
                return _buildImageTile(
                  imageUrl: entry.value,
                  onRemove: () => _removeExistingImage(entry.key),
                  isFirst: entry.key == 0 && _selectedImages.isEmpty,
                );
              }),

              // New Selected Images
              ..._selectedImages.asMap().entries.map((entry) {
                return _buildImageTile(
                  file: entry.value,
                  onRemove: () => _removeImage(entry.key),
                  isFirst: entry.key == 0 && _existingImageUrls.isEmpty,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile({
    File? file,
    String? imageUrl,
    required VoidCallback onRemove,
    bool isFirst = false,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isFirst ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: file != null
                ? Image.file(file, fit: BoxFit.cover)
                : Image.network(imageUrl!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 16,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        if (isFirst)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(List<CategoryModel> parentCategories) {
    // Build grouped dropdown items - show ONLY subcategories, grouped by parent
    final List<DropdownMenuItem<CategoryModel>> items = [];

    for (final parent in parentCategories) {
      if (parent.children.isNotEmpty) {
        // Add parent as a disabled header
        items.add(DropdownMenuItem<CategoryModel>(
          enabled: false,
          value: null,
          child: Text(
            parent.name.toUpperCase(),
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ));

        // Add children (subcategories) as selectable items
        for (final child in parent.children) {
          items.add(DropdownMenuItem<CategoryModel>(
            value: child,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(child.name),
            ),
          ));
        }
      }
    }

    return GestureDetector(
      onTap: () => _showCategoryPicker(parentCategories),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategory?.name ?? 'Select a category',
                style: TextStyle(
                  color: _selectedCategory != null ? AppColors.textPrimary : AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(List<CategoryModel> parentCategories) {
    // Filter to only categories with children
    final filteredCategories = parentCategories.where((c) => c.children.isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            // Category list
            if (filteredCategories.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final parent = filteredCategories[index];

                  return ExpansionTile(
                    leading: Icon(parent.iconData, color: AppColors.primary),
                    title: Text(
                      parent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${parent.children.length} subcategories',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    children: parent.children.map((child) {
                      // If this subcategory has its own children (3rd level), show as expandable
                      if (child.children.isNotEmpty) {
                        return ExpansionTile(
                          leading: Icon(
                            child.iconData,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          title: Text(
                            child.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${child.children.length} subcategories',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          children: child.children.map((grandchild) {
                            final isSelected = _selectedCategory?.id == grandchild.id;
                            return ListTile(
                              contentPadding: const EdgeInsets.only(left: 40),
                              leading: Icon(
                                grandchild.iconData,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                size: 18,
                              ),
                              title: Text(
                                grandchild.name,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                                  : null,
                              onTap: () {
                                setState(() => _selectedCategory = grandchild);
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        );
                      }
                      // Leaf subcategory (no children) - show as selectable ListTile
                      final isSelected = _selectedCategory?.id == child.id;
                      return ListTile(
                        leading: Icon(
                          child.iconData,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          child.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: AppColors.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedCategory = child);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionSelector() {
    return Row(
      children: [
        Expanded(child: _ConditionOption(label: 'New', isSelected: _condition == 'new', onTap: () => setState(() => _condition = 'new'))),
        const SizedBox(width: 12),
        Expanded(child: _ConditionOption(label: 'Used', isSelected: _condition == 'used', onTap: () => setState(() => _condition = 'used'))),
        const SizedBox(width: 12),
        Expanded(child: _ConditionOption(label: 'Refurbished', isSelected: _condition == 'refurbished', onTap: () => setState(() => _condition = 'refurbished'))),
      ],
    );
  }

  Widget _buildVariantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle for enabling variants
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _enableVariants,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        _enableVariants = value ?? false;
                        if (!_enableVariants) {
                          _colors.clear();
                          _sizes.clear();
                          _variants.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enable Product Variants',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Add different colors/sizes with individual prices and stock',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Variants builder UI
        if (_enableVariants) ...[
          const SizedBox(height: 16),

          // Colors Section
          _buildSectionTitle('Available Colors'),
          const SizedBox(height: 8),
          _buildChipsSection(
            items: _colors,
            onRemove: _removeColor,
            chipColor: Colors.blue,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _colorController,
                  decoration: InputDecoration(
                    hintText: 'Add color (e.g., Red, Blue)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _addColor(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addColor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sizes Section
          _buildSectionTitle('Available Sizes'),
          const SizedBox(height: 8),
          _buildChipsSection(
            items: _sizes,
            onRemove: _removeSize,
            chipColor: Colors.green,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sizeController,
                  decoration: InputDecoration(
                    hintText: 'Add size (e.g., S, M, L, XL)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _addSize(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addSize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Generate Variants Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateVariants,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Variants'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Variants List
          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Variants (${_variants.length})'),
            const SizedBox(height: 8),
            ..._variants.asMap().entries.map((entry) {
              final index = entry.key;
              final variant = entry.value;
              return _buildVariantCard(variant, index);
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildChipsSection({
    required List<String> items,
    required Function(String) onRemove,
    required Color chipColor,
  }) {
    if (items.isEmpty) {
      return Text(
        'No items added yet',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Chip(
          label: Text(item, style: const TextStyle(color: Colors.white)),
          backgroundColor: chipColor,
          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
          onDeleted: () => onRemove(item),
        );
      }).toList(),
    );
  }

  Widget _buildVariantCard(ProductVariant variant, int index) {
    final variantName = [variant.color, variant.size].where((e) => e != null && e.isNotEmpty).join(' / ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  variantName.isEmpty ? 'Variant ${index + 1}' : variantName,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeVariant(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price and Stock
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (UGX)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  controller: TextEditingController(text: variant.price.toString()),
                  onChanged: (value) {
                    variant.price = double.tryParse(value) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  controller: TextEditingController(text: variant.stock.toString()),
                  onChanged: (value) {
                    variant.stock = int.tryParse(value) ?? 1;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConditionOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}