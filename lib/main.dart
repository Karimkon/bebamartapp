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
      final route = data['route'] as String?;
      if (route == null || route.isEmpty) return;
      // Use postFrameCallback so navigation fires after the current frame
      // and the router is guaranteed to be in a stable state
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
