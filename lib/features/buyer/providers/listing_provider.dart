// lib/features/buyer/providers/listing_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../auth/providers/auth_provider.dart';

// Featured listings provider
final featuredListingsProvider = FutureProvider<List<ListingModel>>((ref) async {
  print('🔄 featuredListingsProvider: Fetching featured listings...');
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(ApiEndpoints.marketplace);
    print('📦 featuredListingsProvider: Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      List<dynamic> listingsData = [];
      
      if (response.data is Map && (response.data as Map)['success'] == true) {
        final listingsResponse = (response.data as Map)['listings'];
        if (listingsResponse is Map && listingsResponse['data'] is List) {
          listingsData = listingsResponse['data'];
          print('✅ Found ${listingsData.length} listings in listings.data');
        } else if (listingsResponse is List) {
          listingsData = listingsResponse;
          print('✅ Found ${listingsData.length} listings in listings (direct list)');
        } else {
          print('⚠️ Unexpected listings format: $listingsResponse');
          return _getDummyListings();
        }
      } else if (response.data is List) {
        listingsData = response.data;
        print('✅ Response is direct list with ${listingsData.length} items');
      } else {
        print('⚠️ Unexpected response format: ${response.data}');
        return _getDummyListings();
      }
      
      if (listingsData.isEmpty) {
        print('⚠️ No featured listings found, returning dummy data');
        return _getDummyListings();
      }
      
      try {
        final listings = listingsData.map<ListingModel>((item) {
          if (item is! Map<String, dynamic>) {
            print('⚠️ Item is not Map<String, dynamic>, skipping');
            return ListingModel(
              id: 0,
              vendorProfileId: 1,
              title: 'Invalid Item',
              price: 0,
            );
          }
          return ListingModel.fromJson(item);
        }).where((listing) => listing.id != 0).toList();
        
        print('✅ Successfully parsed ${listings.length} featured listings');
        if (listings.isEmpty) {
          print('⚠️ No valid listings after parsing, returning dummy data');
          return _getDummyListings();
        }
        return listings;
      } catch (e, stack) {
        print('❌ Error parsing listings: $e');
        print('📋 Stack: $stack');
        return _getDummyListings();
      }
    }
    
    print('❌ Failed to load featured listings: ${response.statusCode}');
    return _getDummyListings();
  } on DioException catch (e) {
    print('❌ DioException in featuredListingsProvider: ${e.message}');
    return _getDummyListings();
  } catch (e) {
    print('❌ Error in featuredListingsProvider: $e');
    return _getDummyListings();
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

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<ListingModel>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final ApiClient _api;

  SearchNotifier(this._api) : super(const SearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: query, error: null);

    try {
      final response = await _api.get(
        ApiEndpoints.marketplace,
        queryParameters: {'search': query},
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

// Dummy data for testing
List<ListingModel> _getDummyListings() {
  return [
    _getDummyListing(),
    _getDummyListing(),
    _getDummyListing(),
  ];
}

ListingModel _getDummyListing() {
  return ListingModel(
    id: 1,
    vendorProfileId: 1,
    title: 'Sample Product',
    description: 'This is a sample product for testing',
    price: 100.0,
    stock: 10,
    isActive: true,
    viewCount: 0,
    clickCount: 0,
    wishlistCount: 0,
    cartAddCount: 0,
    purchaseCount: 0,
    shareCount: 0,
    images: [
      ListingImageModel(
        id: 1,
        listingId: 1,
        path: 'sample-image.jpg',
      ),
    ],
    variants: [],
    vendor: null,
    category: null,
    reviews: [],
  );
}