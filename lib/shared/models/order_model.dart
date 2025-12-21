// lib/shared/models/order_model.dart
// Order model mapped 1:1 with Laravel orders table

import 'user_model.dart';
import 'listing_model.dart';

class OrderModel {
  final int id;
  final String orderNumber;
  final int buyerId;
  final int vendorProfileId;
  final String status;
  final DateTime? confirmedAt;
  final DateTime? processingAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final double subtotal;
  final double shipping;
  final double taxes;
  final double platformCommission;
  final double total;
  final int? deliveryTimeDays;
  final int? processingTimeHours;
  final double? deliveryScore;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Relationships
  final UserModel? buyer;
  final VendorProfileModel? vendorProfile;
  final List<OrderItemModel> items;
  final List<PaymentModel>? payments;
  final EscrowModel? escrow;
  
  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.vendorProfileId,
    required this.status,
    this.confirmedAt,
    this.processingAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancelledAt,
    required this.subtotal,
    required this.shipping,
    required this.taxes,
    required this.platformCommission,
    required this.total,
    this.deliveryTimeDays,
    this.processingTimeHours,
    this.deliveryScore,
    this.meta,
    DateTime? createdAt,
    this.updatedAt,
    this.buyer,
    this.vendorProfile,
    this.items = const [],
    this.payments,
    this.escrow,
  }) : createdAt = createdAt ?? DateTime.now();
  
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final order = OrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      buyerId: json['buyer_id'] is int ? json['buyer_id'] : int.tryParse(json['buyer_id'].toString()) ?? 0,
      vendorProfileId: json['vendor_profile_id'] is int ? json['vendor_profile_id'] : int.tryParse(json['vendor_profile_id'].toString()) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at'].toString()) : null,
      processingAt: json['processing_at'] != null ? DateTime.tryParse(json['processing_at'].toString()) : null,
      shippedAt: json['shipped_at'] != null ? DateTime.tryParse(json['shipped_at'].toString()) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'].toString()) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      subtotal: json['subtotal'] is num ? json['subtotal'].toDouble() : double.tryParse(json['subtotal'].toString()) ?? 0.0,
      shipping: json['shipping'] is num ? json['shipping'].toDouble() : double.tryParse(json['shipping'].toString()) ?? 0.0,
      taxes: json['taxes'] is num ? json['taxes'].toDouble() : double.tryParse(json['taxes'].toString()) ?? 0.0,
      platformCommission: json['platform_commission'] is num ? json['platform_commission'].toDouble() : double.tryParse(json['platform_commission'].toString()) ?? 0.0,
      total: json['total'] is num ? json['total'].toDouble() : double.tryParse(json['total'].toString()) ?? 0.0,
      deliveryTimeDays: json['delivery_time_days'] is int ? json['delivery_time_days'] : int.tryParse(json['delivery_time_days']?.toString() ?? ''),
      processingTimeHours: json['processing_time_hours'] is int ? json['processing_time_hours'] : int.tryParse(json['processing_time_hours']?.toString() ?? ''),
      deliveryScore: json['delivery_score'] is num ? json['delivery_score'].toDouble() : double.tryParse(json['delivery_score']?.toString() ?? ''),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : (json['meta'] is String ? null : null),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      buyer: json['buyer'] != null && json['buyer'] is Map<String, dynamic> ? UserModel.fromJson(json['buyer']) : null,
      vendorProfile: json['vendor_profile'] != null && json['vendor_profile'] is Map<String, dynamic> ? VendorProfileModel.fromJson(json['vendor_profile']) : null,
      items: (json['items'] as List<dynamic>?)?.map((e) => OrderItemModel.fromJson(e)).toList() ?? [],
      payments: (json['payments'] as List<dynamic>?)?.map((e) => PaymentModel.fromJson(e)).toList(),
      escrow: json['escrow'] != null && json['escrow'] is Map<String, dynamic> ? EscrowModel.fromJson(json['escrow']) : null,
    );
    // Parse items_count from API if available
    if (json['items_count'] != null) {
      order._itemsCountFromApi = json['items_count'] is int
          ? json['items_count']
          : int.tryParse(json['items_count'].toString());
    }
    return order;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'buyer_id': buyerId,
      'vendor_profile_id': vendorProfileId,
      'status': status,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'processing_at': processingAt?.toIso8601String(),
      'shipped_at': shippedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'subtotal': subtotal,
      'shipping': shipping,
      'taxes': taxes,
      'platform_commission': platformCommission,
      'total': total,
      'delivery_time_days': deliveryTimeDays,
      'processing_time_hours': processingTimeHours,
      'delivery_score': deliveryScore,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  // Status check methods
  bool get isPending => status == 'pending';
  bool get isPaymentPending => status == 'payment_pending';
  bool get isPaid => status == 'paid';
  bool get isProcessing => status == 'processing';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  
  bool get canBeCancelled => ['pending', 'payment_pending'].contains(status) && cancelledAt == null;
  bool get canBeDelivered => ['processing', 'shipped'].contains(status) && deliveredAt == null;
  bool get canBeShipped => ['paid', 'processing'].contains(status) && shippedAt == null;
  bool get canBeProcessing => ['paid', 'confirmed'].contains(status) && processingAt == null;
  
  // Shipping address from meta
  ShippingAddressInfo? get shippingAddress {
    if (meta == null) return null;
    final addressData = meta!['shipping_address'];
    if (addressData is Map<String, dynamic>) {
      return ShippingAddressInfo.fromJson(addressData);
    }
    return null;
  }
  
  String? get paymentMethod => meta?['payment_method'] as String?;
  bool get isCashOnDelivery => paymentMethod == 'cash_on_delivery';
  bool get canBuyerConfirmDelivery => isCashOnDelivery && status == 'shipped' && deliveredAt == null;
  
  // Formatted prices (without currency prefix for flexible use)
  String get subtotalFormatted => _formatNumber(subtotal);
  String get shippingFormatted => _formatNumber(shipping);
  String get taxesFormatted => _formatNumber(taxes);
  String get totalFormatted => _formatNumber(total);

  // Helper to format numbers with thousand separators
  String _formatNumber(double value) {
    final intValue = value.toInt();
    return intValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // Computed properties - check items_count from API first, then fall back to items.length
  int? _itemsCountFromApi;
  int get itemsCount => _itemsCountFromApi ?? items.length;
  String get createdAtFormatted => createdAt != null 
      ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
      : 'N/A';

    // Compatibility helpers
    String? get paymentStatus => meta?['payment_status'] as String? ?? meta?['paymentStatus'] as String?;
    double get shippingCost => shipping;
  
  // Vendor alias for consistency
  VendorProfileModel? get vendor => vendorProfile;
  
  // Status display
  String get statusDisplay {
    switch (status) {
      case 'pending': return 'Pending';
      case 'payment_pending': return 'Payment Pending';
      case 'paid': return 'Paid';
      case 'processing': return 'Processing';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status.toUpperCase();
    }
  }
}

