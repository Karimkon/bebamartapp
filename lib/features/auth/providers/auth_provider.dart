// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/user_model.dart';
import '../../buyer/providers/wishlist_provider.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;
  
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
  });
  
  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
  
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isVendor => user?.isVendor ?? false;
  bool get isBuyer => user?.isBuyer ?? false;
  bool get isAdmin => user?.isAdmin ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService _storage;
  final ApiClient _api;
  final Ref _ref;
  
  AuthNotifier(this._storage, this._api, this._ref) : super(const AuthState()) {
    _checkAuthStatus();
  }
  
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    print('🔄 AuthNotifier: Checking auth status...');
    try {
      final hasToken = await _storage.hasToken();
      print('🔑 Has token: $hasToken');
      
      if (!hasToken) {
        state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
        print('👤 No token - unauthenticated');
        return;
      }
      
      final response = await _api.get(ApiEndpoints.user);
      print('📦 /api/user status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final user = UserModel.fromJson(response.data);
          print('✅ User restored: ${user.email}');
          
          await _storage.saveUser(response.data);
          await _storage.saveUserRole(user.role);
          
          state = state.copyWith(
            status: AuthStatus.authenticated, 
            user: user, 
            isLoading: false
          );
          print('🎉 User authenticated from stored token');
          _loadWishlistAfterAuth();
        } catch (e) {
          print('❌ Error parsing stored user: $e');
          // Use cached data
          final cachedUser = _storage.getUser();
          if (cachedUser != null) {
            try {
              final user = UserModel.fromJson(cachedUser);
              state = state.copyWith(
                status: AuthStatus.authenticated, 
                user: user, 
                isLoading: false
              );
              print('🔄 Using cached user data');
            } catch (e2) {
              print('❌ Even cached data failed: $e2');
              state = state.copyWith(
                status: AuthStatus.unauthenticated, 
                isLoading: false
              );
            }
          } else {
            state = state.copyWith(
              status: AuthStatus.unauthenticated, 
              isLoading: false
            );
          }
        }
      } else {
        await _storage.clearAuthData();
        state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
        print('❌ Token invalid - cleared auth data');
      }
    } catch (e) {
      print('❌ Auth check error: $e');
      final cachedUser = _storage.getUser();
      if (cachedUser != null) {
        try {
          final user = UserModel.fromJson(cachedUser);
          state = state.copyWith(
            status: AuthStatus.authenticated, 
            user: user, 
            isLoading: false
          );
          print('🔄 Using cached user after error');
        } catch (e) {
          print('❌ Cached user also invalid');
          state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
        }
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
      }
    }
  }
  
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🚀 Attempting login for: $email');
      final response = await _api.post(ApiEndpoints.login, data: {'email': email, 'password': password});
      
      print('📦 Login response status: ${response.statusCode}');
      print('📦 Login response data: ${response.data}');
      
      if (response.statusCode == 200) {
        // Extract token - check both 'token' and 'access_token'
        final token = response.data is Map 
            ? (response.data['token'] ?? response.data['access_token']) as String?
            : null;
        
        print('🔑 Token received: ${token != null ? 'YES' : 'NO'}');
        
        if (token != null && token.isNotEmpty) {
          await _storage.saveToken(token);
          print('💾 Token saved to storage');
        } else {
          print('⚠️ No token in login response');
        }

        // Try to get user data
        final userResponse = await _api.get(ApiEndpoints.user);
        print('👤 User endpoint status: ${userResponse.statusCode}');
        print('👤 User endpoint data: ${userResponse.data}');
        
        if (userResponse.statusCode == 200) {
          try {
            final user = UserModel.fromJson(userResponse.data);
            print('✅ User parsed: ${user.email} (ID: ${user.id})');
            
            await _storage.saveUser(userResponse.data);
            await _storage.saveUserRole(user.role);
            
            state = state.copyWith(
              status: AuthStatus.authenticated, 
              user: user, 
              isLoading: false
            );
            print('🎉 Login successful!');
            _loadWishlistAfterAuth();
            return true;
          } catch (e) {
            print('❌ User parsing error: $e');
            print('📦 Raw user data: ${userResponse.data}');
            
            // Fallback: Extract role from response if possible
            String fallbackRole = 'buyer';
            if (userResponse.data is Map) {
              final userData = userResponse.data['data'] ?? userResponse.data;
              fallbackRole = userData['role']?.toString() ?? 'buyer';
            }
            
            final fallbackUser = UserModel(
              id: 0,
              phone: '', // Empty phone
              role: fallbackRole,
              email: email,
            );
            
            // Save user data with actual role
            await _storage.saveUser({
              'id': 0,
              'email': email,
              'role': fallbackRole
            });
            await _storage.saveUserRole(fallbackRole);
            
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: fallbackUser,
              isLoading: false,
            );
            print('⚠️ Using fallback user with role: $fallbackRole');
            return true;
          }
        } else {
          // User endpoint failed, but login was successful
          print('⚠️ /api/user failed but login succeeded');
          
          // Try to get role from login response
          String fallbackRole = 'buyer';
          if (response.data is Map) {
            final userData = response.data['user'] ?? response.data;
            if (userData is Map) {
              fallbackRole = userData['role']?.toString() ?? 'buyer';
            }
          }
          
          final fallbackUser = UserModel(
            id: 0,
            phone: '',
            role: fallbackRole,
            email: email,
          );
          
          // Save minimal data with actual role
          await _storage.saveUser({
            'id': 0,
            'email': email,
            'role': fallbackRole
          });
          await _storage.saveUserRole(fallbackRole);
          
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: fallbackUser,
            isLoading: false,
          );
          print('⚠️ Using fallback user with role: $fallbackRole');
          return true;
        }
      }
      
      // Login failed
      print('❌ Login failed - non-200 response');
      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
      
    } on DioException catch (e) {
      print('❌ DioException during login: ${e.message}');
      print('📦 Response: ${e.response?.data}');
      
      String errorMessage = 'Login failed';
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map && errors.isNotEmpty) {
          final firstErrors = errors.values.first;
          errorMessage = firstErrors is List ? firstErrors.first.toString() : firstErrors.toString();
        }
      } else if (e.response?.statusCode == 401) {
        errorMessage = 'Invalid email or password';
      }
      
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      print('❌ Unexpected error during login: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }
  
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String role = 'buyer',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🚀 Attempting registration for: $email');
      final response = await _api.post(ApiEndpoints.register, data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      });
      
      print('📦 Registration response: ${response.statusCode}');
      print('📦 Registration data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 302) {
        // Save token if provided by backend
        final token = response.data is Map 
            ? (response.data['token'] ?? response.data['access_token']) as String?
            : null;
        
        if (token != null && token.isNotEmpty) {
          await _storage.saveToken(token);
          print('💾 Registration token saved');
        }

        // Get user data
        final userResponse = await _api.get(ApiEndpoints.user);
        print('👤 User endpoint after registration: ${userResponse.statusCode}');
        print('👤 User endpoint data: ${userResponse.data}');
        
        if (userResponse.statusCode == 200) {
          try {
            final user = UserModel.fromJson(userResponse.data);
            print('✅ Registered user parsed: ${user.email}');
            
            await _storage.saveUser(userResponse.data);
            await _storage.saveUserRole(user.role);
            
            state = state.copyWith(
              status: AuthStatus.authenticated, 
              user: user, 
              isLoading: false
            );
            print('🎉 Registration successful!');
            _loadWishlistAfterAuth();
            return true;
          } catch (e) {
            print('❌ Error parsing registered user: $e');
            print('📦 Raw user data: ${userResponse.data}');
            
            // Fallback with provided data
            final fallbackUser = UserModel(
              id: 0,
              phone: phone,
              role: role,
              email: email,
              name: name,
            );
            
            await _storage.saveUser({
              'id': 0,
              'name': name,
              'email': email,
              'phone': phone,
              'role': role
            });
            await _storage.saveUserRole(role);
            
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: fallbackUser,
              isLoading: false,
            );
            print('⚠️ Using fallback user for registration');
            _loadWishlistAfterAuth();
            return true;
          }
        } else {
          // User endpoint failed but registration succeeded
          print('⚠️ /api/user failed but registration succeeded');
          
          final fallbackUser = UserModel(
            id: 0,
            phone: phone,
            role: role,
            email: email,
            name: name,
          );
          
          await _storage.saveUser({
            'id': 0,
            'name': name,
            'email': email,
            'phone': phone,
            'role': role
          });
          await _storage.saveUserRole(role);
          
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: fallbackUser,
            isLoading: false,
          );
          print('⚠️ Using fallback user - /api/user endpoint failed');
          _loadWishlistAfterAuth();
          return true;
        }
      }
      
      print('❌ Registration failed - non-200 response');
      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return false;
      
    } on DioException catch (e) {
      print('❌ DioException during registration: ${e.message}');
      print('📦 Response: ${e.response?.data}');
      
      String errorMessage = 'Registration failed';
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map && errors.isNotEmpty) {
          final firstErrors = errors.values.first;
          errorMessage = firstErrors is List ? firstErrors.first.toString() : firstErrors.toString();
        }
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      print('❌ Unexpected error during registration: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }
  
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try { 
      await _api.post(ApiEndpoints.logout); 
      print('👋 Logout API called');
    } catch (e) {
      print('⚠️ Logout API error (ignored): $e');
    }
    await _storage.clearAuthData();
    print('🗑️ Auth data cleared from storage');
    state = const AuthState(status: AuthStatus.unauthenticated);
    print('👤 User logged out');
  }
  
  Future<void> refreshUser() async {
    print('🔄 Refreshing user data...');
    try {
      final response = await _api.get(ApiEndpoints.user);
      if (response.statusCode == 200) {
        try {
          final user = UserModel.fromJson(response.data);
          await _storage.saveUser(response.data);
          state = state.copyWith(user: user);
          print('✅ User refreshed: ${user.email}');
        } catch (e) {
          print('❌ Error parsing refreshed user: $e');
        }
      } else {
        print('⚠️ User refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error refreshing user: $e');
    }
  }
  
  void clearError() {
    print('🧹 Clearing error');
    state = state.copyWith(error: null);
  }
  
  void _loadWishlistAfterAuth() {
    try {
      // Load wishlist after authentication
      Future.microtask(() {
        _ref.read(wishlistProvider.notifier).loadWishlist();
      });
    } catch (e) {
      print('❌ Error loading wishlist after auth: $e');
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(storageServiceProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(storageServiceProvider), ref.watch(apiClientProvider), ref);
});

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authProvider).isAuthenticated);
final isVendorProvider = Provider<bool>((ref) => ref.watch(authProvider).isVendor);
final isBuyerProvider = Provider<bool>((ref) => ref.watch(authProvider).isBuyer);
final authStatusProvider = Provider<AuthStatus>((ref) => ref.watch(authProvider).status);
// Legacy alias used across the app
final authStateProvider = authProvider;