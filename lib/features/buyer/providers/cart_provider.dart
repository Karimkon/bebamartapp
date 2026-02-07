// lib/features/buyer/providers/cart_provider.dart
import 'dart:convert';  
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
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
  final double taxAmount;
  final String? taxDescription;

  CartItem({
    required this.listingId,
    required this.title,
    required this.price,
    required this.quantity,
    this.thumbnail,
    this.variantId,
    this.attributes,
    this.stock = 0,
    this.taxAmount = 0,
    this.taxDescription,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
  print('🔍 Parsing cart item JSON - Looking for image...');
  
  // Extract attributes if they exist
  Map<String, dynamic>? attributes;
  if (json['attributes'] != null) {
    if (json['attributes'] is Map) {
      attributes = Map<String, dynamic>.from(json['attributes']);
    } else if (json['attributes'] is String) {
      try {
        attributes = Map<String, dynamic>.from(jsonDecode(json['attributes']));
      } catch (e) {
        print('⚠️ Failed to parse attributes: $e');
      }
    }
  }

  // Try ALL possible image field names - in order of priority
  String? thumbnail;
  final List<String> imageFieldNames = [
    'primaryImage', 'primary_image', 'primaryImage', 'primary_image', // Home screen uses this
    'thumbnail', 'thumbnail_url', 'thumbnailUrl',
    'image', 'image_url', 'imageUrl',
    'featured_image', 'featuredImage',
    'cover_image', 'coverImage',
    'photo', 'photo_url', 'photoUrl',
  ];

  for (final fieldName in imageFieldNames) {
    if (json[fieldName] != null && json[fieldName].toString().trim().isNotEmpty) {
      final relativePath = json[fieldName].toString();
      // Construct full URL - check if it's already a full URL
      if (relativePath.startsWith('http')) {
        thumbnail = relativePath;
      } else if (relativePath.startsWith('/')) {
        thumbnail = '${AppConstants.baseUrl}$relativePath';
      } else {
        thumbnail = '${AppConstants.storageUrl}/$relativePath';
      }
      print('✅ Found image in field "$fieldName": $thumbnail');
      break;
    }
  }

  // If still no thumbnail, check nested product object
  if (thumbnail == null && json['product'] != null && json['product'] is Map) {
    final product = json['product'] as Map;
    print('🔍 Checking nested product object for image...');
    
    for (final fieldName in imageFieldNames) {
      if (product[fieldName] != null && product[fieldName].toString().trim().isNotEmpty) {
        thumbnail = product[fieldName].toString();
        print('✅ Found image in product.$fieldName: $thumbnail');
        break;
      }
    }
  }

  // If still no thumbnail, check images array
  if (thumbnail == null && json['images'] != null && json['images'] is List) {
    final images = json['images'] as List;
    if (images.isNotEmpty) {
      final firstImage = images.first;
      if (firstImage is String) {
        thumbnail = firstImage;
        print('✅ Found image in images[0] (String): $thumbnail');
      } else if (firstImage is Map) {
        // Check common image object field names
        final imageMap = firstImage as Map<String, dynamic>;
        final List<String> imageObjectFields = ['url', 'full_path', 'path', 'src', 'link'];
        
        for (final field in imageObjectFields) {
          if (imageMap[field] != null && imageMap[field].toString().trim().isNotEmpty) {
            thumbnail = imageMap[field].toString();
            print('✅ Found image in images[0].$field: $thumbnail');
            break;
          }
        }
      }
    }
  }

  // Last resort: check product.images
  if (thumbnail == null && json['product'] != null && json['product'] is Map) {
    final product = json['product'] as Map;
    if (product['images'] != null && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) {
        final firstImage = images.first;
        if (firstImage is String) {
          thumbnail = firstImage;
          print('✅ Found image in product.images[0] (String): $thumbnail');
        } else if (firstImage is Map) {
          final imageMap = firstImage as Map<String, dynamic>;
          if (imageMap['url'] != null) {
            thumbnail = imageMap['url'].toString();
            print('✅ Found image in product.images[0].url: $thumbnail');
          } else if (imageMap['full_path'] != null) {
            thumbnail = imageMap['full_path'].toString();
            print('✅ Found image in product.images[0].full_path: $thumbnail');
          }
        }
      }
    }
  }

  // Debug: if still no thumbnail
  if (thumbnail == null) {
    print('❌ No thumbnail found in any field!');
    print('   Available keys: ${json.keys}');
    if (json['product'] != null && json['product'] is Map) {
      print('   Product keys: ${(json['product'] as Map).keys}');
    }
  } else {
    print('   Final thumbnail URL: $thumbnail');
  }

  return CartItem(
    listingId: json['listing_id'] ?? json['product_id'] ?? json['id'] ?? 0,
    title: json['title'] ?? json['name'] ?? 'Unknown Product',
    price: json['price'] is String ? double.tryParse(json['price']) ?? 0.0 : (json['price'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 1,
    thumbnail: thumbnail,  // Use the extracted thumbnail
    variantId: json['variant_id'],
    attributes: attributes,
    stock: json['stock'] ?? json['available_stock'] ?? 0,
    taxAmount: json['tax_amount'] is String ? double.tryParse(json['tax_amount']) ?? 0.0 : (json['tax_amount'] ?? 0).toDouble(),
    taxDescription: json['tax_description'],
  );
}

  String get itemKey => '${listingId}_${variantId ?? 0}';

  double get total => price * quantity;
  double get taxTotal => taxAmount * quantity;

  String get formattedPrice => 'UGX ${NumberFormat('#,##0', 'en_US').format(price)}';
  String get formattedTotal => 'UGX ${NumberFormat('#,##0', 'en_US').format(total)}';
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
  final Set<String> selectedItemKeys;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.subtotal = 0,
    this.shipping = 0,
    this.tax = 0,
    this.total = 0,
    this.selectedItemKeys = const {},
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  // Selection getters
  List<CartItem> get selectedItems =>
      items.where((item) => selectedItemKeys.contains(item.itemKey)).toList();

  int get selectedItemCount =>
      selectedItems.fold(0, (sum, item) => sum + item.quantity);

  double get selectedSubtotal =>
      selectedItems.fold(0.0, (sum, item) => sum + item.total);

  double get selectedTax => selectedItems.fold(0.0, (sum, item) => sum + item.taxTotal);

  double get selectedTotal => selectedSubtotal + selectedTax;

  bool get allSelected =>
      items.isNotEmpty && selectedItemKeys.length == items.length;

  bool get hasSelection => selectedItemKeys.isNotEmpty;

  String get formattedSelectedSubtotal =>
      'UGX ${NumberFormat('#,##0', 'en_US').format(selectedSubtotal)}';
  String get formattedSelectedTax =>
      'UGX ${NumberFormat('#,##0', 'en_US').format(selectedTax)}';
  String get formattedSelectedTotal =>
      'UGX ${NumberFormat('#,##0', 'en_US').format(selectedTotal)}';

  String get formattedSubtotal => 'UGX ${NumberFormat('#,##0', 'en_US').format(subtotal)}';
  String get formattedShipping => 'UGX ${NumberFormat('#,##0', 'en_US').format(shipping)}';
  String get formattedTax => 'UGX ${NumberFormat('#,##0', 'en_US').format(tax)}';
  String get formattedTotal => 'UGX ${NumberFormat('#,##0', 'en_US').format(total)}';

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    double? subtotal,
    double? shipping,
    double? tax,
    double? total,
    Set<String>? selectedItemKeys,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      subtotal: subtotal ?? this.subtotal,
      shipping: shipping ?? this.shipping,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      selectedItemKeys: selectedItemKeys ?? this.selectedItemKeys,
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
      print('📦 Cart data: ${response.data}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        
          if (data['success'] == true) {
          final cartData = data['data'] ?? {};
          final itemsList = cartData['items'] as List? ?? [];
          
          print('📦 Found ${itemsList.length} items in cart');
          
          // Debug each item
          // Debug each item
for (var i = 0; i < itemsList.length; i++) {
  final item = itemsList[i];
  print('   --- Item $i ---');
  print('     product_id: ${item['product_id']}');
  print('     variant_id: ${item['variant_id']}');
  print('     attributes: ${item['attributes']}');
  print('     title: ${item['title']}');
  
  // Check for image-related fields
  print('     Checking for image fields:');
  final imageFields = ['thumbnail', 'image', 'primaryImage', 'primary_image', 'primaryImage', 'primary_image', 'images'];
  for (final field in imageFields) {
    if (item[field] != null) {
      print('       $field: ${item[field]} (type: ${item[field].runtimeType})');
    }
  }
  
  // Check if there's a nested product object
  if (item['product'] != null) {
    print('     Has nested product object');
    final product = item['product'];
    if (product is Map) {
      print('     Product keys: ${product.keys}');
      for (final field in imageFields) {
        if (product[field] != null) {
          print('       product.$field: ${product[field]} (type: ${product[field].runtimeType})');
        }
      }
    }
  }
}
          
          final items = itemsList.map((item) => CartItem.fromJson(item)).toList();
          // Auto-select all items when cart loads
          final allKeys = items.map((item) => item.itemKey).toSet();
          state = state.copyWith(
            items: items,
            subtotal: (cartData['subtotal'] ?? 0).toDouble(),
            shipping: (cartData['shipping'] ?? 0).toDouble(),
            tax: (cartData['tax'] ?? 0).toDouble(),
            total: (cartData['total'] ?? 0).toDouble(),
            isLoading: false,
            selectedItemKeys: allKeys,
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

// Update the addToCart method to handle variations properly:

Future<bool> addToCart(int listingId, int quantity, {
  int? variantId,
  Map<String, dynamic>? attributes,
}) async {
  print('🛒 Adding to cart: listing=$listingId, qty=$quantity, variant=$variantId');
  
  try {
    final data = {
      'quantity': quantity,
      if (variantId != null) 'variant_id': variantId,
      if (attributes != null) 'attributes': attributes,
    };
    
    print('📦 Sending cart data: $data');
    
    final response = await _api.post(
      ApiEndpoints.cartAdd(listingId),
      data: data,
    );

    print('📦 Add to cart response: ${response.statusCode}');
    print('📦 Response data: ${response.data}');

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
    print('🛒 Removing from cart: listing=$listingId, variant=$variantId');

    try {
      // For items with variants, send variant_id via query params (more reliable for DELETE)
      String endpoint = ApiEndpoints.cartRemove(listingId);
      if (variantId != null) {
        endpoint = '$endpoint?variant_id=$variantId';
      }

      final response = await _api.delete(endpoint);

      print('📦 Remove response: ${response.statusCode} - ${response.data}');

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

  // Selection methods
  void toggleItemSelection(String key) {
    final newKeys = Set<String>.from(state.selectedItemKeys);
    if (newKeys.contains(key)) {
      newKeys.remove(key);
    } else {
      newKeys.add(key);
    }
    state = state.copyWith(selectedItemKeys: newKeys);
  }

  void selectAll() {
    final allKeys = state.items.map((item) => item.itemKey).toSet();
    state = state.copyWith(selectedItemKeys: allKeys);
  }

  void deselectAll() {
    state = state.copyWith(selectedItemKeys: <String>{});
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