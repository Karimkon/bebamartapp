// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/buyer/screens/buyer_shell.dart';
import 'features/buyer/screens/home_screen.dart';
import 'features/buyer/screens/cart_screen.dart';
import 'features/buyer/screens/orders_screen.dart';
import 'features/buyer/screens/profile_screen.dart';
import 'features/buyer/screens/product_detail_screen.dart';
import 'features/buyer/screens/wishlist_screen.dart';
import 'features/buyer/screens/categories_screen.dart';
import 'features/buyer/screens/category_screen.dart'; // Add this import
import 'features/buyer/screens/search_screen.dart';
import 'features/buyer/screens/checkout_screen.dart';
import 'features/buyer/screens/order_detail_screen.dart';
import 'features/vendor/screens/vendor_shell.dart';
import 'features/vendor/screens/vendor_dashboard_screen.dart';
import 'features/vendor/screens/vendor_products_screen.dart';
import 'features/vendor/screens/vendor_orders_screen.dart';
import 'features/vendor/screens/vendor_profile_screen.dart';
import 'features/vendor/screens/vendor_onboarding_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_detail_screen.dart';

// Auth state notifier for router refresh
class AuthStateNotifier extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  bool _isVendor = false;
  
  AuthStatus get status => _status;
  bool get isVendor => _isVendor;
  
  void update(AuthState authState) {
    final newStatus = authState.status;
    final newIsVendor = authState.isVendor;
    
    if (_status != newStatus || _isVendor != newIsVendor) {
      _status = newStatus;
      _isVendor = newIsVendor;
      notifyListeners();
    }
  }
}

final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  final notifier = AuthStateNotifier();
  
  // Listen to auth changes and update the notifier
  ref.listen<AuthState>(authProvider, (previous, next) {
    notifier.update(next);
  });
  
  // Initialize with current state
  notifier.update(ref.read(authProvider));
  
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final status = authNotifier.status;
      final isVendor = authNotifier.isVendor;
      final currentPath = state.uri.path;
      
      print('🚦 Router redirect: path=$currentPath, status=$status, isVendor=$isVendor');
      
      // While checking auth status, show splash
      if (status == AuthStatus.unknown) {
        if (currentPath != '/splash') {
          print('🔄 Redirecting to splash (auth unknown)');
          return '/splash';
        }
        return null;
      }
      
      final isAuthenticated = status == AuthStatus.authenticated;
      final isAuthRoute = currentPath == '/login' || 
                          currentPath == '/register' || 
                          currentPath == '/vendor-register' ||
                          currentPath == '/splash';
      
      // Public routes that don't require auth
      final isPublicRoute = currentPath.startsWith('/product') ||
                            currentPath == '/categories' ||
                            currentPath.startsWith('/category');
      
      // Vendor routes
      final isVendorRoute = currentPath.startsWith('/vendor');
      
      // User is NOT authenticated
      if (!isAuthenticated) {
        // Allow auth routes and public routes
        if (isAuthRoute || isPublicRoute) {
          // But redirect splash to login when not authenticated
          if (currentPath == '/splash') {
            print('🔄 Redirecting splash to login (unauthenticated)');
            return '/login';
          }
          return null;
        }
        // Redirect everything else to login
        print('🔄 Redirecting to login (not authenticated)');
        return '/login';
      }
      
      // User IS authenticated
      if (isAuthenticated) {
        // If on auth routes, redirect to appropriate home
        if (isAuthRoute) {
          final destination = isVendor ? '/vendor' : '/';
          print('🔄 Redirecting auth route to $destination (authenticated, isVendor=$isVendor)');
          return destination;
        }
        
        // Prevent buyers from accessing vendor routes
        if (isVendorRoute && !isVendor) {
          print('🔄 Buyer tried to access vendor route, redirecting to home');
          return '/';
        }
        
        // Prevent vendors from accessing buyer-only routes (like checkout without context)
        // But allow them to browse products
        
        // Allow all other routes
        return null;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/vendor-register',
        builder: (_, __) => const RegisterScreen(isVendor: true),
      ),
      
      // Buyer Shell with bottom navigation
      ShellRoute(
        builder: (_, __, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: '/wishlist',
            builder: (_, __) => const WishlistScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) => OrderDetailScreen(
              orderId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      
      // Routes outside the shell (no bottom nav)
      GoRoute(
        path: '/product/:id',
        builder: (_, state) => ProductDetailScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (_, __) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/category/:slug',
        name: 'category',
        builder: (_, state) => CategoryScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      
      // Chat routes
      GoRoute(
        path: '/chat',
        builder: (_, __) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatDetailScreen(
          conversationId: int.parse(state.pathParameters['id']!),
        ),
      ),
      
      // Vendor Shell with bottom navigation
      ShellRoute(
        builder: (_, __, child) => VendorShell(child: child),
        routes: [
          GoRoute(
            path: '/vendor',
            builder: (_, __) => const VendorDashboardScreen(),
          ),
          GoRoute(
            path: '/vendor/products',
            builder: (_, __) => const VendorProductsScreen(),
          ),
          GoRoute(
            path: '/vendor/orders',
            builder: (_, __) => const VendorOrdersScreen(),
          ),
          GoRoute(
            path: '/vendor/profile',
            builder: (_, __) => const VendorProfileScreen(),
          ),
        ],
      ),
      
      // Vendor onboarding (outside shell)
      GoRoute(
        path: '/vendor/onboarding',
        builder: (_, __) => const VendorOnboardingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri.path}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});