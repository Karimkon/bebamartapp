// lib/features/buyer/providers/order_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

// ==========================================
// ORDER STATE
// ==========================================
class OrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int lastPage;
  final bool hasMore;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.hasMore = false,
  });

  int get orderCount => orders.length;
  bool get isEmpty => orders.isEmpty;

  OrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? lastPage,
    bool? hasMore,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ==========================================
// CHECKOUT STATE
// ==========================================
class CheckoutState {
  final List<ShippingAddressModel> addresses;
  final ShippingAddressModel? selectedAddress;
  final String? selectedPaymentMethod;
  final String? notes;
  final bool isLoading;
  final bool isPlacingOrder;
  final String? error;
  final OrderModel? placedOrder;

  const CheckoutState({
    this.addresses = const [],
    this.selectedAddress,
    this.selectedPaymentMethod,
    this.notes,
    this.isLoading = false,
    this.isPlacingOrder = false,
    this.error,
    this.placedOrder,
  });

  bool get canPlaceOrder => selectedAddress != null && selectedPaymentMethod != null;

  CheckoutState copyWith({
    List<ShippingAddressModel>? addresses,
    ShippingAddressModel? selectedAddress,
    String? selectedPaymentMethod,
    String? notes,
    bool? isLoading,
    bool? isPlacingOrder,
    String? error,
    OrderModel? placedOrder,
  }) {
    return CheckoutState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      error: error,
      placedOrder: placedOrder ?? this.placedOrder,
    );
  }
}

