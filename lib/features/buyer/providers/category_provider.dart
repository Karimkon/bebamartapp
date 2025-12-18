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
              final category = CategoryModel(
                id: item['id'] is int ? item['id'] : int.tryParse(item['id'].toString()) ?? 0,
                name: item['name']?.toString() ?? 'Unknown Category',
                slug: item['slug']?.toString() ?? 'unknown',
                description: item['description']?.toString(),
                icon: item['icon']?.toString() ?? 'category',
                image: item['image']?.toString(),
                isActive: item['is_active'] ?? true,
                listingsCount: item['listings_count'] is int ? item['listings_count'] : null,
                parentId: item['parent_id'] is int ? item['parent_id'] : null,
              );
              if (category.id != 0) {
                categories.add(category);
              }
            } catch (e) {
              print('⚠️ Error parsing individual category: $e');
            }
          }
        }
        
        print('✅ Successfully parsed ${categories.length} categories');
        return categories;
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