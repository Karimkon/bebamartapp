// lib/core/services/notification_service.dart
// Push notification service using Firebase Cloud Messaging (FCM)

import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Top-level background handler (must be top-level function, not a method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // OS handles displaying the notification automatically in background
  // We just need this registered so background messages are received
}

class NotificationService {
  late final FirebaseMessaging _messaging;
  late final FlutterLocalNotificationsPlugin _localNotifications;
  String? _fcmToken;

  // Stream controller for notification taps (used for navigation)
  static final List<void Function(Map<String, dynamic>)> _tapListeners = [];

  NotificationService._();

  static Future<NotificationService> init() async {
    final instance = NotificationService._();
    instance._messaging = FirebaseMessaging.instance;
    instance._localNotifications = FlutterLocalNotificationsPlugin();

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS requires explicit ask; Android 13+ also)
    await instance._requestPermission();

    // Initialize local notifications for foreground display
    await instance._initLocalNotifications();

    // Get FCM token
    try {
      instance._fcmToken = await instance._messaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
    }

    // Listen for token refresh
    instance._messaging.onTokenRefresh.listen((newToken) {
      instance._fcmToken = newToken;
      // Token refresh will be handled by auth provider re-registering
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(instance._handleForegroundMessage);

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(instance._handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await instance._messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay to let the app fully initialize before navigating
      Future.delayed(const Duration(seconds: 2), () {
        instance._handleNotificationTap(initialMessage);
      });
    }

    return instance;
  }

  String? get fcmToken => _fcmToken;

  /// Get FCM token (fetches fresh if null)
  Future<String?> getToken() async {
    _fcmToken ??= await _messaging.getToken();
    return _fcmToken;
  }

  /// Platform name for device token registration
  String get platform => Platform.isIOS ? 'ios' : 'android';

  /// Simple device name
  String get deviceName => Platform.isIOS ? 'iPhone' : 'Android';

  /// Register a listener for notification taps (for navigation)
  static void addTapListener(void Function(Map<String, dynamic>) listener) {
    _tapListeners.add(listener);
  }

  /// Remove a tap listener
  static void removeTapListener(void Function(Map<String, dynamic>) listener) {
    _tapListeners.remove(listener);
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      print('Error requesting notification permission: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'bebamart_notifications',
      'BebaMart Notifications',
      description: 'Order updates, deals, and recommendations',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'bebamart_notifications',
            'BebaMart Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: message.notification?.android?.imageUrl != null
                ? null
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data.isNotEmpty) {
      for (final listener in _tapListeners) {
        listener(data);
      }
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        for (final listener in _tapListeners) {
          listener(data);
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  /// Update badge count on app icon
  Future<void> updateBadgeCount(int count) async {
    try {
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
      } else {
        FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      // Badge not supported on all devices
    }
  }
}

/// Riverpod provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
    'NotificationService must be initialized in main() and overridden',
  );
});
