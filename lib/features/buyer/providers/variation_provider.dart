import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/variation_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class VariationState {
  final List<VariationModel> variations;
  final List<String> availableColors;
  final List<String> availableSizes;
  final bool hasVariations;
  final bool isLoading;
  final String? error;

  const VariationState({
    this.variations = const [],
    this.availableColors = const [],
    this.availableSizes = const [],
    this.hasVariations = false,
    this.isLoading = false,
    this.error,
  });

  VariationState copyWith({
    List<VariationModel>? variations,
    List<String>? availableColors,
    List<String>? availableSizes,
    bool? hasVariations,
    bool? isLoading,
    String? error,
  }) {
    return VariationState(
      variations: variations ?? this.variations,
      availableColors: availableColors ?? this.availableColors,
      availableSizes: availableSizes ?? this.availableSizes,
      hasVariations: hasVariations ?? this.hasVariations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VariationNotifier extends StateNotifier<VariationState> {
  final ApiClient _api;
  
  VariationNotifier(this._api) : super(const VariationState());

  Future<void> loadVariations(int listingId) async {
    state = state.copyWith(isLoading: true, error: null);
    print('🔄 VariationProvider: Loading variations for listing $listingId');

    try {
      // First check if product has variations
      final checkResponse = await _api.get(
        ApiEndpoints.listingCheckVariations(listingId),
      );

      print('📦 VariationProvider: Check response: ${checkResponse.data}');

      if (checkResponse.statusCode == 200) {
        final checkData = checkResponse.data;
        final hasVariations = checkData['has_variations'] ?? false;
        final colors = List<String>.from(checkData['available_colors'] ?? []);
        final sizes = List<String>.from(checkData['available_sizes'] ?? []);

        print('📦 VariationProvider: hasVariations=$hasVariations, colors=$colors, sizes=$sizes');

        if (hasVariations && (colors.isNotEmpty || sizes.isNotEmpty)) {
          // Load full variations data
          final variationsResponse = await _api.get(
            ApiEndpoints.listingVariations(listingId),
          );

          print('📦 VariationProvider: Variations response: ${variationsResponse.data}');

          if (variationsResponse.statusCode == 200) {
            final variationsData = variationsResponse.data;
            final variations = (variationsData['variations'] as List)
                .map((v) => VariationModel.fromJson(v))
                .toList();

            print('✅ VariationProvider: Loaded ${variations.length} variations');
            for (var v in variations) {
              print('   - Variant id=${v.id}, color=${v.color}, size=${v.size}, price=${v.price}, stock=${v.stock}');
            }

            state = state.copyWith(
              variations: variations,
              availableColors: colors,
              availableSizes: sizes,
              hasVariations: true,
              isLoading: false,
            );
          }
        } else {
          print('⚠️ VariationProvider: No variations found');
          state = state.copyWith(
            hasVariations: false,
            isLoading: false,
          );
        }
      } else {
        print('❌ VariationProvider: Check failed with status ${checkResponse.statusCode}');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to check variations',
        );
      }
    } on DioException catch (e) {
      print('❌ VariationProvider: DioException: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Network error',
      );
    }
  }

  VariationModel? findMatchingVariant({
    String? color,
    String? size,
  }) {
    print('🔍 VariationProvider: Finding variant for color=$color, size=$size');
    print('   Available variations: ${state.variations.length}');

    if (state.variations.isEmpty) {
      print('   ❌ No variations available');
      return null;
    }

    for (var v in state.variations) {
      print('   - Checking variant id=${v.id}: color=${v.color}, size=${v.size}');
    }

    final result = state.variations.firstWhere(
      (variant) {
        final variantColor = variant.color;
        final variantSize = variant.size;

        bool colorMatch = true;
        bool sizeMatch = true;

        if (color != null && variantColor != color) {
          colorMatch = false;
        }

        if (size != null && variantSize != size) {
          sizeMatch = false;
        }

        return colorMatch && sizeMatch;
      },
      orElse: () => state.variations.first,
    );

    print('   ✅ Found matching variant: id=${result.id}, color=${result.color}, size=${result.size}');
    return result;
  }

  void clear() {
    state = const VariationState();
  }
}

final variationProvider = StateNotifierProvider.family<VariationNotifier, VariationState, int>((ref, listingId) {
  final api = ref.watch(apiClientProvider);
  return VariationNotifier(api);
});

// Helper provider to get variations for a listing
final listingVariationsProvider = Provider.family<List<VariationModel>, int>((ref, listingId) {
  final state = ref.watch(variationProvider(listingId));
  return state.variations;
});