// lib/main.dart
// BebaMart Flutter App Entry Point

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize storage service
  final storageService = await StorageService.init();

  // Initialize notification service
  final notificationService = await NotificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const BebaMartApp(),
    ),
  );
}

class BebaMartApp extends ConsumerStatefulWidget {
  const BebaMartApp({super.key});

  @override
  ConsumerState<BebaMartApp> createState() => _BebaMartAppState();
}

class _BebaMartAppState extends ConsumerState<BebaMartApp> {
  late final void Function(Map<String, dynamic>) _notificationTapHandler;

  @override
  void initState() {
    super.initState();
    _notificationTapHandler = (data) {
      // Resolve route: use explicit 'route' key first, then fall back by type
      final String route = _resolveNotificationRoute(data);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.read(routerProvider).push(route);
        } catch (_) {
          ref.read(routerProvider).go(route);
        }
      });
    };
    NotificationService.addTapListener(_notificationTapHandler);
  }

  /// Determine where to navigate when a notification is tapped.
  /// Uses the explicit 'route' key from notification data if present,
  /// otherwise maps notification 'type' to a sensible screen.
  String _resolveNotificationRoute(Map<String, dynamic> data) {
    final explicit = data['route'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;

    // Type-based fallbacks for manually sent or legacy notifications
    final type = data['type'] as String? ?? '';
    return switch (type) {
      'cart_reminder'  => '/cart',
      'order_update'   => '/orders',
      'vendor_order'   => '/vendor/orders',
      'vendor_payout'  => '/vendor/wallet',
      'vendor_review'  => '/vendor/dashboard',
      'price_drop'     => '/wishlist',
      'admin_message'  => '/notifications',
      _                => '/home',
    };
  }

  @override
  void dispose() {
    NotificationService.removeTapListener(_notificationTapHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BebaMart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
