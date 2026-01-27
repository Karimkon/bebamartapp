// lib/features/vendor/providers/vendor_provider.dart
// Complete vendor providers with real API integration
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io';

// Re-export commonly used models
export '../../../shared/models/user_model.dart' show VendorProfileModel;
export '../../../shared/models/listing_model.dart' show ListingModel;
export '../../../shared/models/order_model.dart' show OrderModel, OrderItemModel, ShippingAddressInfo;

import '../../../shared/models/user_model.dart' show VendorProfileModel;
import '../../../shared/models/listing_model.dart' show ListingModel;
import '../../../shared/models/order_model.dart' show OrderModel, OrderItemModel, ShippingAddressInfo;
import '../../../shared/models/category_model.dart' show CategoryModel;
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

// Type aliases expected by vendor UI
typedef VendorOrderModel = OrderModel;
typedef ShippingInfo = ShippingAddressInfo;

// ==================== VENDOR EXCEPTIONS ====================
class VendorDeactivatedException implements Exception {
  final String message;
  final String? supportEmail;
  final String? supportPhone;

  VendorDeactivatedException({
    required this.message,
    this.supportEmail,
    this.supportPhone,
  });

  @override
  String toString() => message;
}

class VendorOnboardingRequiredException implements Exception {
  final String message;

  VendorOnboardingRequiredException({
    this.message = 'You need to complete vendor onboarding first.',
  });

  @override
  String toString() => message;
}

class VendorApprovalPendingException implements Exception {
  final String message;
  final String vettingStatus;

  VendorApprovalPendingException({
    required this.message,
    required this.vettingStatus,
  });

  @override
  String toString() => message;
}

// ==================== DASHBOARD STATS MODEL ====================
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
  // Vetting status fields
  final String? vettingStatus;
  final bool isApproved;
  final bool isPending;
  final bool isRejected;
  final String? vettingNotes;

  VendorDashboardStats({
    this.totalListings = 0,
    this.activeListings = 0,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.processingOrders = 0,
    this.shippedOrders = 0,
    this.deliveredOrders = 0,
    this.totalRevenue = 0.0,
    this.monthlyRevenue = 0.0,
    this.pendingBalance = 0.0,
    this.availableBalance = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalViews = 0,
    this.vettingStatus,
    this.isApproved = false,
    this.isPending = false,
    this.isRejected = false,
    this.vettingNotes,
  });

  factory VendorDashboardStats.fromJson(Map<String, dynamic> json) {
    return VendorDashboardStats(
      totalListings: _parseInt(json['total_listings']),
      activeListings: _parseInt(json['active_listings']),
      totalOrders: _parseInt(json['total_orders']),
      pendingOrders: _parseInt(json['pending_orders']),
      processingOrders: _parseInt(json['processing_orders']),
      shippedOrders: _parseInt(json['shipped_orders']),
      deliveredOrders: _parseInt(json['delivered_orders']),
      totalRevenue: _parseDouble(json['total_revenue']),
      monthlyRevenue: _parseDouble(json['monthly_revenue']),
      pendingBalance: _parseDouble(json['pending_balance']),
      availableBalance: _parseDouble(json['available_balance']),
      averageRating: _parseDouble(json['average_rating']),
      totalReviews: _parseInt(json['total_reviews']),
      totalViews: _parseInt(json['total_views']),
      vettingStatus: json['vetting_status'] as String?,
      isApproved: json['is_approved'] == true,
      isPending: json['is_pending'] == true,
      isRejected: json['is_rejected'] == true,
      vettingNotes: json['vetting_notes'] as String?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

// ==================== DASHBOARD PROVIDER ====================
final vendorDashboardProvider = FutureProvider<VendorDashboardStats>((ref) async {
  print('🔄 vendorDashboardProvider: Fetching dashboard data...');
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/dashboard');
    print('📦 vendorDashboardProvider: Response status: ${response.statusCode}');

    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;

      if (data['success'] == true && data['stats'] != null) {
        // Parse stats with vetting status info from root response
        final statsJson = Map<String, dynamic>.from(data['stats'] as Map);
        // Add vetting info from root level to stats
        statsJson['vetting_status'] = data['vetting_status'];
        statsJson['is_approved'] = data['is_approved'];
        statsJson['is_pending'] = data['is_pending'];
        statsJson['is_rejected'] = data['is_rejected'];
        statsJson['vetting_notes'] = data['vetting_notes'];

        final stats = VendorDashboardStats.fromJson(statsJson);
        print('✅ Dashboard stats loaded: ${stats.totalListings} listings, vetting_status: ${stats.vettingStatus}');
        return stats;
      }
    }

    print('⚠️ Failed to load dashboard stats');
    return VendorDashboardStats();
  } on DioException catch (e) {
    print('❌ DioException in vendorDashboardProvider: ${e.message}');
    print('❌ Response: ${e.response?.data}');

    final data = e.response?.data;

    // Check if vendor needs onboarding (404 with requires_onboarding)
    if (e.response?.statusCode == 404) {
      if (data is Map && data['requires_onboarding'] == true) {
        throw VendorOnboardingRequiredException(
          message: data['message'] ?? 'You need to complete vendor onboarding first.',
        );
      }
      print('⚠️ Vendor profile not found');
      throw VendorOnboardingRequiredException();
    }

    // Check if vendor is deactivated (403 response)
    if (e.response?.statusCode == 403) {
      if (data is Map && data['is_deactivated'] == true) {
        throw VendorDeactivatedException(
          message: data['message'] ?? 'Your vendor account has been deactivated.',
          supportEmail: data['support_email'],
          supportPhone: data['support_phone'],
        );
      }
    }

    return VendorDashboardStats();
  } catch (e) {
    print('❌ Error in vendorDashboardProvider: $e');
    rethrow; // Re-throw custom exceptions
  }
});

