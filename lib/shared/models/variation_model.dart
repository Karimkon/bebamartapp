// lib/shared/models/variation_model.dart
class VariationModel {
  final int id;
  final int listingId;
  final Map<String, dynamic> attributes;
  final double price;
  final double? displayPrice;
  final int stock;
  final String? sku;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VariationModel({
    required this.id,
    required this.listingId,
    required this.attributes,
    required this.price,
    this.displayPrice,
    required this.stock,
    this.sku,
    this.meta,
    this.createdAt,
    this.updatedAt,
  });

  factory VariationModel.fromJson(Map<String, dynamic> json) {
    return VariationModel(
      id: json['id'] ?? 0,
      listingId: json['listing_id'] ?? 0,
      attributes: json['attributes'] is Map<String, dynamic> ? json['attributes'] : {},
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
      displayPrice: (json['display_price'] is num) ? json['display_price'].toDouble() : null,
      stock: json['stock'] ?? 0,
      sku: json['sku'],
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'attributes': attributes,
      'price': price,
      'display_price': displayPrice,
      'stock': stock,
      'sku': sku,
      'meta': meta,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper getters for common attributes
  String? get color => attributes['color'] ?? attributes['Color'] ?? attributes['COLOR'];
  String? get size => attributes['size'] ?? attributes['Size'] ?? attributes['SIZE'];

  // Check if variation matches selected options
  bool matchesSelection({String? selectedColor, String? selectedSize}) {
    if (selectedColor != null && color != selectedColor) return false;
    if (selectedSize != null && size != selectedSize) return false;
    return true;
  }

  @override
  String toString() {
    return 'VariationModel(id: $id, attributes: $attributes, price: $price, stock: $stock)';
  }
}