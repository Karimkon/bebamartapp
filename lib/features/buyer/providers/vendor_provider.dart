// lib/features/vendor/providers/vendor_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/category_model.dart';

// ==================== DASHBOARD STATS ====================

class VendorDashboardStats {
  final int totalListings;
  final int activeListings;
  final int totalOrders;
  final int pendingOrders;
  final int processingOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final double totalRevenue;
  final double monthlyRevenue;
  final double pendingBalance;
  final double availableBalance;
  final double averageRating;
  final int totalReviews;
  final int totalViews;

  VendorDashboardStats({
    this.totalListings = 0,
    this.activeListings = 0,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.processingOrders = 0,
    this.shippedOrders = 0,
    this.deliveredOrders = 0,
    this.totalRevenue = 0,
    this.monthlyRevenue = 0,
    this.pendingBalance = 0,
    this.availableBalance = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.totalViews = 0,
  });

  factory VendorDashboardStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? json;
    return VendorDashboardStats(
      totalListings: _parseInt(stats['total_listings']),
      activeListings: _parseInt(stats['active_listings']),
      totalOrders: _parseInt(stats['total_orders']),
      pendingOrders: _parseInt(stats['pending_orders']),
      processingOrders: _parseInt(stats['processing_orders']),
      shippedOrders: _parseInt(stats['shipped_orders']),
      deliveredOrders: _parseInt(stats['delivered_orders']),
      totalRevenue: _parseDouble(stats['total_revenue'] ?? stats['total_sales']),
      monthlyRevenue: _parseDouble(stats['monthly_revenue'] ?? stats['monthly_sales']),
      pendingBalance: _parseDouble(stats['pending_balance']),
      availableBalance: _parseDouble(stats['available_balance']),
      averageRating: _parseDouble(stats['average_rating'] ?? stats['avg_rating']),
      totalReviews: _parseInt(stats['total_reviews']),
      totalViews: _parseInt(stats['total_views']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// Dashboard Stats Provider
final vendorDashboardProvider = FutureProvider<VendorDashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/dashboard');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data['success'] == true || data['stats'] != null) {
        return VendorDashboardStats.fromJson(data);
      }
    }
    return VendorDashboardStats();
  } on DioException catch (e) {
    print('Dashboard error: ${e.message}');
    throw Exception('Failed to load dashboard: ${e.message}');
  }
});

// Recent Orders Provider (for dashboard)
final vendorRecentOrdersProvider = FutureProvider<List<VendorOrderModel>>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/dashboard');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data['recent_orders'] != null) {
        final ordersList = data['recent_orders'] as List;
        return ordersList.map((e) => VendorOrderModel.fromJson(e)).toList();
      }
    }
    return [];
  } on DioException catch (e) {
    print('Recent orders error: ${e.message}');
    return [];
  }
});

// ==================== VENDOR LISTINGS ====================

class VendorListingsState {
  final List<ListingModel> listings;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalPages;
  final String? statusFilter;

  const VendorListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.statusFilter,
  });

  VendorListingsState copyWith({
    List<ListingModel>? listings,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalPages,
    String? statusFilter,
  }) {
    return VendorListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class VendorListingsNotifier extends StateNotifier<VendorListingsState> {
  final Ref ref;

  VendorListingsNotifier(this.ref) : super(const VendorListingsState());

  Future<void> loadListings({String? status, int page = 1, bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);
      String endpoint = '/api/vendor/listings?page=$page';
      if (status != null && status.isNotEmpty) {
        endpoint += '&status=$status';
      }

      final response = await api.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<ListingModel> listings = [];

        // Handle different response formats
        if (data['data'] != null) {
          listings = (data['data'] as List).map((e) => ListingModel.fromJson(e)).toList();
        } else if (data['listings'] != null) {
          listings = (data['listings'] as List).map((e) => ListingModel.fromJson(e)).toList();
        } else if (data is List) {
          listings = data.map((e) => ListingModel.fromJson(e)).toList();
        }

        state = state.copyWith(
          listings: page == 1 ? listings : [...state.listings, ...listings],
          isLoading: false,
          currentPage: page,
          totalPages: data['last_page'] ?? data['meta']?['last_page'] ?? 1,
          statusFilter: status,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to load listings');
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> toggleListingStatus(int listingId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/vendor/listings/$listingId/toggle-status');

      if (response.statusCode == 200) {
        // Refresh listings after toggle
        await loadListings(status: state.statusFilter, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Toggle status error: $e');
      return false;
    }
  }

  Future<bool> deleteListing(int listingId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.delete('/api/vendor/listings/$listingId');

      if (response.statusCode == 200) {
        // Remove from local state immediately
        state = state.copyWith(
          listings: state.listings.where((l) => l.id != listingId).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Delete listing error: $e');
      return false;
    }
  }
}

final vendorListingsProvider =
    StateNotifierProvider<VendorListingsNotifier, VendorListingsState>((ref) {
  return VendorListingsNotifier(ref);
});

// ==================== CREATE/EDIT LISTING ====================

class CreateListingState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final List<CategoryModel> categories;

  const CreateListingState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.categories = const [],
  });

  CreateListingState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    List<CategoryModel>? categories,
  }) {
    return CreateListingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      categories: categories ?? this.categories,
    );
  }
}

