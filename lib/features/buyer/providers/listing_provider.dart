// lib/features/buyer/providers/listing_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../auth/providers/auth_provider.dart';

// All listings provider - fetches all active listings
final allListingsProvider = FutureProvider<List<ListingModel>>((ref) async {
  print('🔄 allListingsProvider: Fetching all listings...');
  final api = ref.watch(apiClientProvider);
  
  try {
    // Use marketplace endpoint with category relationship loaded
    final response = await api.get(ApiEndpoints.marketplace, queryParameters: {
      'per_page': 100,
      'with': 'category,vendor.user,images,variants'
    });
    print('📦 allListingsProvider: Response status: ${response.statusCode}');
    print('📦 allListingsProvider: Response data: ${response.data}');
    print('📦 allListingsProvider: Response data type: ${response.data.runtimeType}');
    
    if (response.statusCode == 200) {
      List<dynamic> listingsData = [];
      
      // Handle different response formats from Laravel API
      if (response.data is Map) {
        final dataMap = response.data as Map;
        print('📦 Response is Map with keys: ${dataMap.keys.toList()}');
        
        if (dataMap['success'] == true && dataMap['data'] != null) {
          final data = dataMap['data'];
          print('📦 Found data in success.data, type: ${data.runtimeType}');
          
          if (data is List) {
            listingsData = data;
            print('✅ Found ${listingsData.length} listings in success.data (List)');
          } else if (data is Map && data['data'] != null) {
            listingsData = data['data'] as List? ?? [];
            print('✅ Found ${listingsData.length} listings in paginated data');
          }
        } else if (dataMap['data'] != null && dataMap['data'] is List) {
          listingsData = dataMap['data'] as List;
          print('✅ Found ${listingsData.length} listings in data key');
        }
      } else if (response.data is List) {
        listingsData = response.data;
        print('✅ Response is direct list with ${listingsData.length} items');
      }
      
      print('📋 Final listingsData: ${listingsData.length} items');
      print('📋 First item sample: ${listingsData.isNotEmpty ? listingsData.first : "EMPTY"}');
      
      if (listingsData.isEmpty) {
        print('⚠️ No listings found in response');
        return [];
      }
      
      try {
        final listings = <ListingModel>[];
        for (var i = 0; i < listingsData.length; i++) {
          final item = listingsData[i];
          if (item is Map<String, dynamic>) {
            try {
              final listing = ListingModel.fromJson(item);
              if (listing.id != 0) {
                listings.add(listing);
              } else {
                print('⚠️ Skipped listing $i: invalid ID');
              }
            } catch (e) {
              print('⚠️ Error parsing individual listing $i: $e');
              print('📋 Item data: $item');
            }
          } else {
            print('⚠️ Item $i is not Map<String, dynamic>, type: ${item.runtimeType}');
          }
        }
        
        print('✅ Successfully parsed ${listings.length} listings');
        return listings;
      } catch (e, stack) {
        print('❌ Error parsing listings: $e');
        print('📋 Stack: $stack');
        return [];
      }
    }
    
    print('❌ Failed to load listings: ${response.statusCode}');
    return [];
  } on DioException catch (e) {
    print('❌ DioException in allListingsProvider (using featured endpoint): ${e.message}');
    print('❌ Response data: ${e.response?.data}');
    return [];
  } catch (e) {
    print('❌ Error in allListingsProvider: $e');
    return [];
  }
});

