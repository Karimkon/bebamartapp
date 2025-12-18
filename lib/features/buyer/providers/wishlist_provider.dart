// lib/features/buyer/providers/wishlist_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../auth/providers/auth_provider.dart';

// ==========================================
// WISHLIST ITEM MODEL
// ==========================================
class WishlistItem {
  final int id;
  final int listingId;
  final String title;
  final double price;
  final String? thumbnail;
  final bool inStock;
  final DateTime addedAt;

  WishlistItem({
    required this.id,
    required this.listingId,
    required this.title,
    required this.price,
    this.thumbnail,
    this.inStock = true,
    required this.addedAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] ?? 0,
      listingId: json['listing_id'] ?? 0,
      title: json['title'] ?? 'Unknown Product',
      price: json['price'] is String ? double.tryParse(json['price']) ?? 0.0 : (json['price'] ?? 0).toDouble(),
      thumbnail: json['thumbnail'],
      inStock: json['in_stock'] ?? true,
      addedAt: json['added_at'] != null 
          ? DateTime.tryParse(json['added_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedPrice => 'UGX ${price.toStringAsFixed(0)}';
}

// ==========================================
// WISHLIST STATE
// ==========================================
class WishlistState {
  final List<WishlistItem> items;
  final Set<int> wishlistedIds; // Quick lookup for wishlist status
  final bool isLoading;
  final String? error;

  const WishlistState({
    this.items = const [],
    this.wishlistedIds = const {},
    this.isLoading = false,
    this.error,
  });

  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  bool isWishlisted(int listingId) => wishlistedIds.contains(listingId);

  WishlistState copyWith({
    List<WishlistItem>? items,
    Set<int>? wishlistedIds,
    bool? isLoading,
    String? error,
  }) {
    return WishlistState(
      items: items ?? this.items,
      wishlistedIds: wishlistedIds ?? this.wishlistedIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==========================================
// WISHLIST NOTIFIER
// ==========================================
class WishlistNotifier extends StateNotifier<WishlistState> {
  final ApiClient _api;

  WishlistNotifier(this._api) : super(const WishlistState());

  Future<void> loadWishlist() async {
    print('💖 Loading wishlist...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get(ApiEndpoints.wishlist);
      print('📦 Wishlist response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        
        if (data['success'] == true) {
          final itemsList = data['data'] as List? ?? [];
          
          final items = itemsList.map((item) => WishlistItem.fromJson(item)).toList();
          final ids = items.map((item) => item.listingId).toSet();

          state = state.copyWith(
            items: items,
            wishlistedIds: ids,
            isLoading: false,
          );
          print('✅ Wishlist loaded: ${items.length} items');
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      print('❌ Wishlist load error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to load wishlist',
      );
    } catch (e) {
      print('❌ Wishlist load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> addToWishlist(int listingId) async {
    print('💖 Adding to wishlist: listing=$listingId');
    
    // Optimistic update
    final currentIds = Set<int>.from(state.wishlistedIds)..add(listingId);
    state = state.copyWith(wishlistedIds: currentIds);
    
    try {
      final response = await _api.post(ApiEndpoints.wishlistAdd(listingId));
      print('📦 Add to wishlist response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        await loadWishlist(); // Refresh full list
        return true;
      }
      
      // Revert on failure
      currentIds.remove(listingId);
      state = state.copyWith(wishlistedIds: currentIds);
      return false;
    } catch (e) {
      print('❌ Add to wishlist error: $e');
      // Revert on error
      currentIds.remove(listingId);
      state = state.copyWith(wishlistedIds: currentIds);
      rethrow;
    }
  }

  Future<bool> removeFromWishlist(int listingId) async {
    print('💔 Removing from wishlist: listing=$listingId');
    
    // Optimistic update
    final currentIds = Set<int>.from(state.wishlistedIds)..remove(listingId);
    state = state.copyWith(wishlistedIds: currentIds);
    
    try {
      final response = await _api.delete(ApiEndpoints.wishlistRemove(listingId));
      print('📦 Remove from wishlist response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Remove from items list too
        final updatedItems = state.items.where((item) => item.listingId != listingId).toList();
        state = state.copyWith(items: updatedItems);
        return true;
      }
      
      // Revert on failure
      currentIds.add(listingId);
      state = state.copyWith(wishlistedIds: currentIds);
      return false;
    } catch (e) {
      print('❌ Remove from wishlist error: $e');
      // Revert on error
      currentIds.add(listingId);
      state = state.copyWith(wishlistedIds: currentIds);
      rethrow;
    }
  }

  Future<bool> toggleWishlist(int listingId) async {
    print('💖 Toggling wishlist: listing=$listingId');
    
    final isCurrentlyWishlisted = state.isWishlisted(listingId);
    
    // Optimistic update
    final currentIds = Set<int>.from(state.wishlistedIds);
    if (isCurrentlyWishlisted) {
      currentIds.remove(listingId);
    } else {
      currentIds.add(listingId);
    }
    state = state.copyWith(wishlistedIds: currentIds);
    
    try {
      final response = await _api.post(ApiEndpoints.wishlistToggle(listingId));
      print('📦 Toggle wishlist response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final inWishlist = response.data['in_wishlist'] ?? !isCurrentlyWishlisted;
        
        // Update ids based on server response
        final updatedIds = Set<int>.from(state.wishlistedIds);
        if (inWishlist) {
          updatedIds.add(listingId);
        } else {
          updatedIds.remove(listingId);
          // Also remove from items
          final updatedItems = state.items.where((item) => item.listingId != listingId).toList();
          state = state.copyWith(items: updatedItems);
        }
        state = state.copyWith(wishlistedIds: updatedIds);
        
        return true;
      }
      
      // Revert on failure
      if (isCurrentlyWishlisted) {
        currentIds.add(listingId);
      } else {
        currentIds.remove(listingId);
      }
      state = state.copyWith(wishlistedIds: currentIds);
      return false;
    } catch (e) {
      print('❌ Toggle wishlist error: $e');
      // Revert on error
      if (isCurrentlyWishlisted) {
        currentIds.add(listingId);
      } else {
        currentIds.remove(listingId);
      }
      state = state.copyWith(wishlistedIds: currentIds);
      rethrow;
    }
  }

  Future<bool> moveToCart(int listingId) async {
    print('🛒 Moving to cart: listing=$listingId');
    
    try {
      final response = await _api.post(ApiEndpoints.wishlistMoveToCart(listingId));
      print('📦 Move to cart response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Remove from wishlist
        final currentIds = Set<int>.from(state.wishlistedIds)..remove(listingId);
        final updatedItems = state.items.where((item) => item.listingId != listingId).toList();
        state = state.copyWith(
          items: updatedItems,
          wishlistedIds: currentIds,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Move to cart error: $e');
      rethrow;
    }
  }
}

// ==========================================
// PROVIDERS
// ==========================================
final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>((ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = WishlistNotifier(api);
  
  // Auto-load wishlist when provider is created
  notifier.loadWishlist();
  
  return notifier;
});

// Convenience providers
final wishlistItemCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistProvider).itemCount;
});

final isInWishlistProvider = Provider.family<bool, int>((ref, listingId) {
  return ref.watch(wishlistProvider).isWishlisted(listingId);
});