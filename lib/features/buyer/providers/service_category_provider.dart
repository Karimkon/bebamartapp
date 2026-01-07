// lib/features/buyer/providers/service_category_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/models/job_model.dart';

final serviceCategoriesProvider = FutureProvider.family<List<ServiceCategoryModel>, String?>((ref, type) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/api/service-categories', queryParameters: {
    if (type != null) 'type': type,
  });

  if (response.statusCode == 200 && response.data['success'] == true) {
    final List data = response.data['data'] ?? [];
    return data.map((json) => ServiceCategoryModel.fromJson(json)).toList();
  }
  return [];
});

final servicesProvider = FutureProvider<List<VendorServiceModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/api/marketplace/services');

  if (response.statusCode == 200 && response.data['success'] == true) {
    final List data = response.data['data'] ?? [];
    return data.map((json) => VendorServiceModel.fromJson(json)).toList();
  }
  return [];
});

final jobsProvider = FutureProvider<List<JobListingModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/api/marketplace/jobs');

  if (response.statusCode == 200 && response.data['success'] == true) {
    final List data = response.data['data'] ?? [];
    return data.map((json) => JobListingModel.fromJson(json)).toList();
  }
  return [];
});
