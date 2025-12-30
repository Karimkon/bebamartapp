// lib/features/buyer/providers/category_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/category_model.dart';
import '../../auth/providers/auth_provider.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  print('🔄 categoriesProvider: Fetching categories from API...');
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get(ApiEndpoints.categories);
    print('📦 categoriesProvider: Response status: ${response.statusCode}');
    print('📦 categoriesProvider: Full URL: ${ApiEndpoints.categories}');

    if (response.statusCode == 200) {
      List<dynamic> categoriesData = [];

      // Handle different response formats
      if (response.data is Map) {
        final dataMap = response.data as Map;
        print('📦 Response keys: ${dataMap.keys.toList()}');

        // Log the message if present (from updated API)
        if (dataMap['message'] != null) {
          print('📦 API Message: ${dataMap['message']}');
        }
        if (dataMap['count'] != null) {
          print('📦 API Count: ${dataMap['count']}');
        }

        if (dataMap['success'] == true && dataMap['data'] != null) {
          final data = dataMap['data'];
          if (data is List) {
            categoriesData = data;
            print('✅ Found ${categoriesData.length} categories in response');

            // Log first 3 categories for debugging
            for (int i = 0; i < categoriesData.length && i < 3; i++) {
              final cat = categoriesData[i];
              print('   📂 Category $i: ${cat['name']} (id=${cat['id']}, parent_id=${cat['parent_id']}, children=${(cat['children'] as List?)?.length ?? 0})');
            }
          }
        } else if (dataMap['data'] != null && dataMap['data'] is List) {
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
              final category = CategoryModel.fromJson(item);
              if (category.id != 0) {
                categories.add(category);
                // Log each category's parent_id
                print('   ✅ Parsed: ${category.name} (id=${category.id}, parentId=${category.parentId}, children=${category.children.length})');
              }
            } catch (e) {
              print('⚠️ Error parsing category: $e');
              print('   Raw data: $item');
            }
          }
        }

        // IMPORTANT: Only show parent categories (parent_id == null)
        final parentCategories = categories.where((c) => c.parentId == null).toList();

        print('📊 Total parsed: ${categories.length}');
        print('📊 Parent categories (parentId==null): ${parentCategories.length}');
        print('📊 Child categories (parentId!=null): ${categories.length - parentCategories.length}');

        // If API correctly returns only parents, use them
        // If API returns mixed, filter to parents only
        final result = parentCategories.isNotEmpty ? parentCategories : categories;

        print('✅ Returning ${result.length} categories');
        for (var cat in result.take(5)) {
          print('   📁 ${cat.name} (${cat.children.length} subcategories, icon=${cat.icon})');
        }

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