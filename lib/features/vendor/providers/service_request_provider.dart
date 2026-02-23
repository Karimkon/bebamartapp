// lib/features/vendor/providers/service_request_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/service_request_model.dart';

class VendorServiceRequestsState {
  final bool isLoading;
  final List<ServiceRequestModel> requests;
  final String? error;
  final int currentPage;
  final int lastPage;
  final int total;
  final Map<String, int> statusCounts;

  VendorServiceRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.statusCounts = const {},
  });

  VendorServiceRequestsState copyWith({
    bool? isLoading,
    List<ServiceRequestModel>? requests,
    String? error,
    int? currentPage,
    int? lastPage,
    int? total,
    Map<String, int>? statusCounts,
  }) {
    return VendorServiceRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      statusCounts: statusCounts ?? this.statusCounts,
    );
  }
}

class VendorServiceRequestsNotifier extends StateNotifier<VendorServiceRequestsState> {
  final Ref ref;

  VendorServiceRequestsNotifier(this.ref) : super(VendorServiceRequestsState());

  Future<void> loadRequests({String? status, bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, requests: []);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{'per_page': 20};
      if (status != null && status != 'all') params['status'] = status;

      final response = await api.get('/api/vendor/service-requests', queryParameters: params);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        if (data['success'] == true) {
          final list = (data['data'] as List)
              .map((e) => ServiceRequestModel.fromJson(e as Map<String, dynamic>))
              .toList();
          final counts = Map<String, int>.from(data['status_counts'] as Map? ?? {});
          state = state.copyWith(
            isLoading: false,
            requests: list,
            statusCounts: counts,
            currentPage: data['current_page'] ?? 1,
            lastPage: data['last_page'] ?? 1,
            total: data['total'] ?? list.length,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, requests: []);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load requests',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> submitQuote(int requestId, double quotedPrice, String? notes) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/api/vendor/service-requests/$requestId/quote',
        data: {'quoted_price': quotedPrice, 'vendor_notes': notes},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Quote submitted'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStatus(int requestId, String status) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/api/vendor/service-requests/$requestId/status',
        data: {'status': status},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Updated'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final vendorServiceRequestsProvider =
    StateNotifierProvider<VendorServiceRequestsNotifier, VendorServiceRequestsState>(
  (ref) => VendorServiceRequestsNotifier(ref),
);

final vendorServiceRequestDetailProvider =
    FutureProvider.family<ServiceRequestModel?, int>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/api/vendor/service-requests/$id');
  if (response.statusCode == 200 && response.data['success'] == true) {
    return ServiceRequestModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
  return null;
});

// Count of pending requests for badge
final vendorPendingRequestsCountProvider = FutureProvider<int>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/api/vendor/service-requests', queryParameters: {'status': 'pending', 'per_page': 1});
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['total'] ?? 0;
    }
    return 0;
  } catch (_) {
    return 0;
  }
});
