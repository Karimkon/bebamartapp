// lib/shared/models/category_model.dart
// Category model mapped 1:1 with Laravel categories table

// Import Icons if not already imported - MUST BE AT TOP
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? image;
  final bool isActive;
  final int? parentId;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Relationships
  final CategoryModel? parent;
  final List<CategoryModel> children;
  final int? listingsCount;
  
  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.image,
    this.isActive = true,
    this.parentId,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.parent,
    this.children = const [],
    this.listingsCount,
  });
  
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    // Parse parent
    CategoryModel? parent;
    if (json['parent'] != null && json['parent'] is Map<String, dynamic>) {
      parent = CategoryModel.fromJson(Map<String, dynamic>.from(json['parent']));
    }
    
    // Parse children
    List<CategoryModel> children = [];
    if (json['children'] != null && json['children'] is List) {
      children = (json['children'] as List)
          .whereType<Map<String, dynamic>>()
          .map((child) => CategoryModel.fromJson(Map<String, dynamic>.from(child)))
          .toList();
    }
    
    // Parse dates safely
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }
    
    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Category',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      image: json['image']?.toString(),
      isActive: json['is_active'] == true || 
                json['is_active'] == 1 || 
                json['is_active'] == '1' ||
                json['is_active'] == null,
      parentId: json['parent_id'] is int 
          ? json['parent_id'] 
          : json['parent_id'] != null 
            ? int.tryParse(json['parent_id'].toString()) 
            : null,
      sortOrder: json['sort_order'] is int 
          ? json['sort_order'] 
          : json['order'] is int 
            ? json['order'] 
            : int.tryParse(json['sort_order'].toString()) ?? 0,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      parent: parent,
      children: children,
      listingsCount: json['listings_count'] is int 
          ? json['listings_count'] 
          : json['listings_count'] != null 
            ? int.tryParse(json['listings_count'].toString()) 
            : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'image': image,
      'is_active': isActive,
      'parent_id': parentId,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'listings_count': listingsCount,
    };
  }
  
  // Helper getters
  bool get hasParent => parentId != null;
  bool get hasChildren => children.isNotEmpty;
  bool get isParent => parentId == null;
  
  String get displayListingsCount {
    if (listingsCount == null) return '';
    return listingsCount == 1 ? '1 item' : '$listingsCount items';
  }
  
  String get fullImagePath {
    if (image == null || image!.isEmpty) return '';
    if (image!.startsWith('http')) return image!;
    // Import AppConstants from core package instead
    return '${AppConstants.storageUrl}/$image';
  }
  
  IconData get iconData {
    // Map Laravel FontAwesome icon names to Flutter Icons
    final iconMap = {
      'car': Icons.directions_car,
      'laptop': Icons.laptop,
      'mobile-alt': Icons.phone_android,
      'mobile': Icons.phone_android,
      'couch': Icons.chair,
      'tshirt': Icons.checkroom,
      'blender': Icons.kitchen,
      'futbol': Icons.sports_soccer,
      'baby-carriage': Icons.child_friendly,
      'gem': Icons.diamond,
      'book': Icons.menu_book,
      'pills': Icons.medical_services,
      'gamepad': Icons.videogame_asset,
      'home': Icons.home,
      'store': Icons.store,
      'shop': Icons.store,
      'tag': Icons.local_offer,
      'shopping-cart': Icons.shopping_cart,
      'cart': Icons.shopping_cart,
      'gift': Icons.card_giftcard,
      'star': Icons.star,
      'fire': Icons.local_fire_department,
      'plane': Icons.airplanemode_active,
      'map-marker-alt': Icons.location_on,
      'location': Icons.location_on,
      'briefcase': Icons.business_center,
      'tools': Icons.build,
      'question-circle': Icons.help,
      'help': Icons.help,
      'comments': Icons.comment,
      'comment': Icons.comment,
      'info-circle': Icons.info,
      'info': Icons.info,
      'envelope': Icons.email,
      'email': Icons.email,
      'th-large': Icons.grid_view,
      'grid': Icons.grid_view,
      'search': Icons.search,
      'user': Icons.person,
      'person': Icons.person,
      'heart': Icons.favorite,
      'favorite': Icons.favorite,
      'category': Icons.category,
      'folder': Icons.folder,
      'bag': Icons.shopping_bag,
      'shopping-bag': Icons.shopping_bag,
      'electronics': Icons.electrical_services,
      'fashion': Icons.checkroom,
      'kitchen': Icons.kitchen,
      'sports': Icons.sports_soccer,
      'baby': Icons.child_friendly,
      'books': Icons.menu_book,
      'health': Icons.medical_services,
      'games': Icons.videogame_asset,
    };
    
    if (icon == null || icon!.isEmpty) return Icons.category;
    return iconMap[icon!.toLowerCase().replaceAll('fa-', '')] ?? Icons.category;
  }
}

// Service Category model for Jobs & Services (mapped to service_categories table)
class ServiceCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? image;
  final int? parentId;
  final String type; // job, service
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.image,
    this.parentId,
    required this.type,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });
  
  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    // Parse dates safely
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }
    
    return ServiceCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Category',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      image: json['image']?.toString(),
      parentId: json['parent_id'] is int 
          ? json['parent_id'] 
          : json['parent_id'] != null 
            ? int.tryParse(json['parent_id'].toString()) 
            : null,
      type: json['type']?.toString() ?? 'job',
      isActive: json['is_active'] == true || 
                json['is_active'] == 1 || 
                json['is_active'] == '1' ||
                json['is_active'] == null,
      sortOrder: json['sort_order'] is int 
          ? json['sort_order'] 
          : int.tryParse(json['sort_order'].toString()) ?? 0,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }
  
  bool get isJobCategory => type == 'job';
  bool get isServiceCategory => type == 'service';
  
  String get fullImagePath {
    if (image == null || image!.isEmpty) return '';
    if (image!.startsWith('http')) return image!;
    // Import AppConstants from core package instead
    return '${AppConstants.storageUrl}/$image';
  }
}