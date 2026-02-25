// lib/core/services/notification_service.dart
// Push notification service using Firebase Cloud Messaging (FCM)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

  // Callback invoked when FCM rotates the device token — used to re-register with backend
  static void Function(String newToken)? _tokenRefreshCallback;

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

    // Listen for token refresh — FCM rotates tokens periodically.
    // We must re-register the new token with the backend immediately,
    // otherwise the old token gets deactivated and notifications stop.
    instance._messaging.onTokenRefresh.listen((newToken) {
      instance._fcmToken = newToken;
      _tokenRefreshCallback?.call(newToken);
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

  /// Register a callback that fires when FCM rotates the device token.
  /// Call this from the auth layer so the new token gets sent to the backend.
  static void setTokenRefreshCallback(void Function(String newToken) callback) {
    _tokenRefreshCallback = callback;
  }

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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Image URL from FCM notification or data payload
    final imageUrl = notification.android?.imageUrl ??
        notification.apple?.imageUrl ??
        message.data['image_url'] as String?;

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Download image to temp file for BigPicture style
      final imagePath = await _downloadImageToTemp(imageUrl);
      if (imagePath != null) {
        androidDetails = AndroidNotificationDetails(
          'bebamart_notifications',
          'BebaMart Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF6C63FF), // BebaMart brand purple
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            largeIcon: FilePathAndroidBitmap(imagePath),
            contentTitle: notification.title,
            summaryText: notification.body,
            htmlFormatContentTitle: false,
            htmlFormatSummaryText: false,
          ),
        );
      } else {
        androidDetails = _defaultAndroidDetails();
      }
    } else {
      androidDetails = _defaultAndroidDetails();
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: [], // iOS images are handled by FCM directly
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  AndroidNotificationDetails _defaultAndroidDetails() {
    return const AndroidNotificationDetails(
      'bebamart_notifications',
      'BebaMart Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF6C63FF),
    );
  }

  /// Downloads a remote image URL to a temp file and returns the local path.
  /// Returns null if download fails (so we gracefully fall back to text-only).
  Future<String?> _downloadImageToTemp(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      // Use a hash of the URL as filename so we cache repeat images
      final fileName = 'notif_${url.hashCode.abs()}.jpg';
      final file = File('${dir.path}/$fileName');

      if (!file.existsSync()) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await response.fold<List<int>>(
            [],
            (acc, chunk) => acc..addAll(chunk),
          );
          await file.writeAsBytes(bytes);
        }
        client.close();
      }

      return file.existsSync() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data.isNotEmpty) {
      // Delay ensures app is fully foregrounded and router is ready before navigating
      Future.delayed(const Duration(milliseconds: 500), () {
        for (final listener in _tapListeners) {
          listener(data);
        }
      });
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        // Delay ensures the local notification tap navigates after the frame settles
        Future.delayed(const Duration(milliseconds: 300), () {
          for (final listener in _tapListeners) {
            listener(data);
          }
        });
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
