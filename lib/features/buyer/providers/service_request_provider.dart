// lib/features/buyer/providers/service_request_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/service_request_model.dart';

class BuyerServiceRequestsState {
  final bool isLoading;
  final List<ServiceRequestModel> requests;
  final String? error;
  final int currentPage;
  final int lastPage;
  final int total;

  BuyerServiceRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  BuyerServiceRequestsState copyWith({
    bool? isLoading,
    List<ServiceRequestModel>? requests,
    String? error,
    int? currentPage,
    int? lastPage,
    int? total,
  }) {
    return BuyerServiceRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
    );
  }
}

class BuyerServiceRequestsNotifier extends StateNotifier<BuyerServiceRequestsState> {
  final Ref ref;

  BuyerServiceRequestsNotifier(this.ref) : super(BuyerServiceRequestsState());

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

      final response = await api.get('/api/service-requests', queryParameters: params);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = (response.data['data'] as List)
            .map((e) => ServiceRequestModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          isLoading: false,
          requests: list,
          currentPage: response.data['current_page'] ?? 1,
          lastPage: response.data['last_page'] ?? 1,
          total: response.data['total'] ?? list.length,
        );
        return;
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

  Future<Map<String, dynamic>> submitRequest(Map<String, dynamic> data) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/service-requests', data: data);
      if (response.statusCode == 201 && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Request submitted'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed to submit'};
    } on DioException catch (e) {
      final errors = e.response?.data?['errors'];
      if (errors != null) {
        final firstError = (errors as Map).values.first;
        return {'success': false, 'message': (firstError as List).first.toString()};
      }
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to submit'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptQuote(int requestId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/service-requests/$requestId/accept');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Quote accepted'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelRequest(int requestId) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/api/service-requests/$requestId/cancel');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Request cancelled'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final buyerServiceRequestsProvider =
    StateNotifierProvider<BuyerServiceRequestsNotifier, BuyerServiceRequestsState>(
  (ref) => BuyerServiceRequestsNotifier(ref),
);
