// lib/shared/models/listing_model.dart
// Listing model mapped 1:1 with Laravel listings table

import 'dart:core';
import 'package:intl/intl.dart';
import 'user_model.dart';
import 'category_model.dart';
import 'package:bebamart/core/constants/app_constants.dart';

class ListingModel {
  final int id;
  final int vendorProfileId;
  final String title;
  final String? description;
  final String? sku;
  final double price;
  final double? weightKg;
  final String? origin;
  final String? condition;
  final int? categoryId;
  final int stock;
  final Map<String, dynamic>? attributes;
  final bool isActive;
  final int viewCount;
  final int clickCount;
  final int wishlistCount;
  final int cartAddCount;
  final int purchaseCount;
  final int shareCount;
  final DateTime? lastViewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Relationships
  final VendorProfileModel? vendor;
  final CategoryModel? category;
  final List<ListingImageModel> images;
  final List<ListingVariantModel> variants;
  final List<ReviewModel>? reviews;
  
  // Computed properties from Laravel
  final double? averageRating;
  final int? reviewsCount;

  // Subscription ranking fields
  final double? rankingScore;
  final double boostMultiplier;

  // Add this getter to fix the rating error
  double get rating => averageRating ?? 0.0;
  
  ListingModel({
    required this.id,
    required this.vendorProfileId,
    required this.title,
    this.description,
    this.sku,
    required this.price,
    this.weightKg,
    this.origin,
    this.condition,
    this.categoryId,
    this.stock = 0,
    this.attributes,
    this.isActive = true,
    this.viewCount = 0,
    this.clickCount = 0,
    this.wishlistCount = 0,
    this.cartAddCount = 0,
    this.purchaseCount = 0,
    this.shareCount = 0,
    this.lastViewedAt,
    this.createdAt,
    this.updatedAt,
    this.vendor,
    this.category,
    this.images = const [],
    this.variants = const [],
    this.reviews,
    this.averageRating,
    this.reviewsCount,
    this.rankingScore,
    this.boostMultiplier = 1.0,
  });
  
  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Parse images
    List<ListingImageModel> images = [];
    if (json['images'] != null && json['images'] is List) {
      images = (json['images'] as List)
          .whereType<Map<String, dynamic>>()
          .map((img) => ListingImageModel.fromJson(img))
          .toList();
    }
    
