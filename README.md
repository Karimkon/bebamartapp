# BebaMart Flutter Mobile App

A production-ready Flutter mobile application for the BebaMart marketplace platform. This app mirrors the exact functionality of the Laravel web application with identical business logic.

## 🚀 Features

### Buyer Features
- **Browse Marketplace**: Search and filter products by category, price, condition
- **Product Details**: View images, descriptions, reviews, variants (color/size)
- **Shopping Cart**: Add/remove items, manage quantities, variant selection
- **Wishlist**: Save products for later
- **Checkout**: Multiple payment methods (Mobile Money, Card, Cash on Delivery, Wallet)
- **Order Management**: Track orders, view history, confirm delivery
- **Reviews**: Write and manage product reviews
- **Chat**: Message vendors directly
- **Wallet**: Manage balance, view transactions
- **Shipping Addresses**: Multiple saved addresses
- **Jobs & Services**: Browse and apply for jobs, request services

### Vendor Features
- **Dashboard**: Sales stats, revenue, pending orders
- **Product Management**: Create, edit, delete listings with variants
- **Order Management**: Process orders, update status, track deliveries
- **Performance Analytics**: View sales metrics, delivery performance
- **Review Management**: View and respond to customer reviews
- **Jobs & Services**: Post job listings, manage service offerings
- **Chat**: Communicate with buyers

### Technical Features
- **State Management**: Riverpod for reactive state management
- **Navigation**: GoRouter for declarative routing
- **Network**: Dio for HTTP client with interceptors
- **Storage**: Secure storage for auth tokens, SharedPreferences for user data
- **Authentication**: Sanctum token-based auth with auto-refresh
- **Offline Support**: Cached user data for offline access

## 📁 Project Structure

```
lib/
├── main.dart                     # App entry point
├── app_router.dart               # GoRouter configuration
├── core/
│   ├── constants/
│   │   └── app_constants.dart    # API endpoints, config values
│   ├── theme/
│   │   └── app_theme.dart        # Colors, typography, components
│   ├── network/
│   │   └── api_client.dart       # Dio HTTP client
│   └── services/
│       └── storage_service.dart  # Local storage management
├── shared/
│   ├── models/                   # Data models (1:1 with Laravel DB)
│   │   ├── user_model.dart
│   │   ├── listing_model.dart
│   │   ├── order_model.dart
│   │   ├── cart_model.dart
│   │   ├── category_model.dart
│   │   └── chat_model.dart
│   └── widgets/
│       └── custom_widgets.dart   # Reusable UI components
└── features/
    ├── auth/
    │   ├── providers/            # Riverpod auth state
    │   └── screens/              # Login, Register, Splash
    ├── buyer/
    │   ├── providers/            # Listing, Cart, Category providers
    │   └── screens/              # Home, Cart, Orders, Profile, etc.
    ├── vendor/
    │   └── screens/              # Dashboard, Products, Orders
    └── chat/
        └── screens/              # Chat list and detail
```

## 🔧 Setup Instructions

### Prerequisites
- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- Android Studio / VS Code with Flutter extensions
- A running BebaMart Laravel backend

### 1. Clone and Install Dependencies

```bash
cd bebamart_flutter
flutter pub get
```

### 2. Configure API Endpoint

Edit `lib/core/constants/app_constants.dart`:

```dart
class AppConstants {
  // For Android Emulator:
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  // For iOS Simulator:
  static const String baseUrl = 'http://127.0.0.1:8000';
  
  // For Physical Device (replace with your computer's IP):
  static const String baseUrl = 'http://192.168.1.100:8000';
  
  // For Production:
  static const String baseUrl = 'https://api.bebamart.com';
}
```

### 3. Setup Laravel Backend API

Copy the `laravel_api_routes.php` file to your Laravel project:

```bash
# In your Laravel project directory
cp /path/to/bebamart_flutter/laravel_api_routes.php routes/api.php
```

Or merge the routes into your existing `routes/api.php`.

Make sure your Laravel backend has:
1. Laravel Sanctum installed and configured
2. CORS enabled for mobile app access
3. All referenced controllers exist

### 4. Laravel CORS Configuration

In `config/cors.php`:

```php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_origins' => ['*'],
    'allowed_methods' => ['*'],
    'allowed_headers' => ['*'],
    'supports_credentials' => true,
];
```

