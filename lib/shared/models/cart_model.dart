// lib/shared/models/cart_model.dart
// Cart model mapped 1:1 with Laravel carts table

import 'listing_model.dart';

class CartModel {
  final int id;
  final int? userId;
  final String? sessionId;
  final List<CartItemModel> items;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  CartModel({
    required this.id,
    this.userId,
    this.sessionId,
    this.items = const [],
    this.subtotal = 0.0,
    this.shipping = 0.0,
    this.tax = 0.0,
    this.total = 0.0,
    this.createdAt,
    this.updatedAt,
  });
  
  factory CartModel.fromJson(Map<String, dynamic> json) {
    List<CartItemModel> cartItems = [];
    
    final itemsData = json['items'];
    if (itemsData is List) {
      cartItems = itemsData
          .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    
    return CartModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      sessionId: json['session_id'] as String?,
      items: cartItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shipping: (json['shipping'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  
  String get formattedSubtotal => 'UGX ${subtotal.toStringAsFixed(0)}';
  String get formattedShipping => 'UGX ${shipping.toStringAsFixed(0)}';
  String get formattedTax => 'UGX ${tax.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
}

class CartItemModel {
  final int listingId;
  final String title;
  final String? image;
  final String? vendorName;
  final double unitPrice;
  final int quantity;
  final double total;
  final double? weightKg;
  final String? origin;
  final int stock;
  final int? variantId;
  final String? color;
  final String? size;
  final ListingModel? listing;
  
  CartItemModel({
    required this.listingId,
    required this.title,
    this.image,
    this.vendorName,
    required this.unitPrice,
    required this.quantity,
    required this.total,
    this.weightKg,
    this.origin,
    this.stock = 0,
    this.variantId,
    this.color,
    this.size,
    this.listing,
  });
  
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      listingId: json['listing_id'] as int,
      title: json['title'] as String? ?? '',
      image: json['image'] as String?,
      vendorName: json['vendor_name'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      origin: json['origin'] as String?,
      stock: json['stock'] as int? ?? 0,
      variantId: json['variant_id'] as int?,
      color: json['color'] as String?,
      size: json['size'] as String?,
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'])
          : null,
    );
  }
  
  String get formattedUnitPrice => 'UGX ${unitPrice.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
  bool get hasVariant => variantId != null || color != null || size != null;
  
  String? get variantDisplay {
    final parts = <String>[];
    if (color != null) parts.add(color!);
    if (size != null) parts.add(size!);
    return parts.isNotEmpty ? parts.join(' / ') : null;
  }
}

class WishlistModel {
  final int id;
  final int userId;
  final int listingId;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final ListingModel? listing;
  
  WishlistModel({
    required this.id,
    required this.userId,
    required this.listingId,
    this.meta,
    this.createdAt,
    this.listing,
  });
  
  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      listingId: json['listing_id'] as int,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'])
          : null,
    );
  }
}
