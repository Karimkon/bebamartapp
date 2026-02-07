// lib/features/vendor/screens/create_service_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_crop_utils.dart';
import '../providers/vendor_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Service category model
class ServiceCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final List<ServiceCategoryModel> children;

  ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.children = const [],
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String?,
      children: (json['children'] as List?)
              ?.map((c) => ServiceCategoryModel.fromJson(c))
              .toList() ??
          [],
    );
  }
}

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _durationController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController(text: 'Kampala');
  final _featuresController = TextEditingController();

  ServiceCategoryModel? _selectedCategory;
  String _pricingType = 'fixed';
  bool _isMobile = false;
  List<File> _selectedImages = [];
  bool _isLoading = false;
  List<ServiceCategoryModel> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _priceMaxController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    print('📋 CreateServiceScreen: Loading categories...');
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/api/vendor/service-categories');

      if (!mounted) {
        print('⚠️ CreateServiceScreen: Widget disposed during category load');
        return;
      }

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List;
        setState(() {
          _categories = data.map((c) => ServiceCategoryModel.fromJson(c)).toList();
          _loadingCategories = false;
        });
        print('✅ CreateServiceScreen: Loaded ${_categories.length} categories');
      }
    } catch (e) {
      print('❌ CreateServiceScreen: Error loading categories: $e');
      if (mounted) {
        setState(() => _loadingCategories = false);
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

      if (!mounted) return;

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

      if (!mounted) return;

      if (croppedFile != null) {
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(createServiceProvider.notifier).createService(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        pricingType: _pricingType,
        price: _priceController.text.isNotEmpty
            ? double.parse(_priceController.text.trim())
            : null,
        priceMax: _priceMaxController.text.isNotEmpty
            ? double.parse(_priceMaxController.text.trim())
            : null,
        duration: _durationController.text.trim().isNotEmpty
            ? _durationController.text.trim()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        city: _cityController.text.trim(),
        isMobile: _isMobile,
        features: _featuresController.text.trim().isNotEmpty
            ? _featuresController.text.trim()
            : null,
        categoryId: _selectedCategory?.id,
        images: _selectedImages,
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Service created successfully!'),
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
    final createState = ref.watch(createServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Service'),
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

              // Service Details Section
              _buildSectionTitle('Service Details'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _titleController,
                label: 'Service Title',
                hint: 'e.g., Professional Plumbing Services',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a service title';
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
                hint: 'Describe your service in detail...',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.length < 20) {
                    return 'Description must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category Section
              _buildSectionTitle('Category'),
              const SizedBox(height: 12),
              _buildCategoryDropdown(),
              const SizedBox(height: 24),

              // Pricing Section
              _buildSectionTitle('Pricing'),
              const SizedBox(height: 12),
              _buildPricingTypeSelector(),
              const SizedBox(height: 16),
              if (_pricingType != 'free_quote' && _pricingType != 'negotiable') ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: _pricingType == 'starting_from' ? 'Starting Price (UGX)' : 'Price (UGX)',
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (_pricingType == 'fixed' || _pricingType == 'hourly') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter price';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_pricingType == 'fixed') ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _priceMaxController,
                          label: 'Max Price (Optional)',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                controller: _durationController,
                label: 'Duration (Optional)',
                hint: 'e.g., 1-2 hours, Same day',
              ),
              const SizedBox(height: 24),

              // Location Section
              _buildSectionTitle('Location'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _cityController,
                label: 'City',
                hint: 'e.g., Kampala',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter city';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Address (Optional)',
                hint: 'e.g., Nakasero, Plot 123',
              ),
              const SizedBox(height: 16),
              _buildMobileServiceToggle(),
              const SizedBox(height: 24),

              // Features Section
              _buildSectionTitle('Features (Optional)'),
              const SizedBox(height: 8),
              Text(
                'List your service features, one per line',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _featuresController,
                label: 'Features',
                hint: 'Free consultation\nSame day service\n24/7 support',
                maxLines: 4,
              ),
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
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Create Service',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        _buildSectionTitle('Service Images'),
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
              if (_selectedImages.length < 5)
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

              // Selected Images
              ..._selectedImages.asMap().entries.map((entry) {
                return _buildImageTile(
                  file: entry.value,
                  onRemove: () => _removeImage(entry.key),
                  isFirst: entry.key == 0,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile({
    required File file,
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
            child: Image.file(file, fit: BoxFit.cover),
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

  Widget _buildCategoryDropdown() {
    if (_loadingCategories) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => _showCategoryPicker(),
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
                _selectedCategory?.name ?? 'Select a category (optional)',
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

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final parent = _categories[index];
                  if (parent.children.isEmpty) {
                    return ListTile(
                      title: Text(parent.name),
                      onTap: () {
                        setState(() => _selectedCategory = parent);
                        Navigator.pop(context);
                      },
                    );
                  }

                  return ExpansionTile(
                    leading: Icon(Icons.category, color: AppColors.primary),
                    title: Text(
                      parent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${parent.children.length} subcategories',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    children: parent.children.map((child) {
                      final isSelected = _selectedCategory?.id == child.id;
                      return ListTile(
                        leading: Icon(
                          Icons.subdirectory_arrow_right,
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

  Widget _buildPricingTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PricingTypeChip(
          label: 'Fixed',
          isSelected: _pricingType == 'fixed',
          onTap: () => setState(() => _pricingType = 'fixed'),
        ),
        _PricingTypeChip(
          label: 'Hourly',
          isSelected: _pricingType == 'hourly',
          onTap: () => setState(() => _pricingType = 'hourly'),
        ),
        _PricingTypeChip(
          label: 'Starting From',
          isSelected: _pricingType == 'starting_from',
          onTap: () => setState(() => _pricingType = 'starting_from'),
        ),
        _PricingTypeChip(
          label: 'Negotiable',
          isSelected: _pricingType == 'negotiable',
          onTap: () => setState(() => _pricingType = 'negotiable'),
        ),
        _PricingTypeChip(
          label: 'Free Quote',
          isSelected: _pricingType == 'free_quote',
          onTap: () => setState(() => _pricingType = 'free_quote'),
        ),
      ],
    );
  }

  Widget _buildMobileServiceToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Service',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Service available at customer location',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isMobile,
            onChanged: (value) => setState(() => _isMobile = value),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PricingTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PricingTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