// Featured listings provider (kept for backward compatibility)
final featuredListingsProvider = FutureProvider<List<ListingModel>>((ref) async {
  print('🔄 featuredListingsProvider: Fetching featured listings...');
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(ApiEndpoints.marketplace);
    print('📦 featuredListingsProvider: Response status: ${response.statusCode}');
    print('📦 featuredListingsProvider: Response data type: ${response.data.runtimeType}');
    
    if (response.statusCode == 200) {
      List<dynamic> listingsData = [];
      
      // Handle different response formats from Laravel API
      if (response.data is Map) {
        final dataMap = response.data as Map;
        
        if (dataMap['success'] == true && dataMap['data'] != null) {
          // Format: {success: true, data: [...]}
          final data = dataMap['data'];
          if (data is List) {
            listingsData = data;
            print('✅ Found ${listingsData.length} listings in success.data (List)');
          } else if (data is Map && data['data'] != null) {
            // Paginated: {success: true, data: {data: [...], meta: {...}}}
            listingsData = data['data'] as List? ?? [];
            print('✅ Found ${listingsData.length} listings in paginated data');
          }
        } else if (dataMap['data'] != null && dataMap['data'] is List) {
          // Format: {data: [...]}
          listingsData = dataMap['data'] as List;
          print('✅ Found ${listingsData.length} listings in data key');
        }
      } else if (response.data is List) {
        listingsData = response.data;
        print('✅ Response is direct list with ${listingsData.length} items');
      }
      
      if (listingsData.isEmpty) {
        print('⚠️ No listings found in response, checking for empty state');
        // Return empty list - no dummy data
        return [];
      }
      
      try {
        final listings = <ListingModel>[];
        for (var item in listingsData) {
          if (item is Map<String, dynamic>) {
            try {
              final listing = ListingModel.fromJson(item);
              if (listing.id != 0) {
                listings.add(listing);
              }
            } catch (e) {
              print('⚠️ Error parsing individual listing: $e');
              // Continue with other listings
            }
          }
        }
        
        print('✅ Successfully parsed ${listings.length} featured listings');
        return listings;
      } catch (e, stack) {
        print('❌ Error parsing listings: $e');
        print('📋 Stack: $stack');
        return [];
      }
    }
    
    print('❌ Failed to load featured listings: ${response.statusCode}');
    return [];
  } on DioException catch (e) {
    print('❌ DioException in featuredListingsProvider: ${e.message}');
    print('❌ Response data: ${e.response?.data}');
    return [];
  } catch (e) {
    print('❌ Error in featuredListingsProvider: $e');
    return [];
  }
});

// Marketplace listings
final marketplaceListingsProvider = FutureProvider.family<List<ListingModel>, Map<String, dynamic>>((ref, filters) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(
      ApiEndpoints.marketplace,
      queryParameters: filters,
    );
    
    if (response.statusCode == 200 && response.data is Map) {
      if (response.data['success'] == true) {
        final listingsData = (response.data['data'] as List?) ?? [];
        return listingsData
            .whereType<Map<String, dynamic>>()
            .map((e) => ListingModel.fromJson(e))
            .where((listing) => listing.id != 0)
            .toList();
      }
    }
    return [];
  } on DioException catch (e) {
    print('❌ DioException in marketplaceListingsProvider: ${e.message}');
    return [];
  }
});

// Single listing provider
final listingDetailProvider = FutureProvider.family<ListingModel?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(ApiEndpoints.listingDetail(id));
    
    if (response.statusCode == 200 && response.data is Map) {
      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return ListingModel.fromJson(data);
        }
      }
    }
    return null;
  } on DioException catch (e) {
    print('❌ DioException in listingDetailProvider: ${e.message}');
    return null;
  }
});

// Category listings provider
final listingsByCategoryProvider = FutureProvider.family<List<ListingModel>, String>((ref, slug) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    print('🔄 listingsByCategoryProvider: Loading listings for category: $slug');
    final response = await api.get('${AppConstants.apiUrl}/categories/$slug');
    
    if (response.statusCode == 200 && response.data is Map) {
      print('📦 Category response structure: ${response.data.keys}');
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        // Handle different response formats
        if (data is Map && data.containsKey('listings')) {
          // Format: {data: {category: {...}, listings: [...]}}
          final listingsData = data['listings'] as List? ?? [];
          print('✅ Found ${listingsData.length} listings in category');
          
          return listingsData
              .whereType<Map<String, dynamic>>()
              .map((e) => ListingModel.fromJson(e))
              .where((listing) => listing.id != 0)
              .toList();
        } else if (data is List) {
          // Format: {data: [...]}
          final listingsData = data;
          print('✅ Found ${listingsData.length} listings in direct list');
          
          return listingsData
              .whereType<Map<String, dynamic>>()
              .map((e) => ListingModel.fromJson(e))
              .where((listing) => listing.id != 0)
              .toList();
        } else {
          print('⚠️ Unexpected data format in category response');
          return [];
        }
      }
    }
    
    print('❌ Failed to load category listings: ${response.statusCode}');
    return [];
  } on DioException catch (e) {
    print('❌ DioException in listingsByCategoryProvider: ${e.message}');
    print('📋 URL: ${AppConstants.apiUrl}/categories/$slug');
    return [];
  } catch (e, stack) {
    print('❌ Error in listingsByCategoryProvider: $e');
    print('📋 Stack: $stack');
    return [];
  }
});

