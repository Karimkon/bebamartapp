// lib/shared/models/user_model.dart
// User model mapped 1:1 with Laravel users table

class UserModel {
  final int id;
  final String? name;
  final String phone;
  final String? email;
  final String? avatar;
  final DateTime? emailVerifiedAt;
  final String role; // buyer, vendor_local, vendor_international, admin, logistics, clearing_agent
  final bool isActive;
  final bool isAdminVerified; // Blue tick badge - admin verified user
  final Map<String, dynamic>? meta;
  final VendorProfileModel? vendorProfile;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    this.name,
    required this.phone,
    this.email,
    this.avatar,
    this.emailVerifiedAt,
    required this.role,
    this.isActive = true,
    this.isAdminVerified = false,
    this.meta,
    this.vendorProfile,
    this.createdAt,
    this.updatedAt,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle nested structure - check if data is inside 'data' key
    final data = json['data'] ?? json;
    
    return UserModel(
      id: (data['id'] as int?) ?? 0,
      name: data['name'] as String?,
      phone: (data['phone'] as String?) ?? '', // FIXED: Handle null phone
      email: data['email'] as String?,
      avatar: data['avatar'] as String?,
      emailVerifiedAt: data['email_verified_at'] != null
          ? DateTime.tryParse(data['email_verified_at'].toString())
          : null,
      role: (data['role'] as String?) ?? 'buyer',
      isActive: data['is_active'] == true || data['is_active'] == 1,
      isAdminVerified: data['is_admin_verified'] == true || data['is_admin_verified'] == 1,
      meta: data['meta'] is Map<String, dynamic> ? data['meta'] : null,
      vendorProfile: data['vendor_profile'] != null
          ? VendorProfileModel.fromJson(data['vendor_profile'])
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'role': role,
      'is_active': isActive,
      'is_admin_verified': isAdminVerified,
      'meta': meta,
      'vendor_profile': vendorProfile?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  // FIXED: Role checks - vendor detection based on ROLE first
  // A user IS a vendor if their role is vendor_local or vendor_international
  // They can ACCESS vendor dashboard only if approved, otherwise go to onboarding
  bool get isVendor => role == 'vendor_local' || role == 'vendor_international';
  
  bool get isBuyer => role == 'buyer';
  
  bool get isAdmin => role == 'admin';
  
  bool get isVendorLocal => role == 'vendor_local';
  
  bool get isVendorInternational => role == 'vendor_international';
  
  // Check if vendor needs to complete onboarding
  bool get isInVendorOnboarding => 
      isVendor && (vendorProfile == null || vendorProfile!.vettingStatus != 'approved');
  
  // Check if vendor is fully approved and can access dashboard
  bool get isApprovedVendor => isVendor && vendorProfile?.isApproved == true;
  
  // Alias for clarity
  bool get canAccessVendorDashboard => isApprovedVendor;
  
  String get displayName => name ?? phone;
  
  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }
  
  UserModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? avatar,
    DateTime? emailVerifiedAt,
    String? role,
    bool? isActive,
    bool? isAdminVerified,
    Map<String, dynamic>? meta,
    VendorProfileModel? vendorProfile,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isAdminVerified: isAdminVerified ?? this.isAdminVerified,
      meta: meta ?? this.meta,
      vendorProfile: vendorProfile ?? this.vendorProfile,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// VendorProfile model mapped to vendor_profiles table
class VendorProfileModel {
  final int id;
  final int userId;
  final String businessName;
  final String? businessDescription;
  final String? businessAddress;
  final String? phone;
  final String? email;
  final String? logo;
  final String? banner;
  final String? vendorType; // local_retail, china_supplier, etc.
  final String vettingStatus; // pending, approved, rejected
  final String? country;
  final String? city;
  final double rating;
  final int? totalSales;
  final bool isVerified; // Blue tick verified badge
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Subscription fields
  final String subscriptionPlanName;
  final String? subscriptionBadgeText;
  final bool hasPaidSubscription;
  final double boostMultiplier;

  VendorProfileModel({
    required this.id,
    required this.userId,
    required this.businessName,
    this.businessDescription,
    this.businessAddress,
    this.phone,
    this.email,
    this.logo,
    this.banner,
    this.vendorType,
    this.vettingStatus = 'pending',
    this.country,
    this.city,
    this.rating = 0.0,
    this.totalSales,
    this.isVerified = false,
    this.meta,
    this.createdAt,
    this.updatedAt,
    this.subscriptionPlanName = 'Free',
    this.subscriptionBadgeText,
    this.hasPaidSubscription = false,
    this.boostMultiplier = 1.0,
  });
  
  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    // Parse subscription data from nested object or direct fields
    final subscription = json['subscription'] is Map<String, dynamic>
        ? json['subscription'] as Map<String, dynamic>
        : <String, dynamic>{};

