// lib/core/network/api_client.dart
// API client for communicating with Laravel backend

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../services/storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService _storage;
  
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available
        final token = await _storage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Add CSRF token for Laravel (cookie-based sessions)
        final csrfToken = await _storage.getCsrfToken();
        if (csrfToken != null && csrfToken.isNotEmpty) {
          options.headers['X-CSRF-TOKEN'] = csrfToken;
        }
        
        if (kDebugMode) {
          print('🚀 REQUEST: ${options.method} ${options.uri}');
          print('   Headers: ${options.headers}');
          if (options.data != null) print('   Data: ${options.data}');
        }
        
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
        }
        
        // Extract CSRF token from response if present
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          for (final cookie in setCookie) {
            if (cookie.contains('XSRF-TOKEN')) {
              final tokenStart = cookie.indexOf('XSRF-TOKEN=') + 11;
              final tokenEnd = cookie.indexOf(';', tokenStart);
              final token = Uri.decodeComponent(
                cookie.substring(tokenStart, tokenEnd > 0 ? tokenEnd : cookie.length)
              );
              _storage.saveCsrfToken(token);
            }
          }
        }
        
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print('❌ ERROR: ${error.response?.statusCode} ${error.requestOptions.uri}');
          print('   Message: ${error.message}');
          print('   Response: ${error.response?.data}');
        }

        // Handle 401 Unauthorized - token expired or invalid
        // Only clear auth data if we actually had a token that was rejected
        if (error.response?.statusCode == 401) {
          final hadToken = error.requestOptions.headers['Authorization'] != null;
          if (hadToken) {
            if (kDebugMode) {
              print('🔑 Token rejected - clearing auth data');
            }
            await _storage.clearAuthData();
            // Auth state listener will handle navigation to login
          } else {
            if (kDebugMode) {
              print('⚠️ 401 without token - endpoint requires auth');
            }
          }
        }

        // Handle 419 - CSRF token mismatch
        if (error.response?.statusCode == 419) {
          // Refresh CSRF token and retry
          await _refreshCsrfToken();
        }

        // Handle 422 - Validation errors
        if (error.response?.statusCode == 422) {
          // Keep the response data for form validation display
        }

        return handler.next(error);
      },
    ));
  }
  
  Future<void> _refreshCsrfToken() async {
    try {
      await _dio.get('/sanctum/csrf-cookie');
    } catch (e) {
      if (kDebugMode) print('Failed to refresh CSRF token: $e');
    }
  }
  
  // Initialize CSRF token (call before first API request)
  Future<void> initCsrf() async {
    await _refreshCsrfToken();
  }
  
  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // Multipart file upload
  Future<Response> uploadFile(
    String path, {
    required String filePath,
    required String fileKey,
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      ...?data,
      fileKey: await MultipartFile.fromFile(filePath),
    });
    
    return _dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }
  
  // Multiple file upload
  Future<Response> uploadMultipleFiles(
    String path, {
    required List<String> filePaths,
    required String fileKey,
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    final files = await Future.wait(
      filePaths.map((path) => MultipartFile.fromFile(path)),
    );
    
    final formData = FormData.fromMap({
      ...?data,
      fileKey: files,
    });
    
    return _dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }
}

// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;
  final int? statusCode;
  
  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
    this.statusCode,
  });
  
  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
      statusCode: statusCode,
    );
  }
  
  factory ApiResponse.error(String message, {Map<String, dynamic>? errors, int? statusCode}) {
    return ApiResponse(
      success: false,
      message: message,
      errors: errors,
      statusCode: statusCode,
    );
  }
  
  factory ApiResponse.fromDioError(DioException e) {
    String message;
    Map<String, dynamic>? errors;
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        break;
      case DioExceptionType.badResponse:
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? 'Something went wrong';
          errors = responseData['errors'] as Map<String, dynamic>?;
        } else {
          message = 'Server error: ${e.response?.statusCode}';
        }
        break;
      default:
        message = 'Something went wrong. Please try again.';
    }
    
    return ApiResponse.error(
      message,
      errors: errors,
      statusCode: e.response?.statusCode,
    );
  }
  
  // Get first error message from validation errors
  String? get firstError {
    if (errors == null || errors!.isEmpty) return null;
    final firstKey = errors!.keys.first;
    final firstErrors = errors![firstKey];
    if (firstErrors is List && firstErrors.isNotEmpty) {
      return firstErrors.first.toString();
    }
    return firstErrors?.toString();
  }
  
  // Get error for specific field
  String? errorFor(String field) {
    if (errors == null || !errors!.containsKey(field)) return null;
    final fieldErrors = errors![field];
    if (fieldErrors is List && fieldErrors.isNotEmpty) {
      return fieldErrors.first.toString();
    }
    return fieldErrors?.toString();
  }
}
