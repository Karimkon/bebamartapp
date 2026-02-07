// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Auth
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/otp_verification_screen.dart';

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
import 'features/buyer/screens/edit_profile_screen.dart';
import 'features/buyer/screens/shipping_addresses_screen.dart';
import 'features/buyer/screens/wallet_screen.dart';
import 'features/buyer/screens/my_reviews_screen.dart';
import 'features/buyer/screens/help_support_screen.dart';
import 'features/buyer/screens/settings_screen.dart';
import 'features/buyer/screens/payment_webview_screen.dart';
import 'features/buyer/screens/services_screen.dart';
import 'features/buyer/screens/service_detail_screen.dart';
import 'features/buyer/screens/jobs_screen.dart';
import 'features/buyer/screens/job_detail_screen.dart';

// Vendor
import 'features/vendor/screens/vendor_shell.dart';
import 'features/vendor/screens/vendor_dashboard_screen.dart';
import 'features/vendor/screens/vendor_products_screen.dart';
import 'features/vendor/screens/create_listing_screen.dart';
import 'features/vendor/screens/vendor_orders_screen.dart';
import 'features/vendor/screens/vendor_order_detail_screen.dart';
import 'features/vendor/screens/vendor_profile_screen.dart';
import 'features/vendor/screens/vendor_onboarding_screen.dart';
import 'features/vendor/screens/vendor_wallet_screen.dart';
import 'features/vendor/screens/vendor_notifications_screen.dart';
import 'features/vendor/screens/vendor_analytics_screen.dart';
import 'features/vendor/screens/create_service_screen.dart';
import 'features/vendor/screens/subscription_screen.dart';

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

      // Debug: Log redirect checks for vendor service routes
      if (location.contains('service')) {
        print('🔀 Router redirect check: location=$location, isLoggedIn=$isLoggedIn, isLoading=$isLoading');
      }

      // NEVER redirect away from OTP verification
      if (location == '/verify-otp') {
        return null;
      }

      // Routes that require authentication
      const protectedRoutes = [
        '/checkout',
        '/orders',
        '/buyer/orders',
        '/profile',
        '/vendor',
        '/vendor/dashboard',
        '/vendor/products',
        '/vendor/orders',
        '/vendor/profile',
        '/vendor/onboarding',
        '/vendor/products/create',
        '/vendor/services/create',
        '/chat',
      ];

      // Routes accessible to guests (browsing without login)
      const guestRoutes = [
        '/home',
        '/categories',
        '/cart',
        '/wishlist',
        '/search',
        '/services',
        '/jobs',
      ];

      // Special handling for splash: once auth check completes, navigate away
      if (location == '/splash') {
        if (isLoading) return null; // still checking
        // Always go to home first - let users browse
        if (!isLoggedIn) return '/home';
        final user = authState.user;
        if (user != null && user.isVendor) {
          return user.vendorProfile?.vettingStatus == 'approved'
              ? '/home'
              : '/vendor/onboarding';
        }
        return '/home';
      }

      // Handle root path '/'
      if (location == '/') {
        if (isLoading) return null;
        if (!isLoggedIn) return '/home';
        final user = authState.user;
        if (user != null && user.isVendor) {
          return user.vendorProfile?.vettingStatus == 'approved'
              ? '/home'
              : '/vendor/onboarding';
        }
        return '/home';
      }

      // Don't redirect while loading for other routes
      if (isLoading) return null;

      // Auth routes - but NOT verify-otp
      final isAuthRoute = location == '/login' ||
                          location == '/register' ||
                          location == '/register/vendor';

      // Check if current route is protected
      final isProtectedRoute = protectedRoutes.any((route) =>
        location == route || location.startsWith('$route/')
      );

      // Check if current route allows guests (product detail, category)
      final isGuestAllowed = guestRoutes.contains(location) ||
          location.startsWith('/product/') ||
          location.startsWith('/category/') ||
          location.startsWith('/service/') ||
          location.startsWith('/job/');

      // If not logged in and trying to access protected route
      if (!isLoggedIn && isProtectedRoute) return '/login';

      // If logged in and on auth route, redirect to appropriate dashboard
      if (isLoggedIn && isAuthRoute) {
        final user = authState.user;
        if (user != null && user.isVendor) {
          return user.vendorProfile?.vettingStatus == 'approved'
              ? '/home'
              : '/vendor/onboarding';
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
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          // Support both old format (String) and new format (Map)
          String email = '';
          String? phone;
          String? profileImagePath;
          String verificationType = 'sms'; // Default to SMS

          if (state.extra is String) {
            email = state.extra as String;
          } else if (state.extra is Map) {
            final data = state.extra as Map;
            email = data['email'] ?? '';
            phone = data['phone'];
            profileImagePath = data['profileImagePath'];
            verificationType = data['verificationType'] ?? 'sms';
          }

          return OtpVerificationScreen(
            email: email,
            phone: phone,
            profileImagePath: profileImagePath,
            verificationType: verificationType,
          );
        },
      ),
      // Vendor Registration Route
      GoRoute(
        path: '/register/vendor',
        builder: (context, state) => const RegisterScreen(isVendor: true),
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
          GoRoute(
            path: '/services',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ServicesScreen(),
            ),
          ),
          GoRoute(
            path: '/jobs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: JobsScreen(),
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
        path: '/service/:slug',
        builder: (context, state) => ServiceDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      GoRoute(
        path: '/job/:slug',
        builder: (context, state) => JobDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/payment/:orderId',
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentWebViewScreen(
            orderId: orderId,
            paymentUrl: extra?['paymentUrl'] ?? '',
            orderNumber: extra?['orderNumber'] ?? '',
          );
        },
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

      // Profile sub-routes
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (context, state) => const ShippingAddressesScreen(),
      ),
      GoRoute(
        path: '/profile/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/profile/reviews',
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: '/profile/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/profile/settings',
        builder: (context, state) => const SettingsScreen(),
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
          // Default route - Redirect to dashboard (Shop tab now goes to /home)
          GoRoute(
            path: '/vendor',
            redirect: (context, state) => '/vendor/dashboard',
          ),
          GoRoute(
            path: '/vendor/dashboard',
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
            path: '/vendor/messages',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatListScreen(),
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
      GoRoute(
        path: '/vendor/wallet',
        builder: (context, state) => const VendorWalletScreen(),
      ),
      GoRoute(
        path: '/vendor/notifications',
        builder: (context, state) => const VendorNotificationsScreen(),
      ),
      GoRoute(
        path: '/vendor/analytics',
        builder: (context, state) => const VendorAnalyticsScreen(),
      ),
      GoRoute(
        path: '/vendor/services/create',
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/vendor/subscription',
        builder: (context, state) => const SubscriptionScreen(),
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