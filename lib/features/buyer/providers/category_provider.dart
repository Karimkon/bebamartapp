// lib/features/buyer/providers/category_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/category_model.dart';
import '../../auth/providers/auth_provider.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  print('🔄 categoriesProvider: Fetching categories...');
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get(ApiEndpoints.categories);
    print('📦 categoriesProvider: Response status: ${response.statusCode}');
    print('📦 categoriesProvider: Response data type: ${response.data.runtimeType}');

    if (response.statusCode == 200) {
      List<dynamic> categoriesData = [];

      // Handle different response formats
      if (response.data is Map) {
        final dataMap = response.data as Map;

        if (dataMap['success'] == true && dataMap['data'] != null) {
          // Format: {success: true, data: [...]}
          final data = dataMap['data'];
          if (data is List) {
            categoriesData = data;
            print('✅ Found ${categoriesData.length} categories in success.data');
          }
        } else if (dataMap['data'] != null && dataMap['data'] is List) {
          // Format: {data: [...]}
          categoriesData = dataMap['data'] as List;
          print('✅ Found ${categoriesData.length} categories in data key');
        }
      } else if (response.data is List) {
        categoriesData = response.data;
        print('✅ Response is direct list with ${categoriesData.length} categories');
      }

      if (categoriesData.isEmpty) {
        print('⚠️ No categories found in response');
        return [];
      }

      try {
        final categories = <CategoryModel>[];
        for (var item in categoriesData) {
          if (item is Map<String, dynamic>) {
            try {
              // Use fromJson to properly parse categories with children
              final category = CategoryModel.fromJson(item);
              if (category.id != 0) {
                categories.add(category);
              }
            } catch (e) {
              print('⚠️ Error parsing individual category: $e');
            }
          }
        }

        // Client-side fallback: filter to only show parent categories (parent_id == null)
        // This ensures proper display even if API returns child categories
        final parentCategories = categories.where((c) => c.parentId == null).toList();

        // If we have parent categories, return them; otherwise return all (legacy fallback)
        final result = parentCategories.isNotEmpty ? parentCategories : categories;

        print('✅ Successfully parsed ${result.length} parent categories (filtered from ${categories.length} total)');
        return result;
      } catch (e) {
        print('❌ Error parsing categories: $e');
        return [];
      }
    }

    print('❌ Failed to load categories: ${response.statusCode}');
    return [];
  } on DioException catch (e) {
    print('❌ DioException in categoriesProvider: ${e.message}');
    print('❌ Response data: ${e.response?.data}');
    return [];
  } catch (e) {
    print('❌ Error in categoriesProvider: $e');
    return [];
  }
});

final parentCategoriesProvider = Provider<AsyncValue<List<CategoryModel>>>((ref) {
  return ref.watch(categoriesProvider).whenData(
    (categories) => categories.where((c) => c.parentId == null).toList(),
  );
});

final categoryDetailProvider = FutureProvider.family<CategoryModel?, String>((ref, slug) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(ApiEndpoints.categoryDetail(slug));
    
    if (response.statusCode == 200 && response.data is Map) {
      if (response.data['success'] == true) {
        return CategoryModel.fromJson(response.data['data']);
      }
    }
    return null;
  } on DioException catch (e) {
    throw Exception('Failed to load category: ${e.message}');
  }
});