class CreateListingNotifier extends StateNotifier<CreateListingState> {
  final Ref ref;

  CreateListingNotifier(this.ref) : super(const CreateListingState());

  Future<void> loadCategories() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/api/categories');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<CategoryModel> categories = [];

        if (data['data'] != null) {
          categories = (data['data'] as List).map((e) => CategoryModel.fromJson(e)).toList();
        } else if (data['categories'] != null) {
          categories = (data['categories'] as List).map((e) => CategoryModel.fromJson(e)).toList();
        } else if (data is List) {
          categories = data.map((e) => CategoryModel.fromJson(e)).toList();
        }

        state = state.copyWith(categories: categories);
      }
    } catch (e) {
      print('Load categories error: $e');
    }
  }

  Future<bool> createListing({
    required String title,
    required String description,
    required double price,
    required int categoryId,
    int? quantity,
    String? condition,
    List<File>? images,
    List<Map<String, dynamic>>? variants,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final api = ref.read(apiClientProvider);

      // Create form data for multipart request
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'quantity': quantity ?? 1,
        'condition': condition ?? 'new',
        'is_active': 1,
      });

      // Add images if provided
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          formData.files.add(MapEntry(
            'images[]',
            await MultipartFile.fromFile(images[i].path, filename: 'image_$i.jpg'),
          ));
        }
      }

      // Add variants if provided
      if (variants != null && variants.isNotEmpty) {
        formData.fields.add(MapEntry('variants', variants.toString()));
      }

      final response = await api.post(
        '/api/vendor/listings',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Listing created successfully!',
        );
        // Refresh listings
        ref.read(vendorListingsProvider.notifier).loadListings(refresh: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data?['message'] ?? 'Failed to create listing',
        );
        return false;
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to create listing';
      if (e.response?.data != null && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else if (e.response?.data != null && e.response?.data['errors'] != null) {
        final errors = e.response!.data['errors'] as Map;
        errorMessage = errors.values.first?.first ?? errorMessage;
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> updateListing({
    required int listingId,
    required String title,
    required String description,
    required double price,
    required int categoryId,
    int? quantity,
    String? condition,
    List<File>? newImages,
    List<int>? deleteImageIds,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final api = ref.read(apiClientProvider);

      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'quantity': quantity ?? 1,
        'condition': condition ?? 'new',
        '_method': 'PUT', // Laravel method spoofing
      });

      // Add new images
      if (newImages != null && newImages.isNotEmpty) {
        for (int i = 0; i < newImages.length; i++) {
          formData.files.add(MapEntry(
            'images[]',
            await MultipartFile.fromFile(newImages[i].path, filename: 'image_$i.jpg'),
          ));
        }
      }

      // Add image IDs to delete
      if (deleteImageIds != null && deleteImageIds.isNotEmpty) {
        for (var id in deleteImageIds) {
          formData.fields.add(MapEntry('delete_images[]', id.toString()));
        }
      }

      final response = await api.post(
        '/api/vendor/listings/$listingId',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Listing updated successfully!',
        );
        ref.read(vendorListingsProvider.notifier).loadListings(refresh: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data?['message'] ?? 'Failed to update listing',
        );
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final createListingProvider =
    StateNotifierProvider<CreateListingNotifier, CreateListingState>((ref) {
  return CreateListingNotifier(ref);
});

// ==================== VENDOR ORDERS ====================

class VendorOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final double total;
  final double subtotal;
  final double shippingCost;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final BuyerInfo? buyer;
  final ShippingInfo? shippingAddress;
  final List<OrderItemModel> items;

  VendorOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.subtotal = 0,
    this.shippingCost = 0,
    this.paymentStatus,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.buyer,
    this.shippingAddress,
    this.items = const [],
  });

  factory VendorOrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List).map((e) => OrderItemModel.fromJson(e)).toList();
    } else if (json['order_items'] != null) {
      items = (json['order_items'] as List).map((e) => OrderItemModel.fromJson(e)).toList();
    }

    return VendorOrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? json['id'].toString(),
      status: json['status'] ?? 'pending',
      total: _parseDouble(json['total']),
      subtotal: _parseDouble(json['subtotal']),
      shippingCost: _parseDouble(json['shipping_cost']),
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      buyer: json['buyer'] != null ? BuyerInfo.fromJson(json['buyer']) : null,
      shippingAddress: json['shipping_address'] != null
          ? ShippingInfo.fromJson(json['shipping_address'])
          : null,
      items: items,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class BuyerInfo {
  final int id;
  final String? name;
  final String? email;
  final String? phone;

  BuyerInfo({required this.id, this.name, this.email, this.phone});

  factory BuyerInfo.fromJson(Map<String, dynamic> json) {
    return BuyerInfo(
      id: json['id'] ?? 0,
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class ShippingInfo {
  final String? fullName;
  final String? address;
  final String? city;
  final String? region;
  final String? phone;

  ShippingInfo({this.fullName, this.address, this.city, this.region, this.phone});

  factory ShippingInfo.fromJson(Map<String, dynamic> json) {
    return ShippingInfo(
      fullName: json['full_name'] ?? json['name'],
      address: json['address'] ?? json['address_line_1'],
      city: json['city'],
      region: json['region'] ?? json['state'],
      phone: json['phone'],
    );
  }

  String get fullAddress {
    final parts = [address, city, region].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}

class OrderItemModel {
  final int id;
  final int listingId;
  final String? title;
  final int quantity;
  final double price;
  final double total;
  final String? imageUrl;
  final String? variant;

  OrderItemModel({
    required this.id,
    required this.listingId,
    this.title,
    required this.quantity,
    required this.price,
    required this.total,
    this.imageUrl,
    this.variant,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Get listing info
    final listing = json['listing'] ?? {};

    return OrderItemModel(
      id: json['id'] ?? 0,
      listingId: json['listing_id'] ?? listing['id'] ?? 0,
      title: json['title'] ?? listing['title'],
      quantity: json['quantity'] ?? 1,
      price: _parseDouble(json['price'] ?? json['unit_price']),
      total: _parseDouble(json['total'] ?? json['subtotal']),
      imageUrl: json['image_url'] ?? listing['primary_image'] ?? listing['image'],
      variant: json['variant'] ?? json['variant_info'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// Vendor Orders State
class VendorOrdersState {
  final List<VendorOrderModel> orders;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalPages;
  final String? statusFilter;

  const VendorOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.statusFilter,
  });

  VendorOrdersState copyWith({
    List<VendorOrderModel>? orders,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalPages,
    String? statusFilter,
  }) {
    return VendorOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class VendorOrdersNotifier extends StateNotifier<VendorOrdersState> {
  final Ref ref;

  VendorOrdersNotifier(this.ref) : super(const VendorOrdersState());

  Future<void> loadOrders({String? status, int page = 1, bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);
      String endpoint = '/api/vendor/orders?page=$page';
      if (status != null && status.isNotEmpty && status != 'all') {
        endpoint += '&status=$status';
      }

      final response = await api.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<VendorOrderModel> orders = [];

        if (data['data'] != null) {
          orders = (data['data'] as List).map((e) => VendorOrderModel.fromJson(e)).toList();
        } else if (data['orders'] != null) {
          orders = (data['orders'] as List).map((e) => VendorOrderModel.fromJson(e)).toList();
        } else if (data is List) {
          orders = data.map((e) => VendorOrderModel.fromJson(e)).toList();
        }

        state = state.copyWith(
          orders: page == 1 ? orders : [...state.orders, ...orders],
          isLoading: false,
          currentPage: page,
          totalPages: data['last_page'] ?? data['meta']?['last_page'] ?? 1,
          statusFilter: status,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to load orders');
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/api/vendor/orders/$orderId/status',
        data: {'status': newStatus},
      );

      if (response.statusCode == 200) {
        // Refresh orders after update
        await loadOrders(status: state.statusFilter, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Update order status error: $e');
      return false;
    }
  }
}

final vendorOrdersProvider =
    StateNotifierProvider<VendorOrdersNotifier, VendorOrdersState>((ref) {
  return VendorOrdersNotifier(ref);
});

// Single order detail provider
final vendorOrderDetailProvider = FutureProvider.family<VendorOrderModel?, int>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/orders/$orderId');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data['order'] != null) {
        return VendorOrderModel.fromJson(data['order']);
      } else if (data['data'] != null) {
        return VendorOrderModel.fromJson(data['data']);
      } else {
        return VendorOrderModel.fromJson(data);
      }
    }
    return null;
  } catch (e) {
    print('Order detail error: $e');
    return null;
  }
});

// ==================== VENDOR PROFILE ====================

class VendorProfileModel {
  final int id;
  final int userId;
  final String? businessName;
  final String? businessDescription;
  final String? businessAddress;
  final String? businessPhone;
  final String? businessEmail;
  final String? logo;
  final String? banner;
  final String vettingStatus;
  final String? vendorType;
  final double rating;
  final int totalSales;
  final DateTime? createdAt;

  VendorProfileModel({
    required this.id,
    required this.userId,
    this.businessName,
    this.businessDescription,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    this.logo,
    this.banner,
    this.vettingStatus = 'pending',
    this.vendorType,
    this.rating = 0,
    this.totalSales = 0,
    this.createdAt,
  });

  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    return VendorProfileModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      businessName: json['business_name'],
      businessDescription: json['business_description'] ?? json['description'],
      businessAddress: json['business_address'] ?? json['address'],
      businessPhone: json['business_phone'] ?? json['phone'],
      businessEmail: json['business_email'] ?? json['email'],
      logo: json['logo'],
      banner: json['banner'],
      vettingStatus: json['vetting_status'] ?? 'pending',
      vendorType: json['vendor_type'],
      rating: _parseDouble(json['rating']),
      totalSales: json['total_sales'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool get isApproved => vettingStatus == 'approved';
  bool get isPending => vettingStatus == 'pending';
  bool get isRejected => vettingStatus == 'rejected';
}

// Vendor Profile Provider
final vendorProfileProvider = FutureProvider<VendorProfileModel?>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/profile');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data['profile'] != null) {
        return VendorProfileModel.fromJson(data['profile']);
      } else if (data['data'] != null) {
        return VendorProfileModel.fromJson(data['data']);
      } else if (data['vendor_profile'] != null) {
        return VendorProfileModel.fromJson(data['vendor_profile']);
      }
      return VendorProfileModel.fromJson(data);
    }
    return null;
  } catch (e) {
    print('Vendor profile error: $e');
    return null;
  }
});

// Update profile notifier
class UpdateProfileNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  UpdateProfileNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<bool> updateProfile({
    String? businessName,
    String? businessDescription,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    File? logo,
    File? banner,
  }) async {
    state = const AsyncValue.loading();

    try {
      final api = ref.read(apiClientProvider);

      final formData = FormData.fromMap({
        if (businessName != null) 'business_name': businessName,
        if (businessDescription != null) 'business_description': businessDescription,
        if (businessAddress != null) 'business_address': businessAddress,
        if (businessPhone != null) 'business_phone': businessPhone,
        if (businessEmail != null) 'business_email': businessEmail,
        '_method': 'PUT',
      });

      if (logo != null) {
        formData.files.add(MapEntry(
          'logo',
          await MultipartFile.fromFile(logo.path, filename: 'logo.jpg'),
        ));
      }

      if (banner != null) {
        formData.files.add(MapEntry(
          'banner',
          await MultipartFile.fromFile(banner.path, filename: 'banner.jpg'),
        ));
      }

      final response = await api.post(
        '/api/vendor/profile',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200) {
        state = const AsyncValue.data(null);
        ref.invalidate(vendorProfileProvider);
        return true;
      }
      state = AsyncValue.error('Failed to update profile', StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final updateProfileProvider =
    StateNotifierProvider<UpdateProfileNotifier, AsyncValue<void>>((ref) {
  return UpdateProfileNotifier(ref);
});

// ==================== VENDOR ANALYTICS ====================

class VendorAnalytics {
  final int totalViews;
  final int totalOrders;
  final int deliveredOrders;
  final double avgRating;
  final List<Map<String, dynamic>> salesByDay;
  final List<Map<String, dynamic>> topProducts;

  VendorAnalytics({
    this.totalViews = 0,
    this.totalOrders = 0,
    this.deliveredOrders = 0,
    this.avgRating = 0,
    this.salesByDay = const [],
    this.topProducts = const [],
  });

  factory VendorAnalytics.fromJson(Map<String, dynamic> json) {
    return VendorAnalytics(
      totalViews: json['total_views'] ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      deliveredOrders: json['delivered_orders'] ?? 0,
      avgRating: _parseDouble(json['avg_rating']),
      salesByDay: json['sales_by_day'] != null
          ? List<Map<String, dynamic>>.from(json['sales_by_day'])
          : [],
      topProducts: json['top_products'] != null
          ? List<Map<String, dynamic>>.from(json['top_products'])
          : [],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

final vendorAnalyticsProvider = FutureProvider<VendorAnalytics>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/analytics');

    if (response.statusCode == 200 && response.data != null) {
      return VendorAnalytics.fromJson(response.data);
    }
    return VendorAnalytics();
  } catch (e) {
    print('Analytics error: $e');
    return VendorAnalytics();
  }
});