// ==========================================
// ORDERS NOTIFIER
// ==========================================
class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiClient _api;

  OrdersNotifier(this._api) : super(const OrdersState());

  Future<void> loadOrders({bool refresh = false}) async {
    if (state.isLoading) return;
    
    print('📦 Loading orders...');
    
    final page = refresh ? 1 : state.currentPage;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get(
        ApiEndpoints.orders,
        queryParameters: {'page': page},
      );
      print('📦 Orders response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        
        if (data['success'] == true) {
          final ordersData = data['data'] as List? ?? [];
          final meta = data['meta'] as Map? ?? {};
          
          final orders = ordersData.map((item) {
            if (item is Map<String, dynamic>) {
              return OrderModel.fromJson(item);
            }
            return null;
          }).whereType<OrderModel>().toList();

          state = state.copyWith(
            orders: refresh ? orders : [...state.orders, ...orders],
            currentPage: meta['current_page'] ?? page,
            lastPage: meta['last_page'] ?? 1,
            hasMore: (meta['current_page'] ?? page) < (meta['last_page'] ?? 1),
            isLoading: false,
          );
          print('✅ Orders loaded: ${orders.length} items');
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      print('❌ Orders load error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to load orders',
      );
    } catch (e) {
      print('❌ Orders load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
    await loadOrders();
  }

  Future<void> refresh() async {
    await loadOrders(refresh: true);
  }
}

// ==========================================
// CHECKOUT NOTIFIER
// ==========================================
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final ApiClient _api;

  CheckoutNotifier(this._api) : super(const CheckoutState());

  Future<void> loadCheckoutData() async {
    print('🛒 Loading checkout data...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get(ApiEndpoints.addresses);
      print('📦 Addresses response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        
        if (data['success'] == true) {
          final addressesData = data['data'] as List? ?? [];
          
          final addresses = addressesData.map((item) {
            if (item is Map<String, dynamic>) {
              return ShippingAddressModel.fromJson(item);
            }
            return null;
          }).whereType<ShippingAddressModel>().toList();

          // Select default address
          ShippingAddressModel? defaultAddress;
          try {
            defaultAddress = addresses.firstWhere((a) => a.isDefault);
          } catch (e) {
            if (addresses.isNotEmpty) {
              defaultAddress = addresses.first;
            }
          }

          state = state.copyWith(
            addresses: addresses,
            selectedAddress: defaultAddress,
            isLoading: false,
          );
          print('✅ Checkout data loaded: ${addresses.length} addresses');
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      print('❌ Checkout load error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to load checkout data',
      );
    } catch (e) {
      print('❌ Checkout load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectAddress(ShippingAddressModel address) {
    state = state.copyWith(selectedAddress: address);
  }

  void selectPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  Future<OrderModel?> placeOrder() async {
    if (!state.canPlaceOrder) {
      state = state.copyWith(error: 'Please select address and payment method');
      return null;
    }

    print('🛒 Placing order...');
    state = state.copyWith(isPlacingOrder: true, error: null);

    try {
      final response = await _api.post(
        ApiEndpoints.placeOrder,
        data: {
          'shipping_address_id': state.selectedAddress!.id,
          'payment_method': state.selectedPaymentMethod,
          'notes': state.notes,
        },
      );
      print('📦 Place order response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data['success'] == true && data['data'] != null) {
          final order = OrderModel.fromJson(data['data']);
          
          state = state.copyWith(
            isPlacingOrder: false,
            placedOrder: order,
          );
          print('✅ Order placed: ${order.orderNumber}');
          return order;
        }
      }
      
      state = state.copyWith(
        isPlacingOrder: false,
        error: response.data['message'] ?? 'Failed to place order',
      );
      return null;
    } on DioException catch (e) {
      print('❌ Place order error: ${e.message}');
      state = state.copyWith(
        isPlacingOrder: false,
        error: e.response?.data?['message'] ?? e.message ?? 'Failed to place order',
      );
      return null;
    } catch (e) {
      print('❌ Place order error: $e');
      state = state.copyWith(
        isPlacingOrder: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<ShippingAddressModel?> addAddress({
    required String recipientName,
    required String recipientPhone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? stateRegion,
    String? postalCode,
    String? country,
    String? label,
    String? deliveryInstructions,
    bool isDefault = false,
  }) async {
    print('📍 Adding new address...');

    try {
      final response = await _api.post(
        ApiEndpoints.addresses,
        data: {
          'recipient_name': recipientName,
          'recipient_phone': recipientPhone,
          'address_line_1': addressLine1,
          'address_line_2': addressLine2,
          'city': city,
          'state_region': stateRegion,
          'postal_code': postalCode,
          'country': country ?? 'Uganda',
          'label': label,
          'delivery_instructions': deliveryInstructions,
          'is_default': isDefault,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data['success'] == true && data['data'] != null) {
          final address = ShippingAddressModel.fromJson(data['data']);
          
          // Refresh addresses
          await loadCheckoutData();
          
          print('✅ Address added');
          return address;
        }
      }
      return null;
    } catch (e) {
      print('❌ Add address error: $e');
      return null;
    }
  }

  void reset() {
    state = const CheckoutState();
  }
}

// ==========================================
// PROVIDERS
// ==========================================
final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = OrdersNotifier(api);
  
  // Auto-load orders when provider is created
  notifier.loadOrders();
  
  return notifier;
});

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  final api = ref.watch(apiClientProvider);
  return CheckoutNotifier(api);
});

// Single order detail provider
final orderDetailProvider = FutureProvider.family<OrderModel?, int>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get(ApiEndpoints.orderDetail(orderId));

    if (response.statusCode == 200 && response.data is Map) {
      if (response.data['success'] == true && response.data['data'] != null) {
        return OrderModel.fromJson(response.data['data']);
      }
    }
    return null;
  } catch (e) {
    print('❌ Error loading order detail: $e');
    return null;
  }
});

// Confirm delivery for COD orders
Future<Map<String, dynamic>> confirmDelivery(ApiClient api, int orderId) async {
  try {
    final response = await api.post(ApiEndpoints.orderConfirmDelivery(orderId));

    if (response.statusCode == 200 && response.data is Map) {
      return {
        'success': response.data['success'] ?? false,
        'message': response.data['message'] ?? 'Delivery confirmed',
        'order': response.data['data'] != null
            ? OrderModel.fromJson(response.data['data'])
            : null,
      };
    }
    return {
      'success': false,
      'message': response.data?['message'] ?? 'Failed to confirm delivery',
    };
  } on DioException catch (e) {
    return {
      'success': false,
      'message': e.response?.data?['message'] ?? e.message ?? 'Failed to confirm delivery',
    };
  } catch (e) {
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}