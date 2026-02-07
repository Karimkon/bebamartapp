// lib/features/vendor/providers/subscription_provider.dart
// Subscription management provider with Riverpod

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../shared/models/subscription_model.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

export '../../../shared/models/subscription_model.dart';

// ==================== SUBSCRIPTION STATE ====================
class SubscriptionState {
  final bool isLoading;
  final String? error;
  final List<SubscriptionPlanModel> plans;
  final VendorSubscriptionModel? currentSubscription;
  final List<SubscriptionPaymentModel> paymentHistory;

  SubscriptionState({
    this.isLoading = false,
    this.error,
    this.plans = const [],
    this.currentSubscription,
    this.paymentHistory = const [],
  });

  SubscriptionState copyWith({
    bool? isLoading,
    String? error,
    List<SubscriptionPlanModel>? plans,
    VendorSubscriptionModel? currentSubscription,
    List<SubscriptionPaymentModel>? paymentHistory,
    bool clearError = false,
    bool clearSubscription = false,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      plans: plans ?? this.plans,
      currentSubscription: clearSubscription ? null : (currentSubscription ?? this.currentSubscription),
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  bool get hasActiveSubscription =>
      currentSubscription != null && currentSubscription!.isActive;

  bool get hasPaidSubscription =>
      hasActiveSubscription && !(currentSubscription!.plan?.isFreePlan ?? true);

  String get currentPlanName =>
      currentSubscription?.plan?.name ?? 'Free';

  String? get currentBadge =>
      currentSubscription?.plan?.badgeEnabled == true
          ? currentSubscription?.plan?.badgeText
          : null;
}

// ==================== SUBSCRIPTION NOTIFIER ====================
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final ApiClient _api;
  final Ref _ref;

  SubscriptionNotifier(this._api, this._ref) : super(SubscriptionState());

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.get('/api/subscription-plans');

      if (response.data['success'] == true) {
        final plansJson = response.data['plans'] as List;
        final plans = plansJson
            .map((json) => SubscriptionPlanModel.fromJson(json))
            .toList();

        state = state.copyWith(
          isLoading: false,
          plans: plans,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Failed to load plans',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Network error loading plans',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription plans',
      );
    }
  }

  Future<void> loadCurrentSubscription() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.get('/api/vendor/subscription');

      if (response.data['success'] == true) {
        VendorSubscriptionModel? subscription;
        if (response.data['subscription'] != null) {
          subscription = VendorSubscriptionModel.fromJson(response.data['subscription']);
        }

        state = state.copyWith(
          isLoading: false,
          currentSubscription: subscription,
          clearSubscription: subscription == null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearSubscription: true,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(
          isLoading: false,
          clearSubscription: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['message'] ?? 'Network error',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription',
      );
    }
  }

  Future<SubscribeResult> subscribe(int planId, {bool autoRenew = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.post('/api/vendor/subscription/subscribe', data: {
        'plan_id': planId,
        'auto_renew': autoRenew,
      });

      state = state.copyWith(isLoading: false);

      if (response.data['success'] == true) {
        // Check if this is a free plan (no payment URL)
        if (response.data['payment_url'] == null) {
          // Free plan subscribed directly
          await loadCurrentSubscription();
          return SubscribeResult(
            success: true,
            message: response.data['message'] ?? 'Subscribed successfully',
          );
        }

        // Paid plan - return payment URL
        return SubscribeResult(
          success: true,
          paymentUrl: response.data['payment_url'],
          merchantReference: response.data['merchant_reference'],
          subscriptionId: response.data['subscription_id'],
        );
      } else {
        return SubscribeResult(
          success: false,
          message: response.data['message'] ?? 'Subscription failed',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      return SubscribeResult(
        success: false,
        message: e.response?.data?['message'] ?? 'Network error',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return SubscribeResult(
        success: false,
        message: 'Failed to process subscription',
      );
    }
  }

  Future<bool> cancelSubscription() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.post('/api/vendor/subscription/cancel');

      if (response.data['success'] == true) {
        await loadCurrentSubscription();
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Failed to cancel',
        );
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Network error',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to cancel subscription',
      );
      return false;
    }
  }

  Future<bool> toggleAutoRenew() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.post('/api/vendor/subscription/toggle-auto-renew');

      if (response.data['success'] == true) {
        await loadCurrentSubscription();
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Failed to toggle auto-renew',
        );
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Network error',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to toggle auto-renew',
      );
      return false;
    }
  }

  Future<void> loadPaymentHistory() async {
    try {
      final response = await _api.get('/api/vendor/subscription/history');

      if (response.data['success'] == true) {
        final paymentsJson = response.data['payments'] as List;
        final payments = paymentsJson
            .map((json) => SubscriptionPaymentModel.fromJson(json))
            .toList();

        state = state.copyWith(paymentHistory: payments);
      }
    } catch (e) {
      // Silently fail for payment history
      print('Failed to load payment history: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ==================== SUBSCRIBE RESULT ====================
class SubscribeResult {
  final bool success;
  final String? message;
  final String? paymentUrl;
  final String? merchantReference;
  final int? subscriptionId;

  SubscribeResult({
    required this.success,
    this.message,
    this.paymentUrl,
    this.merchantReference,
    this.subscriptionId,
  });

  bool get requiresPayment => paymentUrl != null;
}

// ==================== PROVIDERS ====================

/// Main subscription state provider - uses the app's existing apiClientProvider
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final api = ref.watch(apiClientProvider);
  return SubscriptionNotifier(api, ref);
});

/// Get all available subscription plans
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/subscription-plans');

    if (response.data['success'] == true) {
      final plansJson = response.data['plans'] as List;
      return plansJson
          .map((json) => SubscriptionPlanModel.fromJson(json))
          .toList();
    }
    return [];
  } catch (e) {
    print('Failed to load subscription plans: $e');
    return [];
  }
});

/// Get current vendor subscription
final currentSubscriptionProvider = FutureProvider<VendorSubscriptionModel?>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/subscription');

    if (response.data['success'] == true && response.data['subscription'] != null) {
      return VendorSubscriptionModel.fromJson(response.data['subscription']);
    }
    return null;
  } catch (e) {
    print('Failed to load current subscription: $e');
    return null;
  }
});

/// Get subscription payment history
final subscriptionPaymentHistoryProvider =
    FutureProvider<List<SubscriptionPaymentModel>>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final response = await api.get('/api/vendor/subscription/history');

    if (response.data['success'] == true) {
      final paymentsJson = response.data['payments'] as List;
      return paymentsJson
          .map((json) => SubscriptionPaymentModel.fromJson(json))
          .toList();
    }
    return [];
  } catch (e) {
    print('Failed to load payment history: $e');
    return [];
  }
});
