// lib/shared/models/order_model.dart
// Order model mapped 1:1 with Laravel orders table

import 'user_model.dart';
import 'listing_model.dart';

class OrderModel {
  final int id;
  final String orderNumber;
  final int buyerId;
  final int vendorProfileId;
  final String status; // pending, payment_pending, paid, processing, shipped, delivered, cancelled
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
  final DateTime? createdAt;
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
    this.createdAt,
    this.updatedAt,
    this.buyer,
    this.vendorProfile,
    this.items = const [],
    this.payments,
    this.escrow,
  });
  
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      buyerId: json['buyer_id'] as int,
      vendorProfileId: json['vendor_profile_id'] as int,
      status: json['status'] as String,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
      processingAt: json['processing_at'] != null
          ? DateTime.parse(json['processing_at'])
          : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.parse(json['shipped_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      subtotal: (json['subtotal'] as num).toDouble(),
      shipping: (json['shipping'] as num).toDouble(),
      taxes: (json['taxes'] as num).toDouble(),
      platformCommission: (json['platform_commission'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      deliveryTimeDays: json['delivery_time_days'] as int?,
      processingTimeHours: json['processing_time_hours'] as int?,
      deliveryScore: (json['delivery_score'] as num?)?.toDouble(),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      buyer: json['buyer'] != null
          ? UserModel.fromJson(json['buyer'])
          : null,
      vendorProfile: json['vendor_profile'] != null
          ? VendorProfileModel.fromJson(json['vendor_profile'])
          : null,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItemModel.fromJson(e))
          .toList() ?? [],
      payments: (json['payments'] as List<dynamic>?)
          ?.map((e) => PaymentModel.fromJson(e))
          .toList(),
      escrow: json['escrow'] != null
          ? EscrowModel.fromJson(json['escrow'])
          : null,
    );
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  // Status check methods matching Laravel Order model
  bool get isPending => status == 'pending';
  bool get isPaymentPending => status == 'payment_pending';
  bool get isPaid => status == 'paid';
  bool get isProcessing => status == 'processing';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  
  bool get canBeCancelled => 
      ['pending', 'payment_pending'].contains(status) && cancelledAt == null;
  
  bool get canBeDelivered => 
      ['processing', 'shipped'].contains(status) && deliveredAt == null;
  
  bool get canBeShipped => 
      ['paid', 'processing'].contains(status) && shippedAt == null;
  
  bool get canBeProcessing => 
      ['paid', 'confirmed'].contains(status) && processingAt == null;
  
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
  
  // For COD orders, only buyer can confirm delivery
  bool get canBuyerConfirmDelivery => 
      isCashOnDelivery && status == 'shipped' && deliveredAt == null;
  
  // Formatted prices
  String get formattedSubtotal => 'UGX ${subtotal.toStringAsFixed(0)}';
  String get formattedShipping => 'UGX ${shipping.toStringAsFixed(0)}';
  String get formattedTaxes => 'UGX ${taxes.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
  
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
      default: return status;
    }
  }
  
  // Delivery timeline matching Laravel getDeliveryTimeline()
  List<DeliveryTimelineStep> get deliveryTimeline {
    return [
      DeliveryTimelineStep(
        title: 'Order Placed',
        date: createdAt,
        completed: true,
      ),
      DeliveryTimelineStep(
        title: 'Confirmed',
        date: confirmedAt,
        completed: confirmedAt != null,
      ),
      DeliveryTimelineStep(
        title: 'Processing',
        date: processingAt,
        completed: processingAt != null,
      ),
      DeliveryTimelineStep(
        title: 'Shipped',
        date: shippedAt,
        completed: shippedAt != null,
      ),
      DeliveryTimelineStep(
        title: 'Delivered',
        date: deliveredAt,
        completed: deliveredAt != null,
      ),
    ];
  }
  
  // Delivery performance badge matching Laravel getDeliveryPerformanceBadge()
  DeliveryBadge? get deliveryPerformanceBadge {
    if (deliveryScore == null) return null;
    
    final score = deliveryScore!;
    if (score >= 90) {
      return DeliveryBadge('Excellent Delivery', 'green', 'rocket');
    } else if (score >= 80) {
      return DeliveryBadge('Fast Delivery', 'blue', 'bolt');
    } else if (score >= 70) {
      return DeliveryBadge('Good Delivery', 'yellow', 'check_circle');
    } else if (score >= 60) {
      return DeliveryBadge('Average Delivery', 'orange', 'clock');
    } else {
      return DeliveryBadge('Slow Delivery', 'red', 'warning');
    }
  }
}

// Order Item model mapped to order_items table
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
  
  // Relationships
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
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      listingId: json['listing_id'] as int,
      variantId: json['variant_id'] as int?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'])
          : null,
    );
  }
  
  String? get color => meta?['color'] as String?;
  String? get size => meta?['size'] as String?;
  
  String get formattedUnitPrice => 'UGX ${unitPrice.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
}