// Order Item model
class OrderItemModel {
  final int id;
  final int orderId;
  final int listingId;
  final int? variantId;
  final int quantity;
  final double unitPrice;
  final double total;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ListingModel? listing;
  
  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.listingId,
    this.variantId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.meta,
    this.createdAt,
    this.updatedAt,
    this.listing,
  });
  
  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderId: json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id'].toString()) ?? 0,
      listingId: json['listing_id'] is int ? json['listing_id'] : int.tryParse(json['listing_id'].toString()) ?? 0,
      variantId: json['variant_id'] is int ? json['variant_id'] : int.tryParse(json['variant_id']?.toString() ?? ''),
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity'].toString()) ?? 0,
      unitPrice: json['unit_price'] is num ? json['unit_price'].toDouble() : double.tryParse(json['unit_price'].toString()) ?? 0.0,
      total: json['total'] is num ? json['total'].toDouble() : (json['line_total'] is num ? json['line_total'].toDouble() : double.tryParse(json['total']?.toString() ?? '') ?? 0.0),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      listing: json['listing'] != null && json['listing'] is Map<String, dynamic> ? ListingModel.fromJson(json['listing']) : null,
    );
  }
  
  String? get color => meta?['color'] as String?;
  String? get size => meta?['size'] as String?;
  String get formattedUnitPrice => 'UGX ${unitPrice.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
  
  // Image URL from listing
  String? get imageUrl {
    // Prefer explicit image/thumbnail in meta if provided by API
    if (meta != null) {
      final m = meta!;
      if (m['thumbnail'] != null && m['thumbnail'].toString().isNotEmpty) return m['thumbnail'].toString();
      if (m['image'] != null && m['image'].toString().isNotEmpty) return m['image'].toString();
      if (m['image_url'] != null && m['image_url'].toString().isNotEmpty) return m['image_url'].toString();
      if (m['thumbnail_path'] != null && m['thumbnail_path'].toString().isNotEmpty) return m['thumbnail_path'].toString();
    }

    // Fall back to listing images when available
    if (listing?.images.isNotEmpty == true) return listing!.images.first.fullPath;

    // No image available
    return null;
  }
  
  // Title from listing
  String get title => listing?.title ?? 'Product';

  // Compatibility helpers expected by UI
  dynamic get variant => meta?['variant'];
  double get price => unitPrice;
}

