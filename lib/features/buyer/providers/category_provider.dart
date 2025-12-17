// lib/features/buyer/providers/category_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/category_model.dart';
import '../../auth/providers/auth_provider.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  print('🔄 categoriesProvider: Fetching categories...');
  final api = ref.watch(apiClientProvider);
  
  try {
    final response = await api.get(ApiEndpoints.categories);
    print('📦 categoriesProvider: Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      List<dynamic> categoriesData = [];
      
      if (response.data is Map && (response.data as Map)['success'] == true) {
        categoriesData = (response.data as Map)['data'] ?? [];
        print('✅ Found ${categoriesData.length} categories in data key');
      } else if (response.data is List) {
        categoriesData = response.data;
        print('✅ Response is direct list with ${categoriesData.length} items');
      } else {
        print('⚠️ Unexpected response format: ${response.data}');
        return [];
      }
      
      if (categoriesData.isEmpty) {
        print('⚠️ No categories found');
        return [];
      }
      
      try {
        final categories = categoriesData.map<CategoryModel>((item) {
          return CategoryModel(
            id: item['id'] ?? 0,
            name: item['name'] ?? 'Unknown Category',
            slug: item['slug'] ?? 'unknown',
            description: item['description'] ?? '',
            icon: item['icon'] ?? 'category',
            image: item['image'],
            isActive: item['is_active'] ?? true,
            listingsCount: item['listings_count'] ?? 0,
          );
        }).where((category) => category.id != 0).toList();
        
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