// Payment model mapped to payments table
class PaymentModel {
  final int id;
  final int orderId;
  final String? paymentMethod;
  final String? provider;
  final String? transactionId;
  final double amount;
  final String status; // pending, completed, failed, refunded
  final String? errorMessage;
  final Map<String, dynamic>? meta;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  PaymentModel({
    required this.id,
    required this.orderId,
    this.paymentMethod,
    this.provider,
    this.transactionId,
    required this.amount,
    required this.status,
    this.errorMessage,
    this.meta,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });
  
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      paymentMethod: json['payment_method'] as String?,
      provider: json['provider'] as String?,
      transactionId: json['transaction_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}

// Escrow model mapped to escrows table
class EscrowModel {
  final int id;
  final int orderId;
  final double amount;
  final String status; // held, released, refunded
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
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      releaseAt: json['release_at'] != null
          ? DateTime.parse(json['release_at'])
          : null,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  bool get isHeld => status == 'held';
  bool get isReleased => status == 'released';
  bool get isRefunded => status == 'refunded';
}

// Helper classes
class ShippingAddressInfo {
  final String? label;
  final String? recipientName;
  final String? recipientPhone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? stateRegion;
  final String? postalCode;
  final String? country;
  final String? deliveryInstructions;
  final String? fullAddress;
  
  ShippingAddressInfo({
    this.label,
    this.recipientName,
    this.recipientPhone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.stateRegion,
    this.postalCode,
    this.country,
    this.deliveryInstructions,
    this.fullAddress,
  });
  
  factory ShippingAddressInfo.fromJson(Map<String, dynamic> json) {
    return ShippingAddressInfo(
      label: json['label'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String?,
      stateRegion: json['state_region'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      fullAddress: json['full_address'] as String?,
    );
  }
}

class DeliveryTimelineStep {
  final String title;
  final DateTime? date;
  final bool completed;
  
  DeliveryTimelineStep({
    required this.title,
    this.date,
    required this.completed,
  });
}

class DeliveryBadge {
  final String text;
  final String color;
  final String icon;
  
  DeliveryBadge(this.text, this.color, this.icon);
}.toStringAsFixed(0)}';
  String get formattedTaxes => 'UGX ${taxes.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
  
  // Status display
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'payment_pending':
        return 'Payment Pending';
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
  
  // Delivery timeline matching Laravel Order model
  Map<String, Map<String, dynamic>> get deliveryTimeline {
    return {
      'ordered': {
        'date': createdAt,
        'completed': true,
      },
      'confirmed': {
        'date': confirmedAt,
        'completed': confirmedAt != null,
      },
      'processing': {
        'date': processingAt,
        'completed': processingAt != null,
      },
      'shipped': {
        'date': shippedAt,
        'completed': shippedAt != null,
      },
      'delivered': {
        'date': deliveredAt,
        'completed': deliveredAt != null,
      },
    };
  }
  
  // Delivery performance badge matching Laravel
  Map<String, dynamic>? get deliveryPerformanceBadge {
    if (deliveryScore == null) return null;
    
    if (deliveryScore! >= 90) {
      return {'color': 'green', 'text': 'Excellent Delivery', 'icon': 'rocket'};
    } else if (deliveryScore! >= 80) {
      return {'color': 'blue', 'text': 'Fast Delivery', 'icon': 'bolt'};
    } else if (deliveryScore! >= 70) {
      return {'color': 'yellow', 'text': 'Good Delivery', 'icon': 'check_circle'};
    } else if (deliveryScore! >= 60) {
      return {'color': 'orange', 'text': 'Average Delivery', 'icon': 'clock'};
    } else {
      return {'color': 'red', 'text': 'Slow Delivery', 'icon': 'warning'};
    }
  }
}

// OrderItem model mapped to order_items table
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
  
  // Relationship
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
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      listingId: json['listing_id'] as int,
      variantId: json['variant_id'] as int?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'])
          : null,
    );
  }
  
  String? get color => meta?['color'] as String?;
  String? get size => meta?['size'] as String?;
  
  String get formattedUnitPrice => 'UGX ${unitPrice.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
}

// Payment model mapped to payments table
class PaymentModel {
  final int id;
  final int orderId;
  final String? transactionId;
  final String provider; // flutterwave, pesapal, wallet, cod
  final String method; // card, mobile_money, bank_transfer, wallet, cash
  final double amount;
  final String currency;
  final String status; // pending, processing, completed, failed, refunded
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
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      transactionId: json['transaction_id'] as String?,
      provider: json['provider'] as String,
      method: json['method'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'UGX',
      status: json['status'] as String,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}

// Escrow model mapped to escrows table
class EscrowModel {
  final int id;
  final int orderId;
  final double amount;
  final String status; // held, released, refunded
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
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      releaseAt: json['release_at'] != null
          ? DateTime.parse(json['release_at'])
          : null,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
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
  final String? fullAddress;
  
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
    this.fullAddress,
  });
  
  factory ShippingAddressInfo.fromJson(Map<String, dynamic> json) {
    return ShippingAddressInfo(
      label: json['label'] as String?,
      recipientName: json['recipient_name'] as String? ?? 'N/A',
      recipientPhone: json['recipient_phone'] as String? ?? 'N/A',
      addressLine1: json['address_line_1'] as String? ?? 'N/A',
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String? ?? 'N/A',
      stateRegion: json['state_region'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'Uganda',
      deliveryInstructions: json['delivery_instructions'] as String?,
      fullAddress: json['full_address'] as String?,
    );
  }
  
  String get displayAddress {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      return fullAddress!;
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
}