    return VendorProfileModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      businessName: json['business_name']?.toString() ?? '',
      businessDescription: json['business_description']?.toString(),
      businessAddress: json['business_address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      logo: json['logo']?.toString(),
      banner: json['banner']?.toString(),
      vendorType: json['vendor_type']?.toString(),
      vettingStatus: json['vetting_status']?.toString() ?? 'pending',
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      rating: json['rating'] is num ? json['rating'].toDouble() : (double.tryParse(json['rating']?.toString() ?? '') ?? 0.0),
      totalSales: json['total_sales'] is int ? json['total_sales'] : int.tryParse(json['total_sales']?.toString() ?? '0'),
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      // Subscription fields
      subscriptionPlanName: subscription['plan_name']?.toString() ?? 'Free',
      subscriptionBadgeText: subscription['badge_text']?.toString(),
      hasPaidSubscription: subscription['has_paid_subscription'] == true,
      boostMultiplier: subscription['boost_multiplier'] is num
          ? subscription['boost_multiplier'].toDouble()
          : 1.0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'business_description': businessDescription,
      'business_address': businessAddress,
      'phone': phone,
      'email': email,
      'logo': logo,
      'banner': banner,
      'vendor_type': vendorType,
      'vetting_status': vettingStatus,
      'country': country,
      'city': city,
      'rating': rating,
      'total_sales': totalSales,
      'is_verified': isVerified,
      'meta': meta,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'subscription': {
        'plan_name': subscriptionPlanName,
        'badge_text': subscriptionBadgeText,
        'has_paid_subscription': hasPaidSubscription,
        'boost_multiplier': boostMultiplier,
      },
    };
  }

  // Subscription helper getters
  bool get hasSubscriptionBadge => subscriptionBadgeText != null && subscriptionBadgeText!.isNotEmpty;
  bool get isFreeUser => !hasPaidSubscription;
  bool get isPremiumVendor => hasPaidSubscription;

  bool get isApproved => vettingStatus == 'approved';
  bool get isPending => vettingStatus == 'pending';
  bool get isRejected => vettingStatus == 'rejected';

  String get displayRating => rating.toStringAsFixed(1);

  // Compatibility alias expected by UI
  String? get businessPhone => phone;

  String get location {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (country != null) parts.add(country!);
    return parts.join(', ');
  }

  // Compatibility aliases expected by vendor UI
  String get ratingValue => (rating ?? 0.0).toStringAsFixed(1);

  /// Get vendor duration badge text (e.g., "2+ years on BebaMart")
  String get durationBadge {
    if (createdAt == null) return 'New on BebaMart';

    final now = DateTime.now();
    final totalDays = now.difference(createdAt!).inDays;
    final years = totalDays ~/ 365;
    final months = (totalDays % 365) ~/ 30;
    final days = totalDays % 30;

    if (years == 0) {
      if (months == 0) {
        if (totalDays == 0) return 'New on BebaMart';
        if (totalDays == 1) return '1 day on BebaMart';
        return '$totalDays days on BebaMart';
      }
      if (months == 1) return '1 month on BebaMart';
      return '$months months on BebaMart';
    }
    if (years == 1) return '1 year on BebaMart';
    return '$years+ years on BebaMart';
  }
}

// Shipping Address model mapped to shipping_addresses table
class ShippingAddressModel {
  final int id;
  final int userId;
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
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  ShippingAddressModel({
    required this.id,
    required this.userId,
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
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });
  
  factory ShippingAddressModel.fromJson(Map<String, dynamic> json) {
    return ShippingAddressModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      label: json['label'] as String?,
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      addressLine1: json['address_line_1'] as String,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String,
      stateRegion: json['state_region'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'Uganda',
      deliveryInstructions: json['delivery_instructions'] as String?,
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state_region': stateRegion,
      'postal_code': postalCode,
      'country': country,
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  String get fullAddress {
    final parts = <String>[addressLine1];
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    parts.add(city);
    if (stateRegion != null && stateRegion!.isNotEmpty) {
      parts.add(stateRegion!);
    }
    if (postalCode != null && postalCode!.isNotEmpty) {
      parts.add(postalCode!);
    }
    parts.add(country);
    return parts.join(', ');
  }
  
  String get displayLabel => label ?? 'Address';
}

// Buyer Wallet model mapped to buyer_wallets table
class BuyerWalletModel {
  final int id;
  final int userId;
  final double balance;
  final double lockedBalance;
  final String currency;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  BuyerWalletModel({
    required this.id,
    required this.userId,
    this.balance = 0.0,
    this.lockedBalance = 0.0,
    this.currency = 'UGX',
    this.meta,
    this.createdAt,
    this.updatedAt,
  });
  
  factory BuyerWalletModel.fromJson(Map<String, dynamic> json) {
    return BuyerWalletModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['locked_balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'UGX',
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  
  double get availableBalance => balance - lockedBalance;
  
  bool hasSufficientBalance(double amount) => availableBalance >= amount;
}