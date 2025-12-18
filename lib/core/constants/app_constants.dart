// lib/core/constants/app_constants.dart
// App configuration constants mapped to Laravel backend

class AppConstants {
  // App Info
  static const String appName = 'BebaMart';
  static const String appTagline = 'Your Trusted Marketplace';
  static const String appVersion = '1.0.0';
  
  // API Configuration - CHANGE THIS TO YOUR SERVER
  // For local development:
  //   Android Emulator: http://10.0.2.2:8000
  //   iOS Simulator: http://127.0.0.1:8000
  //   Physical Device: http://YOUR_COMPUTER_IP:8000
  // For production: https://yourdomain.com
  static const String baseUrl = 'http://192.168.3.68:8000';

  // API base URL - all API calls go through /api
  static const String apiUrl = '$baseUrl/api';
  static const String storageUrl = '$baseUrl/storage';
  
  // Timeouts
  static const int connectionTimeout = 120000; // Increased to 2 minutes
  static const int receiveTimeout = 120000;
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String userRoleKey = 'user_role';
  static const String onboardingKey = 'onboarding_completed';
  static const String themeKey = 'theme_mode';
  static const String cartKey = 'cart_data';
  
  // User Roles (from Laravel users table enum)
  static const String roleBuyer = 'buyer';
  static const String roleVendorLocal = 'vendor_local';
  static const String roleVendorInternational = 'vendor_international';
  static const String roleAdmin = 'admin';
  static const String roleLogistics = 'logistics';
  static const String roleClearingAgent = 'clearing_agent';
  
  // Currency
  static const String currency = 'UGX';
  static const String currencySymbol = 'UGX';
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 255;
  static const int maxPhoneLength = 20;
  
  // Image
  static const int maxImageSizeKB = 2048;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  
  // Order Statuses (from Laravel Order model)
  static const String orderPending = 'pending';
  static const String orderPaymentPending = 'payment_pending';
  static const String orderPaid = 'paid';
  static const String orderProcessing = 'processing';
  static const String orderShipped = 'shipped';
  static const String orderDelivered = 'delivered';
  static const String orderCancelled = 'cancelled';
  
  // Vendor Vetting Statuses
  static const String vettingPending = 'pending';
  static const String vettingApproved = 'approved';
  static const String vettingRejected = 'rejected';
  
  // Payment Methods
  static const String paymentCOD = 'cash_on_delivery';
  static const String paymentMobileMoney = 'mobile_money';
  static const String paymentCard = 'card';
  static const String paymentWallet = 'wallet';
  
  // Commission & Tax Rates (from Laravel)
  static const double platformCommissionRate = 0.15; // 15%
  static const double taxRate = 0.18; // 18% VAT
  
  // Contact
  static const String supportEmail = 'support@bebamart.com';
  static const String supportPhone = '+256700000000';
}

// API Endpoints - ALL use /api prefix for mobile app
class ApiEndpoints {
  // Auth
  static const String login = '/api/login';
  static const String register = '/api/register';
  static const String logout = '/api/logout';
  
  // User
  static const String user = '/api/user';
  static const String updateProfile = '/api/user/profile';
  static const String changePassword = '/api/user/change-password';
  
  // Categories
  static const String categories = '/api/categories';
  static String categoryDetail(String slug) => '/api/categories/$slug';
  
  // Marketplace/Listings
  static const String marketplace = '/api/marketplace';
  static String listingDetail(int id) => '/api/marketplace/$id';
  static String listingVariations(int id) => '/api/listings/$id/variations';
  static String listingCheckVariations(int id) => '/api/listings/$id/check-variations';
  static const String featuredListings = '/api/featured-listings';
  
  // Cart
  static const String cart = '/api/cart';
  static String cartAdd(int listingId) => '/api/cart/add/$listingId';
  static String cartUpdate(int listingId) => '/api/cart/update/$listingId';
  static String cartRemove(int listingId) => '/api/cart/remove/$listingId';
  static const String cartClear = '/api/cart/clear';
  static const String cartSummary = '/api/cart/summary';
  
