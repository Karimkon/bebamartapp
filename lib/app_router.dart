// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Auth
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';

// Buyer
import 'features/buyer/screens/buyer_shell.dart';
import 'features/buyer/screens/home_screen.dart';
import 'features/buyer/screens/categories_screen.dart';
import 'features/buyer/screens/category_screen.dart';
import 'features/buyer/screens/product_detail_screen.dart';
import 'features/buyer/screens/cart_screen.dart';
import 'features/buyer/screens/checkout_screen.dart';
import 'features/buyer/screens/wishlist_screen.dart';
import 'features/buyer/screens/orders_screen.dart';
import 'features/buyer/screens/order_detail_screen.dart';
import 'features/buyer/screens/profile_screen.dart';
import 'features/buyer/screens/search_screen.dart';

// Vendor
import 'features/vendor/screens/vendor_shell.dart';
import 'features/vendor/screens/vendor_dashboard_screen.dart';
import 'features/vendor/screens/vendor_products_screen.dart';
import 'features/vendor/screens/create_listing_screen.dart';
import 'features/vendor/screens/vendor_orders_screen.dart';
import 'features/vendor/screens/vendor_order_detail_screen.dart';
import 'features/vendor/screens/vendor_profile_screen.dart';
import 'features/vendor/screens/vendor_onboarding_screen.dart';

// Chat
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final location = state.matchedLocation;

      // Special handling for splash: once auth check completes, navigate away
      if (location == '/splash') {
        if (isLoading) return null; // still checking
        if (!isLoggedIn) return '/login';
        final user = authState.user;
        if (user != null) {
          if (user.isVendor) {
            return user.vendorProfile?.vettingStatus == 'approved'
                ? '/vendor'
                : '/vendor/onboarding';
          }
          return '/home';
        }
        return '/home';
      }

      // Handle root path '/' — redirect to appropriate landing (home or vendor)
      if (location == '/') {
        if (isLoading) return null;
        if (!isLoggedIn) return '/login';
        final user = authState.user;
        if (user != null) {
          if (user.isVendor) {
            return user.vendorProfile?.vettingStatus == 'approved'
                ? '/vendor'
                : '/vendor/onboarding';
          }
          return '/home';
        }
        return '/home';
      }

      // Don't redirect while loading for other routes
      if (isLoading) return null;

      // Auth-only routes (exclude splash since handled above)
      final isAuthRoute = location == '/login' || location == '/register';

      // If not logged in and trying to access protected route
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // If logged in and on auth route, redirect to appropriate dashboard
      if (isLoggedIn && isAuthRoute) {
        final user = authState.user;
        if (user != null) {
          if (user.isVendor) {
            return user.vendorProfile?.vettingStatus == 'approved'
                ? '/vendor'
                : '/vendor/onboarding';
          }
          return '/home';
        }
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ==================== BUYER ROUTES ====================
      ShellRoute(
        builder: (context, state, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/categories',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CategoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
          ),
          GoRoute(
            path: '/wishlist',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WishlistScreen(),
            ),
          ),
          GoRoute(
            path: '/buyer/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          // Legacy/shortcut route used elsewhere in the app
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Buyer routes outside shell (full screen)
      GoRoute(
        path: '/category/:slug',
        builder: (context, state) => CategoryScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return OrderDetailScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),

      // ==================== VENDOR ROUTES ====================
      // Vendor Onboarding (for pending vendors)
      GoRoute(
        path: '/vendor/onboarding',
        builder: (context, state) => const VendorOnboardingScreen(),
      ),

      // Vendor Shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(
            path: '/vendor',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/products',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorProductsScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorOrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorProfileScreen(),
            ),
          ),
        ],
      ),

      // Vendor routes outside shell (full screen)
      GoRoute(
        path: '/vendor/products/create',
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: '/vendor/products/:id/edit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return CreateListingScreen(listingId: id);
        },
      ),
      GoRoute(
        path: '/vendor/orders/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return VendorOrderDetailScreen(orderId: id);
        },
      ),

      // ==================== CHAT ROUTES ====================
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ChatDetailScreen(conversationId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});