// Search listings
class SearchState {
  final List<ListingModel> results;
  final bool isLoading;
  final String? error;
  final String query;
  final double? minPrice;
  final double? maxPrice;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.minPrice,
    this.maxPrice,
  });

  SearchState copyWith({
    List<ListingModel>? results,
    bool? isLoading,
    String? error,
    String? query,
    double? minPrice,
    double? maxPrice,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearFilters = false,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      minPrice: (clearFilters || clearMinPrice) ? null : (minPrice ?? this.minPrice),
      maxPrice: (clearFilters || clearMaxPrice) ? null : (maxPrice ?? this.maxPrice),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final ApiClient _api;

  SearchNotifier(this._api) : super(const SearchState());

  Future<void> search(String query, {double? minPrice, double? maxPrice, bool clearFilters = false}) async {
    // Allow empty query if price filters are applied or reset
    if (query.isEmpty && minPrice == null && maxPrice == null && !clearFilters && state.minPrice == null && state.maxPrice == null) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(
      isLoading: true, 
      query: query, 
      error: null,
      minPrice: minPrice,
      maxPrice: maxPrice,
      clearFilters: clearFilters,
    );

    try {
      final queryParams = {
        'search': query,
        if (state.minPrice != null) 'min_price': state.minPrice,
        if (state.maxPrice != null) 'max_price': state.maxPrice,
      };

      final response = await _api.get(
        ApiEndpoints.marketplace,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map) {
        if (response.data['success'] == true) {
          final listingsData = (response.data['data'] as List?) ?? [];
          final results = listingsData
              .whereType<Map<String, dynamic>>()
              .map((e) => ListingModel.fromJson(e))
              .where((listing) => listing.id != 0)
              .toList();
          state = state.copyWith(results: results, isLoading: false);
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: 'No results found');
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Search failed',
      );
    }
  }

  void clear() {
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final api = ref.watch(apiClientProvider);
  return SearchNotifier(api);
});

// Related products provider key class for stable identity
class RelatedProductsKey {
  final int productId;
  final int? categoryId;
  final int? vendorId;

  const RelatedProductsKey({
    required this.productId,
    this.categoryId,
    this.vendorId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelatedProductsKey &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          categoryId == other.categoryId &&
          vendorId == other.vendorId;

  @override
  int get hashCode => productId.hashCode ^ categoryId.hashCode ^ vendorId.hashCode;
}

// Related products provider - fetches products from the same category excluding current product
final relatedProductsProvider = FutureProvider.family<List<ListingModel>, RelatedProductsKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final productId = key.productId;
  final categoryId = key.categoryId;
  final vendorId = key.vendorId;

  try {
    print('🔄 relatedProductsProvider: Fetching related products');
    print('   Product ID: $productId, Category ID: $categoryId, Vendor ID: $vendorId');

    final listings = <ListingModel>[];

    // First try with category filter if available
    if (categoryId != null) {
      final response = await api.get(ApiEndpoints.marketplace, queryParameters: {
        'per_page': 10,
        'exclude': productId,
        'category_id': categoryId,
      });

      if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> listingsData = data is List ? data : (data is Map ? data['data'] ?? [] : []);

        for (var item in listingsData) {
          if (item is Map<String, dynamic>) {
            try {
              final listing = ListingModel.fromJson(item);
              if (listing.id != 0 && listing.id != productId) {
                listings.add(listing);
                if (listings.length >= 8) break;
              }
            } catch (e) {
              print('   ⚠️ Error parsing listing: $e');
            }
          }
        }
        print('   Category filter: found ${listings.length} products');
      }
    }

    // If no results from category, try without filter (get any other products)
    if (listings.isEmpty) {
      print('   🔄 Trying fallback without category filter...');
      final fallbackResponse = await api.get(ApiEndpoints.marketplace, queryParameters: {
        'per_page': 10,
        'exclude': productId,
      });

      if (fallbackResponse.statusCode == 200 && fallbackResponse.data is Map && fallbackResponse.data['success'] == true) {
        final data = fallbackResponse.data['data'];
        List<dynamic> listingsData = data is List ? data : (data is Map ? data['data'] ?? [] : []);

        for (var item in listingsData) {
          if (item is Map<String, dynamic>) {
            try {
              final listing = ListingModel.fromJson(item);
              if (listing.id != 0 && listing.id != productId) {
                listings.add(listing);
                if (listings.length >= 8) break;
              }
            } catch (e) {
              // Skip
            }
          }
        }
        print('   Fallback: found ${listings.length} products');
      }
    }

    print('✅ Total related products: ${listings.length}');
    return listings;
  } on DioException catch (e) {
    print('❌ DioException in relatedProductsProvider: ${e.message}');
    return [];
  } catch (e) {
    print('❌ Error in relatedProductsProvider: $e');
    return [];
  }
});

// No more dummy data - return empty lists when no data available