  // Wishlist
  static const String wishlist = '/api/wishlist';
  static String wishlistAdd(int listingId) => '/api/wishlist/add/$listingId';
  static String wishlistRemove(int listingId) => '/api/wishlist/remove/$listingId';
  static String wishlistToggle(int listingId) => '/api/wishlist/toggle/$listingId';
  static String wishlistMoveToCart(int listingId) => '/api/wishlist/move-to-cart/$listingId';
  static const String wishlistCount = '/api/wishlist/count';
  
  // Orders
  static const String orders = '/api/orders';
  static const String checkout = '/api/orders/checkout';
  static const String placeOrder = '/api/orders/place-order';
  static String orderDetail(int id) => '/api/orders/$id';
  static String orderPayment(int id) => '/api/orders/$id/payment';
  static String orderPayWithWallet(int id) => '/api/orders/$id/pay-with-wallet';
  static String orderCancel(int id) => '/api/orders/$id/cancel';
  static String orderConfirmDelivery(int id) => '/api/orders/$id/confirm-delivery';
  
  // Shipping Addresses
  static const String addresses = '/api/addresses';
  static String addressDetail(int id) => '/api/addresses/$id';
  static String addressSetDefault(int id) => '/api/addresses/$id/set-default';
  
  // Wallet
  static const String wallet = '/api/wallet';
  static const String walletDeposit = '/api/wallet/deposit';
  static const String walletWithdraw = '/api/wallet/withdraw';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String walletBalance = '/api/wallet/balance';
  
  // Disputes
  static const String disputes = '/api/disputes';
  static String disputeCreate(int orderId) => '/api/disputes/create/$orderId';
  static String disputeStore(int orderId) => '/api/disputes/store/$orderId';
  static String disputeDetail(int id) => '/api/disputes/$id';
  
  // Reviews
  static const String reviews = '/api/reviews';
  static const String reviewCreate = '/api/reviews/create';
  static String reviewEdit(int id) => '/api/reviews/$id/edit';
  static String reviewDelete(int id) => '/api/reviews/$id';
  static String reviewVote(int id) => '/api/reviews/$id/vote';
  static String listingReviews(int listingId) => '/api/listings/$listingId/reviews';
  
  // Chat
  static const String chat = '/api/chat';
  static const String chatStart = '/api/chat/start';
  static const String chatUnreadCount = '/api/chat/unread-count';
  static String chatConversation(int id) => '/api/chat/$id';
  static String chatSend(int id) => '/api/chat/$id/send';
  static String chatNewMessages(int id) => '/api/chat/$id/new-messages';
  static String chatArchive(int id) => '/api/chat/$id/archive';
  
  // Vendor Dashboard
  static const String vendorDashboard = '/api/vendor/dashboard';
  
  // Vendor Listings
  static const String vendorListings = '/api/vendor/listings';
  static const String vendorListingsCreate = '/api/vendor/listings/create';
  static String vendorListingEdit(int id) => '/api/vendor/listings/$id/edit';
  static String vendorListingUpdate(int id) => '/api/vendor/listings/$id';
  static String vendorListingDelete(int id) => '/api/vendor/listings/$id';
  static String vendorListingToggle(int id) => '/api/vendor/listings/$id/toggle-status';
  
  // Vendor Orders
  static const String vendorOrders = '/api/vendor/orders';
  static String vendorOrderDetail(int id) => '/api/vendor/orders/$id';
  static String vendorOrderStatus(int id) => '/api/vendor/orders/$id/status';
  static String vendorOrderShip(int id) => '/api/vendor/orders/$id/ship';
  static String vendorOrderCancel(int id) => '/api/vendor/orders/$id/cancel';
  static String vendorOrderPackingSlip(int id) => '/api/vendor/orders/$id/packing-slip';
  
  // Vendor Profile
  static const String vendorProfile = '/api/vendor/profile';
  
