// lib/features/notifications/providers/notification_provider.dart
// Riverpod providers for notification state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/notification_model.dart';
import '../../auth/providers/auth_provider.dart';

// ==================
// Unread Count Provider (for badges)
// ==================

final notificationUnreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.get(ApiEndpoints.notificationsUnreadCount);
    if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
      final count = response.data['unread_count'] as int? ?? 0;

      // Update app icon badge
      try {
        final notifService = ref.read(notificationServiceProvider);
        notifService.updateBadgeCount(count);
      } catch (_) {}

      return count;
    }
  } catch (e) {
    // Ignore errors (user might not be logged in)
  }
  return 0;
});

// ==================
// Notifications List Provider
// ==================

class NotificationsState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiClient _api;

  NotificationsNotifier(this._api) : super(const NotificationsState());

  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage + 1;

    state = state.copyWith(
      isLoading: true,
      error: null,
      notifications: refresh ? [] : null,
    );

    try {
      final response = await _api.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': page, 'per_page': 20},
      );

      if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
        final items = (response.data['notifications'] as List?)
                ?.map((e) =>
                    NotificationModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        final pagination = response.data['pagination'];
        final hasMore =
            pagination != null && pagination['current_page'] < pagination['last_page'];

        state = state.copyWith(
          notifications: refresh ? items : [...state.notifications, ...items],
          isLoading: false,
          hasMore: hasMore,
          currentPage: page,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications',
      );
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _api.post(ApiEndpoints.notificationRead(notificationId));

      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationModel(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              imageUrl: n.imageUrl,
              data: n.data,
              isRead: true,
              readAt: DateTime.now(),
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList(),
      );
    } catch (e) {
      // Ignore
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.post(ApiEndpoints.notificationsReadAll);

      state = state.copyWith(
        notifications: state.notifications
            .map((n) => NotificationModel(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  imageUrl: n.imageUrl,
                  data: n.data,
                  isRead: true,
                  readAt: DateTime.now(),
                  createdAt: n.createdAt,
                ))
            .toList(),
      );
    } catch (e) {
      // Ignore
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.read(apiClientProvider));
});

// ==================
// Notification Preferences Provider
// ==================

class NotifPrefsNotifier extends StateNotifier<NotificationPreferencesModel?> {
  final ApiClient _api;

  NotifPrefsNotifier(this._api) : super(null);

  Future<void> loadPreferences() async {
    try {
      final response = await _api.get(ApiEndpoints.notificationPreferences);
      if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
        state = NotificationPreferencesModel.fromJson(
          response.data['preferences'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      // Use defaults
      state = NotificationPreferencesModel();
    }
  }

  Future<void> updatePreferences(NotificationPreferencesModel prefs) async {
    state = prefs;
    try {
      await _api.put(
        ApiEndpoints.notificationPreferences,
        data: prefs.toJson(),
      );
    } catch (e) {
      // Revert on failure
      await loadPreferences();
    }
  }

  void updateField(String field, bool value) {
    if (state == null) return;

    final updated = switch (field) {
      'push_enabled' => state!.copyWith(pushEnabled: value),
      'email_enabled' => state!.copyWith(emailEnabled: value),
      'order_updates' => state!.copyWith(orderUpdates: value),
      'promotions' => state!.copyWith(promotions: value),
      'recommendations' => state!.copyWith(recommendations: value),
      'price_drops' => state!.copyWith(priceDrops: value),
      'cart_reminders' => state!.copyWith(cartReminders: value),
      'new_orders' => state!.copyWith(newOrders: value),
      'reviews' => state!.copyWith(reviews: value),
      'payouts' => state!.copyWith(payouts: value),
      'vendor_tips' => state!.copyWith(vendorTips: value),
      _ => state!,
    };

    updatePreferences(updated);
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotifPrefsNotifier, NotificationPreferencesModel?>((ref) {
  return NotifPrefsNotifier(ref.read(apiClientProvider));
});
