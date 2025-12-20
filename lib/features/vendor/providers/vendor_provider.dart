// Minimal vendor providers and model typedefs to satisfy vendor screens.
// These are lightweight stubs — replace with real implementations when integrating API.
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export commonly used models so screens that import this provider file
// can reference the types directly (e.g. `VendorProfileModel`).
export '../../../shared/models/user_model.dart' show VendorProfileModel;
export '../../../shared/models/listing_model.dart' show ListingModel;
export '../../../shared/models/order_model.dart' show OrderModel, OrderItemModel, ShippingAddressInfo;

import 'dart:io';

import '../../../shared/models/user_model.dart' show VendorProfileModel;
import '../../../shared/models/listing_model.dart' show ListingModel;
import '../../../shared/models/order_model.dart' show OrderModel, OrderItemModel, ShippingAddressInfo;
import '../../../shared/models/category_model.dart' show CategoryModel;
import '../../auth/providers/auth_provider.dart' show authProvider, currentUserProvider;

// Type aliases expected by vendor UI
typedef VendorOrderModel = OrderModel;
typedef ShippingInfo = ShippingAddressInfo;

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
    this.totalRevenue = 0.0,
    this.monthlyRevenue = 0.0,
    this.pendingBalance = 0.0,
    this.availableBalance = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalViews = 0,
  });
}

// Providers used by vendor screens (stubs that return empty/default data).
final vendorDashboardProvider = FutureProvider<VendorDashboardStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  final vendor = user?.vendorProfile;
  if (vendor == null) return VendorDashboardStats();
  return VendorDashboardStats(averageRating: vendor.rating ?? 0.0, totalReviews: vendor.totalSales ?? 0);
});

final vendorRecentOrdersProvider = FutureProvider<List<VendorOrderModel>>((ref) async {
  return <VendorOrderModel>[];
});

final vendorProfileProvider = FutureProvider<VendorProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  return user?.vendorProfile;
});

class VendorListingsState {
  final bool isLoading;
  final List<ListingModel> listings;
  final String? error;

  VendorListingsState({this.isLoading = false, this.listings = const [], this.error});

  VendorListingsState copyWith({bool? isLoading, List<ListingModel>? listings, String? error}) {
    return VendorListingsState(
      isLoading: isLoading ?? this.isLoading,
      listings: listings ?? this.listings,
      error: error,
    );
  }
}

class VendorListingsNotifier extends StateNotifier<VendorListingsState> {
  VendorListingsNotifier(): super(VendorListingsState());

  Future<void> loadListings({String? status, bool refresh = false, int perPage = 20}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // stub: replace with API call
      await Future.delayed(const Duration(milliseconds: 200));
      state = state.copyWith(isLoading: false, listings: []);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleListingStatus(int listingId) async {
    // stub: pretend success if exists
    final exists = state.listings.any((l) => l.id == listingId);
    return exists;
  }

  Future<bool> deleteListing(int listingId) async {
    state = state.copyWith(listings: state.listings.where((l) => l.id != listingId).toList());
    return true;
  }
}

final vendorListingsProvider = StateNotifierProvider<VendorListingsNotifier, VendorListingsState>((ref) {
  return VendorListingsNotifier();
});

class VendorOrdersState {
  final bool isLoading;
  final List<OrderModel> orders;
  final String? error;

  VendorOrdersState({this.isLoading = false, this.orders = const [], this.error});

  VendorOrdersState copyWith({bool? isLoading, List<OrderModel>? orders, String? error}) {
    return VendorOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      error: error,
    );
  }
}

class VendorOrdersNotifier extends StateNotifier<VendorOrdersState> {
  VendorOrdersNotifier(): super(VendorOrdersState());

  Future<void> loadOrders({String? status, bool refresh = false, int perPage = 20}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // stub: replace with API call
      await Future.delayed(const Duration(milliseconds: 200));
      state = state.copyWith(isLoading: false, orders: []);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    final exists = state.orders.any((o) => o.id == orderId);
    return exists;
  }
}

final vendorOrdersProvider = StateNotifierProvider<VendorOrdersNotifier, VendorOrdersState>((ref) {
  return VendorOrdersNotifier();
});

final vendorOrderDetailProvider = FutureProvider.family<OrderModel?, int>((ref, orderId) async {
  return null;
});

class CreateListingState {
  final bool isLoading;
  final List<CategoryModel> categories;
  final String? error;

  CreateListingState({this.isLoading = false, this.categories = const [], this.error});

  CreateListingState copyWith({bool? isLoading, List<CategoryModel>? categories, String? error}) {
    return CreateListingState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      error: error,
    );
  }
}

class CreateListingNotifier extends StateNotifier<CreateListingState> {
  CreateListingNotifier(): super(CreateListingState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // stub: replace with API call
      await Future.delayed(const Duration(milliseconds: 100));
      state = state.copyWith(isLoading: false, categories: []);
    } catch (e) {
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
  }) async {
    // stub: implement API call
    return true;
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
    // stub: implement API call
    return true;
  }
}

final createListingProvider = StateNotifierProvider<CreateListingNotifier, CreateListingState>((ref) => CreateListingNotifier());

class UpdateProfileNotifier extends StateNotifier<bool> {
  UpdateProfileNotifier(): super(false);

  Future<bool> updateProfile({
    File? logo,
    String? businessName,
    String? businessDescription,
    String? businessAddress,
    String? businessPhone,
  }) async {
    // stub: perform upload/update
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }
}

final updateProfileProvider = StateNotifierProvider<UpdateProfileNotifier, bool>((ref) => UpdateProfileNotifier());