// ==================== RECENT ORDERS PROVIDER ====================
final vendorRecentOrdersProvider = FutureProvider<List<VendorOrderModel>>((ref) async {
  print('🔄 vendorRecentOrdersProvider: Fetching recent orders...');
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/dashboard');

    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;

      if (data['success'] == true && data['recent_orders'] != null) {
        final ordersData = data['recent_orders'] as List;
        final orders = ordersData
            .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
            .toList();
        print('✅ Loaded ${orders.length} recent orders');
        return orders;
      }
    }

    return <VendorOrderModel>[];
  } on DioException catch (e) {
    print('❌ DioException in vendorRecentOrdersProvider: ${e.message}');
    return <VendorOrderModel>[];
  } catch (e) {
    print('❌ Error in vendorRecentOrdersProvider: $e');
    return <VendorOrderModel>[];
  }
});

// ==================== VENDOR PROFILE PROVIDER ====================
// Now fetches full profile with stats from API
final vendorProfileProvider = FutureProvider<VendorProfileModel?>((ref) async {
  print('🔄 vendorProfileProvider: Fetching vendor profile with stats...');
  final api = ref.watch(apiClientProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null || !user.isVendor) {
    print('⚠️ User is null or not a vendor');
    return null;
  }

  try {
    // First get the dashboard stats
    final dashboardResponse = await api.get('/api/vendor/dashboard');

    if (dashboardResponse.statusCode == 200 && dashboardResponse.data is Map) {
      final data = dashboardResponse.data as Map;

      if (data['success'] == true && data['stats'] != null) {
        final stats = data['stats'] as Map<String, dynamic>;

        // Build an enhanced profile with stats
        final baseProfile = user.vendorProfile;
        if (baseProfile != null) {
          // Create enhanced profile with stats from dashboard
          return VendorProfileModel(
            id: baseProfile.id,
            userId: baseProfile.userId,
            businessName: baseProfile.businessName,
            businessDescription: baseProfile.businessDescription,
            businessAddress: baseProfile.businessAddress,
            phone: baseProfile.phone,
            email: baseProfile.email,
            logo: baseProfile.logo,
            banner: baseProfile.banner,
            vendorType: baseProfile.vendorType,
            vettingStatus: baseProfile.vettingStatus,
            country: baseProfile.country,
            city: baseProfile.city,
            rating: _parseDouble(stats['average_rating']),
            totalSales: _parseInt(stats['total_orders']),
            meta: baseProfile.meta,
            createdAt: baseProfile.createdAt,
            updatedAt: baseProfile.updatedAt,
          );
        }
      }
    }

    // Fallback to cached profile
    print('⚠️ Using cached vendor profile');
    return user.vendorProfile;
  } on DioException catch (e) {
    print('❌ DioException in vendorProfileProvider: ${e.message}');
    return user.vendorProfile;
  } catch (e) {
    print('❌ Error in vendorProfileProvider: $e');
    return user.vendorProfile;
  }
});

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

