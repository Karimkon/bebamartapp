// lib/shared/models/subscription_model.dart
// Subscription models mapped to Laravel subscription tables

import 'package:intl/intl.dart';

/// Subscription Plan model mapped to subscription_plans table
class SubscriptionPlanModel {
  final int id;
  final String name;
  final String slug;
  final double price;
  final String billingCycle;
  final double boostMultiplier;
  final int maxFeaturedListings;
  final bool badgeEnabled;
  final String? badgeText;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.billingCycle,
    required this.boostMultiplier,
    required this.maxFeaturedListings,
    required this.badgeEnabled,
    this.badgeText,
    required this.features,
    required this.isActive,
    required this.sortOrder,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    List<String> features = [];
    if (json['features'] != null) {
      if (json['features'] is List) {
        features = (json['features'] as List).map((e) => e.toString()).toList();
      }
    }

    return SubscriptionPlanModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      price: json['price'] is num ? json['price'].toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      boostMultiplier: json['boost_multiplier'] is num
          ? json['boost_multiplier'].toDouble()
          : double.tryParse(json['boost_multiplier']?.toString() ?? '1') ?? 1.0,
      maxFeaturedListings: json['max_featured_listings'] is int
          ? json['max_featured_listings']
          : int.tryParse(json['max_featured_listings']?.toString() ?? '0') ?? 0,
      badgeEnabled: json['badge_enabled'] == true || json['badge_enabled'] == 1,
      badgeText: json['badge_text']?.toString(),
      features: features,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      sortOrder: json['sort_order'] is int ? json['sort_order'] : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'price': price,
      'billing_cycle': billingCycle,
      'boost_multiplier': boostMultiplier,
      'max_featured_listings': maxFeaturedListings,
      'badge_enabled': badgeEnabled,
      'badge_text': badgeText,
      'features': features,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  bool get isFreePlan => price == 0 || slug == 'free';

  bool get hasUnlimitedFeatured => maxFeaturedListings == -1;

  String get formattedPrice => isFreePlan
      ? 'Free'
      : 'UGX ${NumberFormat('#,##0', 'en_US').format(price)}/$billingCycle';

  String get boostDescription => '${boostMultiplier}x ranking boost';

  String get featuredDescription => hasUnlimitedFeatured
      ? 'Unlimited featured listings'
      : '$maxFeaturedListings featured listings';
}

/// Vendor Subscription model mapped to vendor_subscriptions table
class VendorSubscriptionModel {
  final int id;
  final int vendorProfileId;
  final int subscriptionPlanId;
  final String status;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final int daysRemaining;
  final bool isExpiringSoon;
  final SubscriptionPlanModel? plan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VendorSubscriptionModel({
    required this.id,
    required this.vendorProfileId,
    required this.subscriptionPlanId,
    required this.status,
    this.startsAt,
    this.expiresAt,
    required this.autoRenew,
    this.daysRemaining = 0,
    this.isExpiringSoon = false,
    this.plan,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorSubscriptionModel.fromJson(Map<String, dynamic> json) {
    SubscriptionPlanModel? plan;
    if (json['plan'] != null && json['plan'] is Map<String, dynamic>) {
      plan = SubscriptionPlanModel.fromJson(json['plan']);
    }

    return VendorSubscriptionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorProfileId: json['vendor_profile_id'] is int
          ? json['vendor_profile_id']
          : int.tryParse(json['vendor_profile_id']?.toString() ?? '0') ?? 0,
      subscriptionPlanId: json['subscription_plan_id'] is int
          ? json['subscription_plan_id']
          : int.tryParse(json['subscription_plan_id']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      startsAt: json['starts_at'] != null ? DateTime.tryParse(json['starts_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      autoRenew: json['auto_renew'] == true || json['auto_renew'] == 1,
      daysRemaining: json['days_remaining'] is int
          ? json['days_remaining']
          : int.tryParse(json['days_remaining']?.toString() ?? '0') ?? 0,
      isExpiringSoon: json['is_expiring_soon'] == true,
      plan: plan,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_profile_id': vendorProfileId,
      'subscription_plan_id': subscriptionPlanId,
      'status': status,
      'starts_at': startsAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'auto_renew': autoRenew,
      'days_remaining': daysRemaining,
      'is_expiring_soon': isExpiringSoon,
      'plan': plan?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'active' && expiresAt != null && expiresAt!.isAfter(DateTime.now());
  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'Pending Payment';
      case 'expired':
        return 'Expired';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get expiryDisplay {
    if (expiresAt == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(expiresAt!);
  }

  String get daysRemainingDisplay {
    if (daysRemaining <= 0) return 'Expired';
    if (daysRemaining == 1) return '1 day left';
    return '$daysRemaining days left';
  }
}

/// Subscription Payment model mapped to subscription_payments table
class SubscriptionPaymentModel {
  final int id;
  final int vendorSubscriptionId;
  final int vendorProfileId;
  final String? pesapalOrderTrackingId;
  final String pesapalMerchantReference;
  final double amount;
  final String currency;
  final String status;
  final Map<String, dynamic>? paymentResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? planName;

  SubscriptionPaymentModel({
    required this.id,
    required this.vendorSubscriptionId,
    required this.vendorProfileId,
    this.pesapalOrderTrackingId,
    required this.pesapalMerchantReference,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentResponse,
    this.createdAt,
    this.updatedAt,
    this.planName,
  });

  factory SubscriptionPaymentModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPaymentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorSubscriptionId: json['vendor_subscription_id'] is int
          ? json['vendor_subscription_id']
          : int.tryParse(json['vendor_subscription_id']?.toString() ?? '0') ?? 0,
      vendorProfileId: json['vendor_profile_id'] is int
          ? json['vendor_profile_id']
          : int.tryParse(json['vendor_profile_id']?.toString() ?? '0') ?? 0,
      pesapalOrderTrackingId: json['pesapal_order_tracking_id']?.toString(),
      pesapalMerchantReference: json['merchant_reference']?.toString() ?? json['pesapal_merchant_reference']?.toString() ?? '',
      amount: json['amount'] is num ? json['amount'].toDouble() : double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'UGX',
      status: json['status']?.toString() ?? 'pending',
      paymentResponse: json['payment_response'] is Map<String, dynamic> ? json['payment_response'] : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      planName: json['plan_name']?.toString(),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  String get formattedAmount => '$currency ${NumberFormat('#,##0', 'en_US').format(amount)}';

  String get dateDisplay {
    if (createdAt == null) return 'N/A';
    return DateFormat('MMM dd, yyyy HH:mm').format(createdAt!);
  }
}

/// Vendor Subscription Info (for display in product cards)
class VendorSubscriptionInfo {
  final String planName;
  final String? badgeText;
  final bool hasPaidSubscription;

  VendorSubscriptionInfo({
    required this.planName,
    this.badgeText,
    required this.hasPaidSubscription,
  });

  factory VendorSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return VendorSubscriptionInfo(
      planName: json['plan_name']?.toString() ?? 'Free',
      badgeText: json['badge_text']?.toString(),
      hasPaidSubscription: json['has_paid_subscription'] == true,
    );
  }

  bool get showBadge => badgeText != null && badgeText!.isNotEmpty;
}
