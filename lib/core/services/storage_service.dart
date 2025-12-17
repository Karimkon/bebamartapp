// lib/core/services/storage_service.dart
// Secure storage service for auth tokens and user data

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  late final FlutterSecureStorage _secureStorage;
  late final SharedPreferences _prefs;
  
  StorageService._();
  
  static Future<StorageService> init() async {
    final instance = StorageService._();
    instance._secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    instance._prefs = await SharedPreferences.getInstance();
    return instance;
  }
  
  // ==================
  // Auth Token (Secure)
  // ==================
  
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }
  
  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }
  
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
  }
  
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // ==================
  // CSRF Token (for Laravel)
  // ==================
  
  Future<void> saveCsrfToken(String token) async {
    await _prefs.setString('csrf_token', token);
  }
  
  Future<String?> getCsrfToken() async {
    return _prefs.getString('csrf_token');
  }
  
  // ==================
  // User Data
  // ==================
  
  Future<void> saveUser(Map<String, dynamic> userData) async {
    await _prefs.setString(AppConstants.userKey, jsonEncode(userData));
  }
  
  Map<String, dynamic>? getUser() {
    final userData = _prefs.getString(AppConstants.userKey);
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }
  
  Future<void> deleteUser() async {
    await _prefs.remove(AppConstants.userKey);
  }
  
  // ==================
  // User Role
  // ==================
  
  Future<void> saveUserRole(String role) async {
    await _prefs.setString(AppConstants.userRoleKey, role);
  }
  
  String? getUserRole() {
    return _prefs.getString(AppConstants.userRoleKey);
  }
  
  bool isVendor() {
    final role = getUserRole();
    return role == AppConstants.roleVendorLocal || 
           role == AppConstants.roleVendorInternational;
  }
  
  bool isBuyer() {
    final role = getUserRole();
    return role == AppConstants.roleBuyer;
  }
  
  bool isAdmin() {
    final role = getUserRole();
    return role == AppConstants.roleAdmin;
  }
  
  // ==================
  // Vendor Profile Data
  // ==================
  
  Future<void> saveVendorProfile(Map<String, dynamic> vendorData) async {
    await _prefs.setString('vendor_profile', jsonEncode(vendorData));
  }
  
  Map<String, dynamic>? getVendorProfile() {
    final data = _prefs.getString('vendor_profile');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
  
  String? getVendorVettingStatus() {
    final profile = getVendorProfile();
    return profile?['vetting_status'] as String?;
  }
  
  bool isVendorApproved() {
    return getVendorVettingStatus() == AppConstants.vettingApproved;
  }
  
  // ==================
  // Onboarding
  // ==================
  
  Future<void> setOnboardingCompleted() async {
    await _prefs.setBool(AppConstants.onboardingKey, true);
  }
  
  bool isOnboardingCompleted() {
    return _prefs.getBool(AppConstants.onboardingKey) ?? false;
  }
  
  // ==================
  // Theme
  // ==================
  
  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.themeKey, mode);
  }
  
  String getThemeMode() {
    return _prefs.getString(AppConstants.themeKey) ?? 'system';
  }
  
  // ==================
  // Cart Data (local cache)
  // ==================
  
  Future<void> saveCartData(Map<String, dynamic> cartData) async {
    await _prefs.setString(AppConstants.cartKey, jsonEncode(cartData));
  }
  
  Map<String, dynamic>? getCartData() {
    final data = _prefs.getString(AppConstants.cartKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
  
  Future<void> clearCartData() async {
    await _prefs.remove(AppConstants.cartKey);
  }
  
  // ==================
  // Search History
  // ==================
  
  Future<void> addSearchTerm(String term) async {
    final history = getSearchHistory();
    if (!history.contains(term)) {
      history.insert(0, term);
      if (history.length > 10) {
        history.removeLast();
      }
      await _prefs.setStringList('search_history', history);
    }
  }
  
  List<String> getSearchHistory() {
    return _prefs.getStringList('search_history') ?? [];
  }
  
  Future<void> clearSearchHistory() async {
    await _prefs.remove('search_history');
  }
  
  // ==================
  // Recently Viewed Products
  // ==================
  
  Future<void> addRecentlyViewed(int productId) async {
    final recent = getRecentlyViewed();
    recent.remove(productId);
    recent.insert(0, productId);
    if (recent.length > 20) {
      recent.removeLast();
    }
    await _prefs.setString('recently_viewed', jsonEncode(recent));
  }
  
  List<int> getRecentlyViewed() {
    final data = _prefs.getString('recently_viewed');
    if (data != null) {
      return List<int>.from(jsonDecode(data));
    }
    return [];
  }
  
  // ==================
  // General Storage
  // ==================
  
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
  
  String? getString(String key) {
    return _prefs.getString(key);
  }
  
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }
  
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }
  
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }
  
  int? getInt(String key) {
    return _prefs.getInt(key);
  }
  
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
  
  // ==================
  // Clear Methods
  // ==================
  
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
  
  Future<void> clearAuthData() async {
    await deleteToken();
    await deleteUser();
    await _prefs.remove(AppConstants.userRoleKey);
    await _prefs.remove('vendor_profile');
    await _prefs.remove('csrf_token');
  }
}