// Payment model
class PaymentModel {
  final int id;
  final int orderId;
  final String? transactionId;
  final String provider;
  final String method;
  final double amount;
  final String currency;
  final String status;
  final Map<String, dynamic>? meta;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  PaymentModel({
    required this.id,
    required this.orderId,
    this.transactionId,
    required this.provider,
    required this.method,
    required this.amount,
    this.currency = 'UGX',
    required this.status,
    this.meta,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });
  
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderId: json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id'].toString()) ?? 0,
      transactionId: json['transaction_id']?.toString(),
      provider: json['provider']?.toString() ?? '',
      method: json['method']?.toString() ?? json['payment_method']?.toString() ?? '',
      amount: json['amount'] is num ? json['amount'].toDouble() : double.tryParse(json['amount'].toString()) ?? 0.0,
      currency: json['currency']?.toString() ?? 'UGX',
      status: json['status']?.toString() ?? 'pending',
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
  
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}

// Escrow model
class EscrowModel {
  final int id;
  final int orderId;
  final double amount;
  final String status;
  final DateTime? releaseAt;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  EscrowModel({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.status,
    this.releaseAt,
    this.meta,
    this.createdAt,
    this.updatedAt,
  });
  
  factory EscrowModel.fromJson(Map<String, dynamic> json) {
    return EscrowModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderId: json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id'].toString()) ?? 0,
      amount: json['amount'] is num ? json['amount'].toDouble() : double.tryParse(json['amount'].toString()) ?? 0.0,
      status: json['status']?.toString() ?? 'held',
      releaseAt: json['release_at'] != null ? DateTime.tryParse(json['release_at'].toString()) : null,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
  
  bool get isHeld => status == 'held';
  bool get isReleased => status == 'released';
  bool get isRefunded => status == 'refunded';
}

// Shipping address info from order meta
class ShippingAddressInfo {
  final String? label;
  final String recipientName;
  final String recipientPhone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? stateRegion;
  final String? postalCode;
  final String country;
  final String? deliveryInstructions;
  final String fullAddress;
  
  ShippingAddressInfo({
    this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.stateRegion,
    this.postalCode,
    this.country = 'Uganda',
    this.deliveryInstructions,
    this.fullAddress = '',
  });
  
  factory ShippingAddressInfo.fromJson(Map<String, dynamic> json) {
    return ShippingAddressInfo(
      label: json['label']?.toString(),
      recipientName: json['recipient_name']?.toString() ?? 'N/A',
      recipientPhone: json['recipient_phone']?.toString() ?? 'N/A',
      addressLine1: json['address_line_1']?.toString() ?? 'N/A',
      addressLine2: json['address_line_2']?.toString(),
      city: json['city']?.toString() ?? 'N/A',
      stateRegion: json['state_region']?.toString(),
      postalCode: json['postal_code']?.toString(),
      country: json['country']?.toString() ?? 'Uganda',
      deliveryInstructions: json['delivery_instructions']?.toString(),
      fullAddress: json['full_address']?.toString() ?? '',
    );
  }
  
  String get displayAddress {
    if (fullAddress.isNotEmpty) {
      return fullAddress;
    }
    final parts = <String>[addressLine1];
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    parts.add(city);
    if (stateRegion != null && stateRegion!.isNotEmpty) {
      parts.add(stateRegion!);
    }
    parts.add(country);
    return parts.join(', ');
  }

  // Compatibility getters expected by UI
  String? get fullName => recipientName;
  String? get phone => recipientPhone;
}