  // Vendor Analytics
  static const String vendorAnalytics = '/api/vendor/analytics';
  static const String vendorPerformance = '/api/vendor/performance';
  
  // Vendor Reviews
  static const String vendorReviews = '/api/vendor/reviews';
  static String vendorReviewRespond(int id) => '/api/vendor/reviews/$id/respond';
  
  // Vendor Promotions
  static const String vendorPromotions = '/api/vendor/promotions';
  static const String vendorPromotionsCreate = '/api/vendor/promotions/create';
  static String vendorPromotionDetail(int id) => '/api/vendor/promotions/$id';
  static String vendorPromotionCancel(int id) => '/api/vendor/promotions/$id/cancel';
  
  // Vendor Callbacks
  static const String vendorCallbacks = '/api/vendor/callbacks';
  static String vendorCallbackStatus(int id) => '/api/vendor/callbacks/$id/status';
  
  // Vendor Onboarding
  static const String vendorOnboard = '/api/vendor/onboard';
  static const String vendorOnboardStatus = '/api/vendor/onboard/status';
  
  // Vendor Jobs
  static const String vendorJobs = '/api/vendor/jobs';
  static const String vendorJobsCreate = '/api/vendor/jobs/create';
  static String vendorJobDetail(int id) => '/api/vendor/jobs/$id';
  static String vendorJobEdit(int id) => '/api/vendor/jobs/$id/edit';
  static String vendorJobToggle(int id) => '/api/vendor/jobs/$id/toggle';
  static String vendorJobApplication(int jobId, int appId) => '/api/vendor/jobs/$jobId/applications/$appId';
  static String vendorJobApplicationStatus(int jobId, int appId) => '/api/vendor/jobs/$jobId/applications/$appId/status';
  
  // Vendor Services
  static const String vendorServices = '/api/vendor/services';
  static const String vendorServicesCreate = '/api/vendor/services/create';
  static String vendorServiceEdit(int id) => '/api/vendor/services/$id/edit';
  static String vendorServiceToggle(int id) => '/api/vendor/services/$id/toggle';
  static const String vendorServiceRequests = '/api/vendor/services/requests';
  static const String vendorServiceInquiries = '/api/vendor/services/inquiries';
  
  // Public Jobs & Services
  static const String jobs = '/api/jobs';
  static String jobDetail(String slug) => '/api/jobs/$slug';
  static String jobApply(String slug) => '/api/jobs/$slug/apply';
  
  static const String services = '/api/services';
  static String serviceDetail(String slug) => '/api/services/$slug';
  static String serviceRequest(String slug) => '/api/services/$slug/request';
  static String serviceInquiry(String slug) => '/api/services/$slug/inquiry';
  
  // Buyer Job Applications
  static const String myApplications = '/api/my-applications';
  static String applicationDetail(int id) => '/api/my-applications/$id';
  static String applicationWithdraw(int id) => '/api/my-applications/$id';
  
  // Buyer Service Requests
  static const String myServiceRequests = '/api/service-requests';
  static String serviceRequestDetail(int id) => '/api/service-requests/$id';
  static String serviceRequestAccept(int id) => '/api/service-requests/$id/accept';
  static String serviceRequestCancel(int id) => '/api/service-requests/$id/cancel';
  static String serviceRequestComplete(int id) => '/api/service-requests/$id/complete';
  static String serviceRequestReview(int id) => '/api/service-requests/$id/review';
  
  // Callback Request
  static String listingCallback(int listingId) => '/api/listings/$listingId/callback';
  
  // Payment
  static String paymentOptions(int orderId) => '/api/payment/order/$orderId';
  static String paymentMobileMoney(int orderId) => '/api/payment/order/$orderId/mobile-money';
  static String paymentCard(int orderId) => '/api/payment/order/$orderId/card';
  static String paymentStatus(int orderId) => '/api/payment/order/$orderId/status';
  
  // Health check
  static const String health = '/api/health';
  
  // Import Calculator
  static const String importCalculate = '/api/import-calculate';
}