// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
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
            _registerDeviceToken();
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
  
  /// Registration result class
  /// Returns requires_verification: true if OTP verification is needed
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    String phone = '',
    required String password,
    required String passwordConfirmation,
    String role = 'buyer',
    dynamic profileImage,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🚀 Attempting registration for: $email');
      final data = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
      if (phone.isNotEmpty) {
        data['phone'] = phone;
      }
      final response = await _api.post(ApiEndpoints.register, data: data);

      print('📦 Registration response: ${response.statusCode}');
      print('📦 Registration data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;

        // Check if OTP verification is required
        if (data['requires_verification'] == true) {
          state = state.copyWith(isLoading: false);
          print('📧 OTP verification required for: $email');
          return {
            'success': true,
            'requires_verification': true,
            'email': data['email'] ?? email,
            'phone': data['phone'] ?? phone,
            'verification_type': data['verification_type'] ?? 'sms',
            'message': data['message'] ?? 'Please verify your phone',
          };
        }

        // If no OTP required (legacy flow), proceed with token
        final token = data['token'] ?? data['access_token'];
        if (token != null && token.isNotEmpty) {
          await _storage.saveToken(token);
          print('💾 Registration token saved');

          // Get user data
          final userResponse = await _api.get(ApiEndpoints.user);
          if (userResponse.statusCode == 200) {
            final user = UserModel.fromJson(userResponse.data);
            await _storage.saveUser(userResponse.data);
            await _storage.saveUserRole(user.role);
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: user,
              isLoading: false
            );
            _loadWishlistAfterAuth();
            _registerDeviceToken();
          }
        }

        return {'success': true, 'requires_verification': false};
      }

      print('❌ Registration failed - non-200 response');
      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return {'success': false, 'error': 'Registration failed'};

    } on DioException catch (e) {
      print('❌ DioException during registration: ${e.message}');
      print('📦 Response: ${e.response?.data}');

      String errorMessage = 'Registration failed';

      // First check for direct message field
      if (e.response?.data != null && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'].toString();
      }
      // Then check for validation errors
      else if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map && errors.isNotEmpty) {
          final firstErrors = errors.values.first;
          errorMessage = firstErrors is List ? firstErrors.first.toString() : firstErrors.toString();
        }
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      print('❌ Unexpected error during registration: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return {'success': false, 'error': 'Unexpected error'};
    }
  }

  /// Verify OTP code sent to email
  Future<bool> verifyOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔐 Verifying OTP for: $email');
      final response = await _api.post(ApiEndpoints.verifyOtp, data: {
        'email': email,
        'otp': otp,
      });

      print('📦 OTP verification response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        final token = data['token'];

        if (token != null) {
          await _storage.saveToken(token);

          final userData = data['user'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          await _storage.saveUser(userData);
          await _storage.saveUserRole(user.role);

          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
          );

          print('✅ OTP verified, user authenticated');
          _loadWishlistAfterAuth();
          return true;
        }
      }

      final errorMsg = response.data['message'] ?? 'OTP verification failed';
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;

    } on DioException catch (e) {
      print('❌ DioException during OTP verification: ${e.message}');
      String errorMessage = e.response?.data?['message'] ?? 'OTP verification failed';
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      print('❌ Unexpected error during OTP verification: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }

  /// Upload user avatar/profile picture
  Future<bool> uploadAvatar(dynamic imageFile) async {
    if (imageFile == null) return true;

    try {
      print('📷 Uploading avatar...');
      print('📷 File path: ${imageFile.path}');

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _api.post('/api/user/avatar', data: formData);

      print('📷 Upload response status: ${response.statusCode}');
      print('📷 Upload response data: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Avatar uploaded successfully');
        // Update user avatar in state
        if (state.user != null) {
          final updatedUser = state.user!.copyWith(
            avatar: response.data['avatar'],
          );
          state = state.copyWith(user: updatedUser);
        }
        return true;
      }
      print('❌ Avatar upload failed: ${response.data}');
      return false;
    } on DioException catch (e) {
      print('❌ DioException uploading avatar: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      print('❌ Status: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error uploading avatar: $e');
      return false;
    }
  }

  /// Resend OTP code
  Future<bool> resendOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('📧 Resending OTP to: $email');
      final response = await _api.post(ApiEndpoints.resendOtp, data: {
        'email': email,
      });

      state = state.copyWith(isLoading: false);

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ OTP resent successfully');
        return true;
      }

      state = state.copyWith(error: response.data['message'] ?? 'Failed to resend OTP');
      return false;

    } on DioException catch (e) {
      print('❌ Error resending OTP: ${e.message}');
      state = state.copyWith(isLoading: false, error: 'Failed to resend OTP');
      return false;
    } catch (e) {
      print('❌ Unexpected error resending OTP: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }

  /// Apple Sign-In
  Future<bool> signInWithApple({
    required String email,
    required String name,
    required String appleUserId,
    String? identityToken,
    String? authorizationCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🍎 Apple Sign-In for: $email');
      final response = await _api.post(ApiEndpoints.appleAuth, data: {
        'email': email,
        'name': name,
        'apple_user_id': appleUserId,
        'identity_token': identityToken,
        'authorization_code': authorizationCode,
      });

      print('📦 Apple auth response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        final token = data['token'];

        if (token != null) {
          await _storage.saveToken(token);

          final userData = data['user'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          await _storage.saveUser(userData);
          await _storage.saveUserRole(user.role);

          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
          );

          print('✅ Apple Sign-In successful');
          _loadWishlistAfterAuth();
          return true;
        }
      }

      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed');
      return false;

    } on DioException catch (e) {
      print('❌ DioException during Apple sign-in: ${e.message}');
      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed');
      return false;
    } catch (e) {
      print('❌ Unexpected error during Apple sign-in: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }

  /// Google Sign-In
  Future<bool> signInWithGoogle({
    required String email,
    required String name,
    required String googleId,
    String? avatar,
    String? idToken,
    String? accessToken,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔵 Google Sign-In for: $email');
      final response = await _api.post(ApiEndpoints.googleAuth, data: {
        'email': email,
        'name': name,
        'google_id': googleId,
        'avatar': avatar,
        'id_token': idToken,
        'access_token': accessToken,
      });

      print('📦 Google auth response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        final token = data['token'];

        if (token != null) {
          await _storage.saveToken(token);

          final userData = data['user'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          await _storage.saveUser(userData);
          await _storage.saveUserRole(user.role);

          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
          );

          print('✅ Google Sign-In successful');
          _loadWishlistAfterAuth();
          return true;
        }
      }

      state = state.copyWith(isLoading: false, error: 'Google sign-in failed');
      return false;

    } on DioException catch (e) {
      print('❌ DioException during Google sign-in: ${e.message}');
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed');
      return false;
    } catch (e) {
      print('❌ Unexpected error during Google sign-in: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error');
      return false;
    }
  }
  
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _removeDeviceToken();
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

  /// Register FCM device token with backend after login
  Future<void> _registerDeviceToken() async {
    try {
      final notifService = _ref.read(notificationServiceProvider);
      final token = await notifService.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.post(ApiEndpoints.deviceToken, data: {
          'token': token,
          'platform': notifService.platform,
          'device_name': notifService.deviceName,
        });
        print('📱 Device token registered');
      }
    } catch (e) {
      print('⚠️ Device token registration failed (non-critical): $e');
    }
  }

  /// Remove FCM device token from backend on logout
  Future<void> _removeDeviceToken() async {
    try {
      final notifService = _ref.read(notificationServiceProvider);
      final token = await notifService.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.delete(ApiEndpoints.deviceToken, data: {
          'token': token,
        });
        print('📱 Device token removed');
      }
    } catch (e) {
      print('⚠️ Device token removal failed (non-critical): $e');
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