// ==================== LISTINGS STATE & NOTIFIER ====================
class VendorListingsState {
  final bool isLoading;
  final List<ListingModel> listings;
  final String? error;
  final int currentPage;
  final int lastPage;
  final int total;

  VendorListingsState({
    this.isLoading = false,
    this.listings = const [],
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  VendorListingsState copyWith({
    bool? isLoading,
    List<ListingModel>? listings,
    String? error,
    int? currentPage,
    int? lastPage,
    int? total,
  }) {
    return VendorListingsState(
      isLoading: isLoading ?? this.isLoading,
      listings: listings ?? this.listings,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
    );
  }
}

class VendorListingsNotifier extends StateNotifier<VendorListingsState> {
  final Ref ref;

  VendorListingsNotifier(this.ref) : super(VendorListingsState());

  Future<void> loadListings({String? status, bool refresh = false, int perPage = 20}) async {
    print('🔄 VendorListingsNotifier: Loading listings (status=$status, refresh=$refresh)');

    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, listings: []);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final api = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'per_page': perPage,
      };
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }

      final response = await api.get(
        '/api/vendor/listings',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;

        if (data['success'] == true && data['data'] != null) {
          final listingsData = data['data'] as List;
          final listings = listingsData
              .map((l) => ListingModel.fromJson(l as Map<String, dynamic>))
              .toList();

          state = state.copyWith(
            isLoading: false,
            listings: listings,
            currentPage: data['current_page'] ?? 1,
            lastPage: data['last_page'] ?? 1,
            total: data['total'] ?? listings.length,
          );
          print('✅ Loaded ${listings.length} listings');
          return;
        }
      }

      state = state.copyWith(isLoading: false, listings: []);
    } on DioException catch (e) {
      print('❌ DioException loading listings: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load listings',
      );
    } catch (e) {
      print('❌ Error loading listings: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleListingStatus(int listingId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/vendor/listings/$listingId/toggle-status');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Refresh listings
        await loadListings(refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error toggling listing status: $e');
      return false;
    }
  }

  Future<bool> deleteListing(int listingId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.delete('/api/vendor/listings/$listingId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Remove from local state
        state = state.copyWith(
          listings: state.listings.where((l) => l.id != listingId).toList(),
          total: state.total - 1,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting listing: $e');
      return false;
    }
  }
}

final vendorListingsProvider = StateNotifierProvider<VendorListingsNotifier, VendorListingsState>((ref) {
  return VendorListingsNotifier(ref);
});

// ==================== ORDERS STATE & NOTIFIER ====================
class VendorOrdersState {
  final bool isLoading;
  final List<OrderModel> orders;
  final String? error;
  final int currentPage;
  final int lastPage;
  final int total;

  VendorOrdersState({
    this.isLoading = false,
    this.orders = const [],
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  VendorOrdersState copyWith({
    bool? isLoading,
    List<OrderModel>? orders,
    String? error,
    int? currentPage,
    int? lastPage,
    int? total,
  }) {
    return VendorOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
    );
  }
}

class VendorOrdersNotifier extends StateNotifier<VendorOrdersState> {
  final Ref ref;

  VendorOrdersNotifier(this.ref) : super(VendorOrdersState());