    // Parse variants
    List<ListingVariantModel> variants = [];
    if (json['variants'] != null && json['variants'] is List) {
      variants = (json['variants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((variant) => ListingVariantModel.fromJson(variant))
          .toList();
    }
    
    // Parse reviews
    List<ReviewModel>? reviews;
    if (json['reviews'] != null && json['reviews'] is List) {
      reviews = (json['reviews'] as List)
          .whereType<Map<String, dynamic>>()
          .map((review) => ReviewModel.fromJson(review))
          .toList();
    }
    
    // Parse vendor
    VendorProfileModel? vendor;
    if (json['vendor'] != null && json['vendor'] is Map<String, dynamic>) {
      vendor = VendorProfileModel.fromJson(json['vendor']);
    }
    
    // Parse category
    CategoryModel? category;
    if (json['category'] != null && json['category'] is Map<String, dynamic>) {
      category = CategoryModel.fromJson(json['category']);
    }
    
    return ListingModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorProfileId: json['vendor_profile_id'] is int 
          ? json['vendor_profile_id'] 
          : int.tryParse(json['vendor_profile_id']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? 'Unknown Product',
      description: json['description']?.toString(),
      sku: json['sku']?.toString(),
      price: json['price'] is String ? double.tryParse(json['price']) ?? 0.0 : (json['price'] is num ? json['price'].toDouble() : 0.0),
      weightKg: json['weight_kg'] is num ? json['weight_kg'].toDouble() : null,
      origin: json['origin']?.toString(),
      condition: json['condition']?.toString(),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : json['category_id'] != null
            ? int.tryParse(json['category_id']?.toString() ?? '0')
            : (json['category'] != null && json['category'] is Map && json['category']['id'] != null)
              ? (json['category']['id'] is int ? json['category']['id'] : int.tryParse(json['category']['id'].toString()))
              : null,
      stock: json['stock'] is int ? json['stock'] : int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      attributes: json['attributes'] is Map<String, dynamic> 
          ? Map<String, dynamic>.from(json['attributes']) 
          : null,
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      viewCount: json['view_count'] is int ? json['view_count'] : int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      clickCount: json['click_count'] is int ? json['click_count'] : int.tryParse(json['click_count']?.toString() ?? '0') ?? 0,
      wishlistCount: json['wishlist_count'] is int ? json['wishlist_count'] : int.tryParse(json['wishlist_count']?.toString() ?? '0') ?? 0,
      cartAddCount: json['cart_add_count'] is int ? json['cart_add_count'] : int.tryParse(json['cart_add_count']?.toString() ?? '0') ?? 0,
      purchaseCount: json['purchase_count'] is int ? json['purchase_count'] : int.tryParse(json['purchase_count']?.toString() ?? '0') ?? 0,
      shareCount: json['share_count'] is int ? json['share_count'] : int.tryParse(json['share_count']?.toString() ?? '0') ?? 0,
      lastViewedAt: json['last_viewed_at'] != null
          ? DateTime.tryParse(json['last_viewed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      vendor: vendor,
      category: category,
      images: images,
      variants: variants,
      reviews: reviews,
      averageRating: json['average_rating'] is num
          ? json['average_rating'].toDouble()
          : json['rating'] is num
            ? json['rating'].toDouble()
            : 0.0,
      reviewsCount: json['reviews_count'] is int
          ? json['reviews_count']
          : json['reviews_count'] != null
            ? int.tryParse(json['reviews_count']?.toString() ?? '0')
            : 0,
      rankingScore: json['ranking_score'] is num
          ? json['ranking_score'].toDouble()
          : null,
      boostMultiplier: json['boost_multiplier'] is num
          ? json['boost_multiplier'].toDouble()
          : (json['is_promoted'] == true ? 1.5 : 1.0),
    );
  }

  /// Whether this listing is from a paid subscriber (promoted)
  bool get isPromoted => boostMultiplier > 1.0;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_profile_id': vendorProfileId,
      'title': title,
      'description': description,
      'sku': sku,
      'price': price,
      'weight_kg': weightKg,
      'origin': origin,
      'condition': condition,
      'category_id': categoryId,
      'stock': stock,
      'attributes': attributes,
      'is_active': isActive,
      'view_count': viewCount,
      'click_count': clickCount,
      'wishlist_count': wishlistCount,
      'cart_add_count': cartAddCount,
      'purchase_count': purchaseCount,
      'share_count': shareCount,
      'last_viewed_at': lastViewedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'rating': averageRating, // Add this for API compatibility
    };
  }
  
  // Computed properties matching Laravel model
  bool get hasVariations => variants.where((v) => v.stock > 0).isNotEmpty;
  
  List<String> get availableColors => variants
      .where((v) => v.stock > 0)
      .map((v) => v.color)
      .where((c) => c != null && c.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  
  List<String> get availableSizes => variants
      .where((v) => v.stock > 0)
      .map((v) => v.size)
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  
  String? get primaryImage {
    if (images.isNotEmpty) {
      return images.first.fullPath;
    }
    return null;
  }
  
  String? get thumbnail {
    if (images.isNotEmpty) {
      return images.first.fullPath;
    }
    return null;
  }
  
  double get displayRating => averageRating ?? 0.0;
  
  int get displayReviewsCount => reviewsCount ?? 0;

  // Backwards-compatible alias: some vendor UI expects `quantity`
  int get quantity => stock;

  bool get isInStock => stock > 0 || hasVariations;
  
  String get formattedPrice => 'UGX ${NumberFormat('#,##0', 'en_US').format(price)}';

  // Subscription helpers
  bool get vendorHasBadge => vendor?.hasSubscriptionBadge ?? false;
  String? get vendorBadgeText => vendor?.subscriptionBadgeText;
  bool get vendorIsPremium => vendor?.hasPaidSubscription ?? false;
  bool get isBoosted => boostMultiplier > 1.0;
  
  ListingVariantModel? findVariantByAttributes(String? color, String? size) {
    try {
      return variants.firstWhere(
        (v) {
          final colorMatch = color == null || v.color == color;
          final sizeMatch = size == null || v.size == size;
          return colorMatch && sizeMatch && v.stock > 0;
        },
      );
    } catch (e) {
      return null;
    }
  }
  
  ListingVariantModel? get defaultVariant {
    final defaultVariants = variants.where((v) => v.isDefault && v.stock > 0);
    if (defaultVariants.isNotEmpty) return defaultVariants.first;
    final availableVariants = variants.where((v) => v.stock > 0);
    return availableVariants.isNotEmpty ? availableVariants.first : null;
  }
}

// ListingImage model mapped to listing_images table
class ListingImageModel {
  final int id;
  final int listingId;
  final String path;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  ListingImageModel({
    required this.id,
    required this.listingId,
    required this.path,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });
  
  factory ListingImageModel.fromJson(Map<String, dynamic> json) {
    return ListingImageModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      listingId: json['listing_id'] is int ? json['listing_id'] : int.tryParse(json['listing_id']?.toString() ?? '0') ?? 0,
      path: json['path']?.toString() ?? '',
      sortOrder: json['sort_order'] is int ? json['sort_order'] : json['order'] is int ? json['order'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
  
  // Get full URL for image
  String get fullPath {
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) {
      return '${AppConstants.storageUrl}$path';
    }
    return '${AppConstants.storageUrl}/$path';
  }
}

// ListingVariant model mapped to listing_variants table
class ListingVariantModel {
  final int id;
  final int listingId;
  final String? sku;
  final double price;
  final double? displayPrice;
  final int stock;
  final Map<String, dynamic>? attributes;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  ListingVariantModel({
    required this.id,
    required this.listingId,
    this.sku,
    required this.price,
    this.displayPrice,
    this.stock = 0,
    this.attributes,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });
  
  factory ListingVariantModel.fromJson(Map<String, dynamic> json) {
    return ListingVariantModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      listingId: json['listing_id'] is int ? json['listing_id'] : int.tryParse(json['listing_id']?.toString() ?? '0') ?? 0,
      sku: json['sku']?.toString(),
      price: json['price'] is String ? double.tryParse(json['price']) ?? 0.0 : (json['price'] is num ? json['price'].toDouble() : 0.0),
      displayPrice: json['display_price'] is num ? json['display_price'].toDouble() : null,
      stock: json['stock'] is int ? json['stock'] : int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      attributes: json['attributes'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['attributes'])
          : null,
      isDefault: json['is_default'] == true || json['is_default'] == 1 || json['is_default'] == '1',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
  
  String? get color {
    if (attributes == null) return null;
    if (attributes!.containsKey('color')) return attributes!['color']?.toString();
    if (attributes!.containsKey('Color')) return attributes!['Color']?.toString();
    if (attributes!.containsKey('COLOR')) return attributes!['COLOR']?.toString();
    return null;
  }
  
  String? get size {
    if (attributes == null) return null;
    if (attributes!.containsKey('size')) return attributes!['size']?.toString();
    if (attributes!.containsKey('Size')) return attributes!['Size']?.toString();
    if (attributes!.containsKey('SIZE')) return attributes!['SIZE']?.toString();
    return null;
  }
  
  double get effectivePrice => displayPrice ?? price;
  
  String get formattedPrice => 'UGX ${NumberFormat('#,##0', 'en_US').format(effectivePrice)}';
  
  bool get inStock => stock > 0;
}

// Review model mapped to reviews table
class ReviewModel {
  final int id;
  final int userId;
  final int listingId;
  final int? orderId;
  final int rating;
  final String? title;
  final String? comment;
  final String status; // pending, approved, rejected
  final String? vendorResponse;
  final DateTime? vendorResponseAt;
  final int helpfulVotes;
  final int unhelpfulVotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Relationships
  final UserModel? user;
  final ListingModel? listing;
  
  ReviewModel({
    required this.id,
    required this.userId,
    required this.listingId,
    this.orderId,
    required this.rating,
    this.title,
    this.comment,
    this.status = 'pending',
    this.vendorResponse,
    this.vendorResponseAt,
    this.helpfulVotes = 0,
    this.unhelpfulVotes = 0,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.listing,
  });
  
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      listingId: json['listing_id'] is int ? json['listing_id'] : int.tryParse(json['listing_id']?.toString() ?? '0') ?? 0,
      orderId: json['order_id'] != null 
          ? (json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id']?.toString() ?? '0')) 
          : null,
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString(),
      comment: json['comment']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      vendorResponse: json['vendor_response']?.toString(),
      vendorResponseAt: json['vendor_response_at'] != null
          ? DateTime.tryParse(json['vendor_response_at'].toString())
          : null,
      helpfulVotes: json['helpful_votes'] is int ? json['helpful_votes'] : int.tryParse(json['helpful_votes']?.toString() ?? '0') ?? 0,
      unhelpfulVotes: json['unhelpful_votes'] is int ? json['unhelpful_votes'] : int.tryParse(json['unhelpful_votes']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      listing: json['listing'] != null && json['listing'] is Map<String, dynamic>
          ? ListingModel.fromJson(Map<String, dynamic>.from(json['listing']))
          : null,
    );
  }
  
  bool get isApproved => status == 'approved';
  bool get hasVendorResponse => vendorResponse != null && vendorResponse!.isNotEmpty;
}