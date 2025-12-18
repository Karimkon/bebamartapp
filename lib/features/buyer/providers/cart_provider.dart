// lib/features/buyer/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

// ==========================================
// CART ITEM MODEL
// ==========================================
class CartItem {
  final int listingId;
  final String title;
  final double price;
  final int quantity;
  final String? thumbnail;
  final int? variantId;
  final Map<String, dynamic>? attributes;
  final int stock;

  CartItem({
    required this.listingId,
    required this.title,
    required this.price,
    required this.quantity,
    this.thumbnail,
    this.variantId,
    this.attributes,
    this.stock = 0,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      listingId: json['listing_id'] ?? 0,
      title: json['title'] ?? 'Unknown Product',
      price: json['price'] is String ? double.tryParse(json['price']) ?? 0.0 : (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      thumbnail: json['thumbnail'],
      variantId: json['variant_id'],
      attributes: json['attributes'],
      stock: json['stock'] ?? 0,
    );
  }

  double get total => price * quantity;

  String get formattedPrice => 'UGX ${price.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';
}

// ==========================================
// CART STATE
// ==========================================
class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.subtotal = 0,
    this.shipping = 0,
    this.tax = 0,
    this.total = 0,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  String get formattedSubtotal => 'UGX ${subtotal.toStringAsFixed(0)}';
  String get formattedShipping => 'UGX ${shipping.toStringAsFixed(0)}';
  String get formattedTax => 'UGX ${tax.toStringAsFixed(0)}';
  String get formattedTotal => 'UGX ${total.toStringAsFixed(0)}';

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    double? subtotal,
    double? shipping,
    double? tax,
    double? total,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      subtotal: subtotal ?? this.subtotal,
      shipping: shipping ?? this.shipping,
      tax: tax ?? this.tax,
      total: total ?? this.total,
    );
  }
}

// ==========================================
// CART NOTIFIER
// ==========================================
class CartNotifier extends StateNotifier<CartState> {
  final ApiClient _api;

  CartNotifier(this._api) : super(const CartState());

  Future<void> loadCart() async {
    print('🛒 Loading cart...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get(ApiEndpoints.cart);
      print('📦 Cart response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        
        if (data['success'] == true) {
          final cartData = data['data'] ?? {};
          final itemsList = cartData['items'] as List? ?? [];
          
          final items = itemsList.map((item) => CartItem.fromJson(item)).toList();

          state = state.copyWith(
            items: items,
            subtotal: (cartData['subtotal'] ?? 0).toDouble(),
            shipping: (cartData['shipping'] ?? 0).toDouble(),
            tax: (cartData['tax'] ?? 0).toDouble(),
            total: (cartData['total'] ?? 0).toDouble(),
            isLoading: false,
          );
          print('✅ Cart loaded: ${items.length} items');
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      print('❌ Cart load error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to load cart',
      );
    } catch (e) {
      print('❌ Cart load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> addToCart(int listingId, int quantity, {int? variantId, Map<String, dynamic>? attributes}) async {
    print('🛒 Adding to cart: listing=$listingId, qty=$quantity');
    
    try {
      final response = await _api.post(
        ApiEndpoints.cartAdd(listingId),
        data: {
          'quantity': quantity,
          if (variantId != null) 'variant_id': variantId,
          if (attributes != null) 'attributes': attributes,
        },
      );

      print('📦 Add to cart response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        await loadCart();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Add to cart error: $e');
      rethrow;
    }
  }

  Future<bool> updateQuantity(int listingId, int quantity, {int? variantId}) async {
    print('🛒 Updating quantity: listing=$listingId, qty=$quantity');
    
    try {
      final response = await _api.post(
        ApiEndpoints.cartUpdate(listingId),
        data: {
          'quantity': quantity,
          if (variantId != null) 'variant_id': variantId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        await loadCart();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Update quantity error: $e');
      rethrow;
    }
  }

  Future<bool> removeFromCart(int listingId, {int? variantId}) async {
    print('🛒 Removing from cart: listing=$listingId');
    
    try {
      final response = await _api.delete(ApiEndpoints.cartRemove(listingId));

      if (response.statusCode == 200 && response.data['success'] == true) {
        await loadCart();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Remove from cart error: $e');
      rethrow;
    }
  }

  Future<bool> clearCart() async {
    print('🛒 Clearing cart...');
    
    try {
      final response = await _api.post(ApiEndpoints.cartClear);

      if (response.statusCode == 200 && response.data['success'] == true) {
        state = const CartState();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Clear cart error: $e');
      rethrow;
    }
  }
}

// ==========================================
// PROVIDERS
// ==========================================
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = CartNotifier(api);
  
  // Auto-load cart when provider is created
  notifier.loadCart();
  
  return notifier;
});

// Convenience providers
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});

final cartIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});