  Future<void> loadOrders({String? status, bool refresh = false, int perPage = 20}) async {
    print('🔄 VendorOrdersNotifier: Loading orders (status=$status)');

    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, orders: []);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final api = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'per_page': perPage,
      };
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }

      final response = await api.get(
        '/api/vendor/orders',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;

        if (data['success'] == true && data['data'] != null) {
          final ordersData = data['data'] as List;
          final orders = ordersData
              .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
              .toList();

          state = state.copyWith(
            isLoading: false,
            orders: orders,
            currentPage: data['current_page'] ?? 1,
            lastPage: data['last_page'] ?? 1,
            total: data['total'] ?? orders.length,
          );
          print('✅ Loaded ${orders.length} orders');
          return;
        }
      }

      state = state.copyWith(isLoading: false, orders: []);
    } on DioException catch (e) {
      print('❌ DioException loading orders: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load orders',
      );
    } catch (e) {
      print('❌ Error loading orders: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String newStatus) async {
    print('🔄 Updating order $orderId status to $newStatus');

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/api/vendor/orders/$orderId/status',
        data: {'status': newStatus},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local state
        final updatedOrders = state.orders.map((order) {
          if (order.id == orderId) {
            return order.copyWith(status: newStatus);
          }
          return order;
        }).toList();

        state = state.copyWith(orders: updatedOrders);
        print('✅ Order status updated');
        return {'success': true, 'message': response.data['message']};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed to update status'};
    } on DioException catch (e) {
      print('❌ DioException updating order status: ${e.message}');
      final responseData = e.response?.data;
      // Check if COD payment confirmation is required
      if (responseData is Map && responseData['requires_payment_confirmation'] == true) {
        return {
          'success': false,
          'requires_payment_confirmation': true,
          'message': responseData['message'] ?? 'COD payment confirmation required',
        };
      }
      return {'success': false, 'message': responseData?['message'] ?? e.message ?? 'Failed to update status'};
    } catch (e) {
      print('❌ Error updating order status: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Confirm COD payment received (for Cash on Delivery orders)
  Future<Map<String, dynamic>> confirmCodPayment(int orderId) async {
    print('🔄 Confirming COD payment for order $orderId');

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/vendor/orders/$orderId/confirm-cod-payment');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local state
        final updatedOrders = state.orders.map((order) {
          if (order.id == orderId) {
            return order.copyWith(status: 'delivered');
          }
          return order;
        }).toList();

        state = state.copyWith(orders: updatedOrders);
        print('✅ COD payment confirmed');
        return {'success': true, 'message': response.data['message'] ?? 'Payment confirmed successfully'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed to confirm payment'};
    } on DioException catch (e) {
      print('❌ DioException confirming COD payment: ${e.message}');
      final message = e.response?.data?['message'] ?? e.message ?? 'Failed to confirm payment';
      return {'success': false, 'message': message};
    } catch (e) {
      print('❌ Error confirming COD payment: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}

final vendorOrdersProvider = StateNotifierProvider<VendorOrdersNotifier, VendorOrdersState>((ref) {
  return VendorOrdersNotifier(ref);
});

// ==================== ORDER DETAIL PROVIDER ====================
final vendorOrderDetailProvider = FutureProvider.family<OrderModel?, int>((ref, orderId) async {
  print('🔄 Fetching order detail for ID: $orderId');
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/orders/$orderId');

    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;

      if (data['success'] == true && data['order'] != null) {
        final order = OrderModel.fromJson(data['order'] as Map<String, dynamic>);
        print('✅ Order detail loaded');
        return order;
      }
    }
    return null;
  } on DioException catch (e) {
    print('❌ DioException fetching order detail: ${e.message}');
    return null;
  } catch (e) {
    print('❌ Error fetching order detail: $e');
    return null;
  }
});

// ==================== CREATE LISTING STATE & NOTIFIER ====================
class CreateListingState {
  final bool isLoading;
  final List<CategoryModel> categories; // All categories with children
  final String? error;

  CreateListingState({
    this.isLoading = false,
    this.categories = const [],
    this.error,
  });

  CreateListingState copyWith({
    bool? isLoading,
    List<CategoryModel>? categories,
    String? error,
  }) {
    return CreateListingState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      error: error,
    );
  }

  // Get only subcategories (categories with parent_id != null) for vendor selection
  List<CategoryModel> get subcategories {
    final List<CategoryModel> subs = [];
    for (final parent in categories) {
      subs.addAll(parent.children);
    }
    return subs;
  }

  // Get categories grouped by parent for UI display
  Map<String, List<CategoryModel>> get categoriesByParent {
    final Map<String, List<CategoryModel>> grouped = {};
    for (final parent in categories) {
      if (parent.children.isNotEmpty) {
        grouped[parent.name] = parent.children;
      }
    }
    return grouped;
  }
}

class CreateListingNotifier extends StateNotifier<CreateListingState> {
  final Ref ref;

  CreateListingNotifier(this.ref) : super(CreateListingState());

  Future<void> loadCategories() async {
    print('🔄 CreateListingNotifier: Loading categories for product creation...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);

      // Use the existing categories endpoint which returns parent categories with nested children
      final response = await api.get(ApiEndpoints.categories);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;

        if (data['success'] == true && data['data'] != null) {
          final categoriesData = data['data'] as List;
          final categories = categoriesData
              .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
              .toList();

          state = state.copyWith(isLoading: false, categories: categories);
          print('✅ Loaded ${categories.length} parent categories with subcategories');

          // Log subcategories count
          int subCount = 0;
          for (var cat in categories) {
            subCount += cat.children.length;
          }
          print('   Total subcategories: $subCount');
          return;
        }
      }

      state = state.copyWith(isLoading: false, categories: []);
    } on DioException catch (e) {
      print('❌ DioException loading categories: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load categories',
      );
    } catch (e) {
      print('❌ Error loading categories: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createListing({
    required String title,
    required String description,
    required double price,
    required int categoryId,
    required int quantity,
    required String condition,
    required List<File> images,
    double? weight,
    List<Map<String, dynamic>>? variations, // Product variants (color/size)
  }) async {
    print('🔄 Creating new listing: $title');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);

      // Create FormData for multipart upload
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'price': price.toString(),
        'category_id': categoryId.toString(),
        'stock': quantity.toString(),
        'condition': condition,
        if (weight != null) 'weight': weight.toString(),
      });

      // Add images
      for (int i = 0; i < images.length; i++) {
        final file = images[i];
        formData.files.add(MapEntry(
          'images[$i]',
          await MultipartFile.fromFile(
            file.path,
            filename: 'image_$i.jpg',
          ),
        ));
      }

      // Add variations if provided
      if (variations != null && variations.isNotEmpty) {
        for (int i = 0; i < variations.length; i++) {
          final v = variations[i];
          if (v['color'] != null) formData.fields.add(MapEntry('variations[$i][color]', v['color'].toString()));
          if (v['size'] != null) formData.fields.add(MapEntry('variations[$i][size]', v['size'].toString()));
          if (v['sku'] != null) formData.fields.add(MapEntry('variations[$i][sku]', v['sku'].toString()));
          formData.fields.add(MapEntry('variations[$i][price]', (v['price'] ?? price).toString()));
          if (v['sale_price'] != null) formData.fields.add(MapEntry('variations[$i][sale_price]', v['sale_price'].toString()));
          formData.fields.add(MapEntry('variations[$i][stock]', (v['stock'] ?? 1).toString()));
        }
        print('📦 Adding ${variations.length} variants to listing');
      }

      final response = await api.post(
        '/api/vendor/listings',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      state = state.copyWith(isLoading: false);

      if (response.statusCode == 201 && response.data['success'] == true) {
        print('✅ Listing created successfully');
        // Refresh vendor listings
        ref.read(vendorListingsProvider.notifier).loadListings(refresh: true);
        // Refresh dashboard stats
        ref.invalidate(vendorDashboardProvider);
        return true;
      }

      state = state.copyWith(error: response.data['message'] ?? 'Failed to create listing');
      return false;
    } on DioException catch (e) {
      print('❌ DioException creating listing: ${e.message}');
      print('❌ Response: ${e.response?.data}');

      final data = e.response?.data;
      String errorMessage = 'Failed to create listing';

      // Handle specific error cases
      if (e.response?.statusCode == 403 && data is Map) {
        if (data['requires_onboarding'] == true) {
          errorMessage = data['message'] ?? 'Complete vendor onboarding first.';
        } else if (data['requires_approval'] == true) {
          errorMessage = data['message'] ?? 'Your vendor application is pending approval.';
        } else {
          errorMessage = data['message'] ?? 'You are not authorized to create listings.';
        }
      } else if (data is Map && data['message'] != null) {
        errorMessage = data['message'];
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      print('❌ Error creating listing: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateListing({
    required int listingId,
    required String title,
    required String description,
    required double price,
    required int categoryId,
    required int quantity,
    required String condition,
    List<File>? newImages,
    List<int>? deleteImageIds,
  }) async {
    print('🔄 Updating listing $listingId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);

      // Create FormData for multipart upload
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'price': price.toString(),
        'category_id': categoryId.toString(),
        'quantity': quantity.toString(),
        'condition': condition,
        '_method': 'PUT', // Laravel method spoofing for PUT with multipart
      });

      // Add new images if any
      if (newImages != null) {
        for (int i = 0; i < newImages.length; i++) {
          final file = newImages[i];
          formData.files.add(MapEntry(
            'images[$i]',
            await MultipartFile.fromFile(
              file.path,
              filename: 'image_$i.jpg',
            ),
          ));
        }
      }

      // Add delete image IDs if any
      if (deleteImageIds != null && deleteImageIds.isNotEmpty) {
        for (int i = 0; i < deleteImageIds.length; i++) {
          formData.fields.add(MapEntry('delete_images[$i]', deleteImageIds[i].toString()));
        }
      }

      final response = await api.post(
        '/api/vendor/listings/$listingId',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      state = state.copyWith(isLoading: false);

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Listing updated successfully');
        // Refresh vendor listings
        ref.read(vendorListingsProvider.notifier).loadListings(refresh: true);
        return true;
      }

      state = state.copyWith(error: response.data['message'] ?? 'Failed to update listing');
      return false;
    } on DioException catch (e) {
      print('❌ DioException updating listing: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to update listing',
      );
      return false;
    } catch (e) {
      print('❌ Error updating listing: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final createListingProvider = StateNotifierProvider<CreateListingNotifier, CreateListingState>((ref) {
  return CreateListingNotifier(ref);
});

// ==================== UPDATE PROFILE NOTIFIER ====================
class UpdateProfileNotifier extends StateNotifier<bool> {
  final Ref ref;

  UpdateProfileNotifier(this.ref) : super(false);

  Future<bool> updateProfile({
    File? logo,
    File? avatar,
    String? businessName,
    String? businessDescription,
    String? businessAddress,
    String? businessPhone,
  }) async {
    print('🔄 Updating vendor profile');
    state = true; // Loading

    try {
      final api = ref.read(apiClientProvider);

      final formData = FormData.fromMap({
        if (businessName != null) 'business_name': businessName,
        if (businessDescription != null) 'description': businessDescription,
        if (businessAddress != null) 'address': businessAddress,
        if (businessPhone != null) 'phone': businessPhone,
      });

      // Add store logo
      if (logo != null) {
        formData.files.add(MapEntry(
          'logo',
          await MultipartFile.fromFile(logo.path, filename: 'logo.jpg'),
        ));
      }

      // Add user avatar/profile picture
      if (avatar != null) {
        formData.files.add(MapEntry(
          'avatar',
          await MultipartFile.fromFile(avatar.path, filename: 'avatar.jpg'),
        ));
      }

      final response = await api.post(
        '/api/vendor/profile',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      state = false;

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Profile updated');
        // Refresh user data
        ref.invalidate(currentUserProvider);
        ref.invalidate(vendorProfileProvider);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating profile: $e');
      state = false;
      return false;
    }
  }
}

final updateProfileProvider = StateNotifierProvider<UpdateProfileNotifier, bool>((ref) {
  return UpdateProfileNotifier(ref);
});

// ==================== VENDOR ANALYTICS STATE & NOTIFIER ====================
class VendorAnalyticsState {
  final bool isLoading;
  final String? error;
  final double totalRevenue;
  final double revenueGrowth;
  final int totalOrders;
  final int productsSold;
  final double averageOrderValue;
  final int totalViews;
  final double conversionRate;
  final double fulfillmentRate;
  final double averageRating;
  final double responseRate;
  final int pendingOrders;
  final int processingOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final List<Map<String, dynamic>> topProducts;

  VendorAnalyticsState({
    this.isLoading = false,
    this.error,
    this.totalRevenue = 0,
    this.revenueGrowth = 0,
    this.totalOrders = 0,
    this.productsSold = 0,
    this.averageOrderValue = 0,
    this.totalViews = 0,
    this.conversionRate = 0,
    this.fulfillmentRate = 0,
    this.averageRating = 0,
    this.responseRate = 0,
    this.pendingOrders = 0,
    this.processingOrders = 0,
    this.shippedOrders = 0,
    this.deliveredOrders = 0,
    this.topProducts = const [],
  });

  VendorAnalyticsState copyWith({
    bool? isLoading,
    String? error,
    double? totalRevenue,
    double? revenueGrowth,
    int? totalOrders,
    int? productsSold,
    double? averageOrderValue,
    int? totalViews,
    double? conversionRate,
    double? fulfillmentRate,
    double? averageRating,
    double? responseRate,
    int? pendingOrders,
    int? processingOrders,
    int? shippedOrders,
    int? deliveredOrders,
    List<Map<String, dynamic>>? topProducts,
  }) {
    return VendorAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
      totalOrders: totalOrders ?? this.totalOrders,
      productsSold: productsSold ?? this.productsSold,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      totalViews: totalViews ?? this.totalViews,
      conversionRate: conversionRate ?? this.conversionRate,
      fulfillmentRate: fulfillmentRate ?? this.fulfillmentRate,
      averageRating: averageRating ?? this.averageRating,
      responseRate: responseRate ?? this.responseRate,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      processingOrders: processingOrders ?? this.processingOrders,
      shippedOrders: shippedOrders ?? this.shippedOrders,
      deliveredOrders: deliveredOrders ?? this.deliveredOrders,
      topProducts: topProducts ?? this.topProducts,
    );
  }
}

class VendorAnalyticsNotifier extends StateNotifier<VendorAnalyticsState> {
  final Ref ref;

  VendorAnalyticsNotifier(this.ref) : super(VendorAnalyticsState());

  Future<void> loadAnalytics({int days = 30}) async {
    print('🔄 VendorAnalyticsNotifier: Loading analytics for $days days');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiClientProvider);

      // First get dashboard stats as base data
      final dashboardResponse = await api.get('/api/vendor/dashboard');

      if (dashboardResponse.statusCode == 200 && dashboardResponse.data is Map) {
        final data = dashboardResponse.data as Map;

        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;

          // Calculate some metrics from available data
          final totalOrders = _parseInt(stats['total_orders']);
          final deliveredOrders = _parseInt(stats['delivered_orders']);
          final totalRevenue = _parseDouble(stats['total_revenue']);

          state = state.copyWith(
            isLoading: false,
            totalRevenue: totalRevenue,
            revenueGrowth: 12.5, // TODO: Calculate from API when available
            totalOrders: totalOrders,
            productsSold: _parseInt(stats['products_sold']) > 0
                ? _parseInt(stats['products_sold'])
                : deliveredOrders * 2, // Estimate
            averageOrderValue: totalOrders > 0 ? totalRevenue / totalOrders : 0,
            totalViews: _parseInt(stats['total_views']),
            conversionRate: _parseInt(stats['total_views']) > 0
                ? (totalOrders / _parseInt(stats['total_views'])) * 100
                : 0,
            fulfillmentRate: totalOrders > 0
                ? (deliveredOrders / totalOrders) * 100
                : 0,
            averageRating: _parseDouble(stats['average_rating']),
            responseRate: 95.0, // TODO: Calculate from API when available
            pendingOrders: _parseInt(stats['pending_orders']),
            processingOrders: _parseInt(stats['processing_orders']),
            shippedOrders: _parseInt(stats['shipped_orders']),
            deliveredOrders: deliveredOrders,
            topProducts: [], // TODO: Get from API when available
          );
          print('✅ Analytics loaded successfully');
          return;
        }
      }

      state = state.copyWith(isLoading: false, error: 'Failed to load analytics');
    } on DioException catch (e) {
      print('❌ DioException loading analytics: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load analytics',
      );
    } catch (e) {
      print('❌ Error loading analytics: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

final vendorAnalyticsProvider = StateNotifierProvider<VendorAnalyticsNotifier, VendorAnalyticsState>((ref) {
  return VendorAnalyticsNotifier(ref);
});

// ==================== VENDOR ONBOARDING STATE & NOTIFIER ====================
class VendorOnboardingState {
  final bool isLoading;
  final String? error;
  final bool success;
  final VendorProfileModel? currentProfile;

  VendorOnboardingState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.currentProfile,
  });

  VendorOnboardingState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
    VendorProfileModel? currentProfile,
  }) {
    return VendorOnboardingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
      currentProfile: currentProfile ?? this.currentProfile,
    );
  }
}