### 5. Run the App

```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

## 🔐 Authentication Flow

1. User enters credentials on Login screen
2. App calls `/api/v1/auth/login` endpoint
3. Server validates and returns Sanctum token
4. Token stored in FlutterSecureStorage
5. All subsequent API calls include `Authorization: Bearer <token>`
6. On 401 response, token is cleared and user redirected to login

## 📱 Screens Overview

### Auth Flow
- **Splash Screen**: Initial loading, auth check
- **Login Screen**: Email/password login
- **Register Screen**: Buyer/Vendor registration

### Buyer Flow (Bottom Navigation)
- **Home**: Featured products, categories, search
- **Cart**: View/manage cart items
- **Wishlist**: Saved products
- **Orders**: Order history and tracking
- **Profile**: Account settings, addresses, wallet

### Vendor Flow (Bottom Navigation)
- **Dashboard**: Stats, recent orders
- **Products**: Manage listings
- **Orders**: Process customer orders
- **Store**: Profile and settings

## 🎨 Theming

The app uses a custom theme based on the BebaMart brand colors:

```dart
// Primary: Dark Navy Blue (#1A1A4E)
// Accent: Indigo (#6366F1)
// Secondary: Purple (#8B5CF6)
```

All theme configuration is in `lib/core/theme/app_theme.dart`.

## 📦 Models Mapping

All Flutter models map 1:1 with Laravel database tables:

| Flutter Model | Laravel Table | Description |
|---------------|---------------|-------------|
| UserModel | users | User account data |
| VendorProfileModel | vendor_profiles | Vendor business info |
| ListingModel | listings | Products/listings |
| ListingImageModel | listing_images | Product images |
| ListingVariantModel | listing_variants | Product variants |
| OrderModel | orders | Orders |
| OrderItemModel | order_items | Order line items |
| CartModel | carts | Shopping cart |
| WishlistModel | wishlists | Saved products |
| CategoryModel | categories | Product categories |
| ReviewModel | reviews | Product reviews |
| ConversationModel | conversations | Chat conversations |
| MessageModel | messages | Chat messages |
| ShippingAddressModel | shipping_addresses | Delivery addresses |
| BuyerWalletModel | buyer_wallets | Wallet balance |

## 🔄 State Management

Using Riverpod for all state management:

```dart
// Auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(...);

// Listings
final featuredListingsProvider = FutureProvider<List<ListingModel>>(...);

// Categories
final categoriesProvider = FutureProvider<List<CategoryModel>>(...);

// Search
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(...);
```

## 🛠 Development

### Adding New Features

1. Create model in `lib/shared/models/`
2. Add API endpoint in `lib/core/constants/app_constants.dart`
3. Create provider in feature's `providers/` folder
4. Create screen in feature's `screens/` folder
5. Add route in `lib/app_router.dart`

### Code Generation

The project uses standard Dart null-safety. No code generation required.

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📝 API Reference

See `laravel_api_routes.php` for complete API documentation. Key endpoints:

### Auth
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/register` - Register
- `POST /api/v1/auth/logout` - Logout

### Marketplace
- `GET /api/v1/marketplace` - List products
- `GET /api/v1/marketplace/{id}` - Product detail
- `GET /api/v1/categories` - List categories

### Cart
- `GET /api/v1/cart` - Get cart
- `POST /api/v1/cart/add/{listingId}` - Add to cart
- `DELETE /api/v1/cart/remove/{listingId}` - Remove from cart

### Orders
- `GET /api/v1/orders` - List orders
- `POST /api/v1/orders/place` - Place order
- `POST /api/v1/orders/{id}/cancel` - Cancel order

## 🐛 Troubleshooting

### Common Issues

1. **Connection refused**: Check Laravel server is running and API URL is correct
2. **401 Unauthorized**: Token expired, try logging in again
3. **CORS errors**: Ensure Laravel CORS is configured correctly
4. **SSL errors on Android**: Add network security config for local development

### Debug Mode

Enable debug logging in `lib/core/network/api_client.dart`:

```dart
if (kDebugMode) {
  print('🚀 REQUEST: ${options.method} ${options.uri}');
}
```

## 📄 License

This project is proprietary software for BebaMart.

## 👥 Contributors

Built by [Your Team]

---

For questions or support, contact: support@bebamart.com
