// lib/shared/models/service_model.dart
import 'category_model.dart';
import '../../../core/constants/app_constants.dart';

class VendorServiceModel {
  final int id;
  final String title;
  final String slug;
  final String? price;
  final String? image;
  final ServiceVendorPreview vendor;
  final ServiceCategoryPreview? category;

  final String? description;
  final String? location;
  final String? city;

  VendorServiceModel({
    required this.id,
    required this.title,
    required this.slug,
    this.price,
    this.image,
    required this.vendor,
    this.category,
    this.description,
    this.location,
    this.city,
  });

  factory VendorServiceModel.fromJson(Map<String, dynamic> json) {
    return VendorServiceModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Service',
      slug: json['slug'] as String? ?? '',
      price: json['price']?.toString(),
      image: json['image'] as String?,
      vendor: ServiceVendorPreview.fromJson(json['vendor'] as Map<String, dynamic>),
      category: json['category'] != null
          ? ServiceCategoryPreview.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String?,
      location: json['location'] as String?,
      city: json['city'] as String?,
    );
  }

  String get fullImagePath {
    if (image == null || image!.isEmpty) return '';
    if (image!.startsWith('http')) return image!;
    return '${AppConstants.storageUrl}/$image';
  }
}

class ServiceVendorPreview {
  final int id;
  final String businessName;

  ServiceVendorPreview({
    required this.id,
    required this.businessName,
  });

  factory ServiceVendorPreview.fromJson(Map<String, dynamic> json) {
    return ServiceVendorPreview(
      id: json['id'] as int,
      businessName: json['business_name'] as String? ?? 'Unknown Vendor',
    );
  }
}

class ServiceCategoryPreview {
  final int id;
  final String name;
  final String slug;

  ServiceCategoryPreview({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ServiceCategoryPreview.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryPreview(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Category',
      slug: json['slug'] as String? ?? '',
    );
  }
}