class VendorOnboardingNotifier extends StateNotifier<VendorOnboardingState> {
  final Ref ref;

  VendorOnboardingNotifier(this.ref) : super(VendorOnboardingState());

  Future<void> checkStatus() async {
    // If we already have a successful submission in this session, don't re-show loading
    if (state.currentProfile != null && state.success) {
      print('⏭️ VendorOnboardingNotifier: Status already known, skipping re-check');
      return;
    }

    print('🔄 VendorOnboardingNotifier: Checking status...');
    state = state.copyWith(isLoading: state.currentProfile == null, error: null);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/api/vendor/onboard/status');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = VendorProfileModel.fromJson(response.data['vendor_profile']);
        state = state.copyWith(isLoading: false, currentProfile: profile);
        print('✅ Vendor application found: ${profile.vettingStatus}');
      } else {
        state = state.copyWith(isLoading: false, currentProfile: null);
      }
    } on DioException catch (e) {
      print('❌ DioException checking status: ${e.message}');
      state = state.copyWith(
        isLoading: false, 
        currentProfile: null,
        error: e.response?.statusCode == 404 ? null : (e.response?.data?['message'] ?? e.message),
      );
    } catch (e) {
      print('❌ Error checking status: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitOnboarding({
    required String vendorType,
    required String businessName,
    required String country,
    required String city,
    required String address,
    required String preferredCurrency,
    double? annualTurnover,
    required File nationalIdFront,
    required File nationalIdBack,
    required File bankStatement,
    required File proofOfAddress,
    required String guarantorName,
    required String guarantorPhone,
    required File guarantorId,
    File? companyRegistration,
    File? taxCertificate,
  }) async {
    print('🔄 VendorOnboardingNotifier: Submitting onboarding application...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiClientProvider);

      // Helper to get filename with proper extension
      String getFileName(File file, String baseName) {
        final ext = file.path.split('.').last.toLowerCase();
        return '$baseName.$ext';
      }

      final formData = FormData.fromMap({
        'vendor_type': vendorType,
        'business_name': businessName,
        'country': country,
        'city': city,
        'address': address,
        'preferred_currency': preferredCurrency,
        if (annualTurnover != null) 'annual_turnover': annualTurnover.toString(),
        'guarantor_name': guarantorName,
        'guarantor_phone': guarantorPhone,
        'terms': '1',
      });

      // Add files with proper extensions detected from actual file paths
      formData.files.addAll([
        MapEntry('national_id_front', await MultipartFile.fromFile(
          nationalIdFront.path,
          filename: getFileName(nationalIdFront, 'id_front'),
        )),
        MapEntry('national_id_back', await MultipartFile.fromFile(
          nationalIdBack.path,
          filename: getFileName(nationalIdBack, 'id_back'),
        )),
        MapEntry('bank_statement', await MultipartFile.fromFile(
          bankStatement.path,
          filename: getFileName(bankStatement, 'bank_statement'),
        )),
        MapEntry('proof_of_address', await MultipartFile.fromFile(
          proofOfAddress.path,
          filename: getFileName(proofOfAddress, 'proof_address'),
        )),
        MapEntry('guarantor_id', await MultipartFile.fromFile(
          guarantorId.path,
          filename: getFileName(guarantorId, 'guarantor_id'),
        )),
      ]);

      if (companyRegistration != null) {
        formData.files.add(MapEntry('company_registration', await MultipartFile.fromFile(
          companyRegistration.path,
          filename: getFileName(companyRegistration, 'comp_reg'),
        )));
      }
      if (taxCertificate != null) {
        formData.files.add(MapEntry('tax_certificate', await MultipartFile.fromFile(
          taxCertificate.path,
          filename: getFileName(taxCertificate, 'tax_cert'),
        )));
      }

      print('📤 Uploading ${formData.files.length} files...');

      final response = await api.post(
        '/api/vendor/onboard',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 5), // Extended timeout for file uploads
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = VendorProfileModel.fromJson(response.data['vendor_profile']);
        state = state.copyWith(isLoading: false, success: true, currentProfile: profile);
        print('✅ Vendor onboarding submitted successfully');
        
        // Refresh user to sync the new vendor role
        ref.read(authProvider.notifier).refreshUser();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response.data['message'] ?? 'Submission failed');
        return false;
      }
    } on DioException catch (e) {
      print('❌ DioException submitting onboarding: ${e.message}');
      print('   Status: ${e.response?.statusCode}');
      print('   Response: ${e.response?.data}');
      print('   Type: ${e.type}');

      String errorMessage = 'Failed to submit application';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Upload timed out. Please check your internet connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e.response?.statusCode == 422) {
        // Validation error
        final errors = e.response?.data?['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first.toString();
          }
        } else {
          errorMessage = e.response?.data?['message'] ?? 'Validation failed';
        }
      } else if (e.response?.statusCode == 413) {
        errorMessage = 'Files are too large. Please use smaller images.';
      } else if (e.response?.statusCode == 302) {
        errorMessage = 'Session expired. Please login again.';
      } else if (e.response?.statusCode == 401) {
        errorMessage = 'Not authenticated. Please login again.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data?['message'] ?? errorMessage;
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      print('❌ Error submitting onboarding: $e');
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred: ${e.toString()}');
      return false;
    }
  }
}

final vendorOnboardingProvider = StateNotifierProvider<VendorOnboardingNotifier, VendorOnboardingState>((ref) {
  return VendorOnboardingNotifier(ref);
});
