<?php

/**
 * BebaMart Mobile API Routes
 * 
 * This file should be added to your Laravel application at routes/api.php
 * These routes are designed to work with the BebaMart Flutter mobile app.
 * 
 * Add to your existing api.php or replace it entirely.
 */

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

// Import Controllers
use App\Http\Controllers\AuthController;
use App\Http\Controllers\Buyer\CartController;
use App\Http\Controllers\Buyer\WishlistController;
use App\Http\Controllers\Buyer\OrderController as BuyerOrderController;
use App\Http\Controllers\Buyer\ShippingAddressController;
use App\Http\Controllers\Buyer\WalletController;
use App\Http\Controllers\Buyer\DisputeController;
use App\Http\Controllers\Buyer\BuyerDashboardController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\MarketplaceController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\Vendor\VendorDashboardController;
use App\Http\Controllers\Vendor\VendorListingController;
use App\Http\Controllers\Vendor\VendorOrderController;
use App\Http\Controllers\Vendor\VendorProfileController;
use App\Http\Controllers\JobsServicesController;
use App\Http\Controllers\Api\MobileApiController;

/*
|--------------------------------------------------------------------------
| Mobile API Routes
|--------------------------------------------------------------------------
|
| These routes are designed for the Flutter mobile application.
| All responses are JSON-formatted.
|
*/

// ====================
// PUBLIC ROUTES (No Authentication Required)
// ====================

Route::prefix('v1')->group(function () {
    
    // Health check
    Route::get('/health', function () {
        return response()->json(['status' => 'ok', 'timestamp' => now()]);
    });
    
    // ====================
    // AUTHENTICATION
    // ====================
    Route::prefix('auth')->group(function () {
        
        // Login
        Route::post('/login', function (Request $request) {
            $request->validate([
                'email' => 'required|email',
                'password' => 'required|string',
            ]);
            
            if (!auth()->attempt($request->only('email', 'password'))) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid credentials',
                ], 401);
            }
            
            $user = auth()->user();
            $user->load('vendorProfile');
            $token = $user->createToken('mobile-app')->plainTextToken;
            
            return response()->json([
                'success' => true,
                'token' => $token,
                'user' => $user,
            ]);
        });
        
        // Register
        Route::post('/register', function (Request $request) {
            $request->validate([
                'name' => 'required|string|max:255',
                'email' => 'required|string|email|max:255|unique:users',
                'phone' => 'required|string|max:20|unique:users',
                'password' => 'required|string|min:8|confirmed',
                'role' => 'nullable|in:buyer,vendor_local,vendor_international',
            ]);
            
            $role = $request->role ?? 'buyer';
            
            $user = \App\Models\User::create([
                'name' => $request->name,
                'email' => $request->email,
                'phone' => $request->phone,
                'password' => bcrypt($request->password),
                'role' => $role,
            ]);
            
            // Create vendor profile if registering as vendor
            if (in_array($role, ['vendor_local', 'vendor_international'])) {
                \App\Models\VendorProfile::create([
                    'user_id' => $user->id,
                    'vendor_type' => $role === 'vendor_international' ? 'china_supplier' : 'local_retail',
                    'business_name' => $request->business_name ?? $request->name . "'s Store",
                    'country' => $request->country ?? 'Uganda',
                    'city' => $request->city ?? 'Kampala',
                    'vetting_status' => 'pending',
                ]);
            }
            
            // Create buyer wallet if registering as buyer
            if ($role === 'buyer') {
                \App\Models\BuyerWallet::firstOrCreate(
                    ['user_id' => $user->id],
                    ['balance' => 0, 'locked_balance' => 0, 'currency' => 'UGX']
                );
            }
            
            $user->load('vendorProfile');
            $token = $user->createToken('mobile-app')->plainTextToken;
            
            return response()->json([
                'success' => true,
                'token' => $token,
                'user' => $user,
            ], 201);
        });
        
        // Forgot Password
        Route::post('/forgot-password', function (Request $request) {
            $request->validate(['email' => 'required|email']);
            
            $status = \Illuminate\Support\Facades\Password::sendResetLink(
                $request->only('email')
            );
            
            return response()->json([
                'success' => $status === \Illuminate\Support\Facades\Password::RESET_LINK_SENT,
                'message' => __($status),
            ]);
        });
    });
    
    // ====================
    // MARKETPLACE (PUBLIC)
    // ====================
    Route::prefix('marketplace')->group(function () {
        
        // List all listings with filters
        Route::get('/', function (Request $request) {
            $query = \App\Models\Listing::with(['images', 'vendor', 'category'])
                ->where('is_active', true);
            
            // Search
            if ($request->has('search')) {
                $search = $request->search;
                $query->where(function($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('description', 'like', "%{$search}%");
                });
            }
            
            // Category filter
            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }
            
            // Price range
            if ($request->has('min_price')) {
                $query->where('price', '>=', $request->min_price);
            }
            if ($request->has('max_price')) {
                $query->where('price', '<=', $request->max_price);
            }
            
            // Condition filter
            if ($request->has('condition')) {
                $query->where('condition', $request->condition);
            }
            
            // Sorting
            $sortBy = $request->get('sort_by', 'created_at');
            $sortDir = $request->get('sort_dir', 'desc');
            $query->orderBy($sortBy, $sortDir);
            
            $listings = $query->paginate($request->get('per_page', 20));
            
            return response()->json([
                'success' => true,
                'listings' => $listings,
            ]);
        });
        
        // Get single listing
        Route::get('/{id}', function ($id) {
            $listing = \App\Models\Listing::with([
                'images', 
                'vendor', 
                'category', 
                'variants',
                'approvedReviews.user'
            ])->findOrFail($id);
            
            // Increment view count
            $listing->increment('view_count');
            
            return response()->json([
                'success' => true,
                'listing' => $listing,
            ]);
        });
        
        // Get listing variations
        Route::get('/{id}/variations', function ($id) {
            $listing = \App\Models\Listing::with('variants')->findOrFail($id);
            
            return response()->json([
                'has_variations' => $listing->has_variations ?? false,
                'variations' => $listing->variants,
                'colors' => $listing->available_colors ?? [],
                'sizes' => $listing->available_sizes ?? [],
            ]);
        });
        
        // Get listing reviews
        Route::get('/{id}/reviews', function ($id) {
            $reviews = \App\Models\Review::with('user')
                ->where('listing_id', $id)
                ->where('status', 'approved')
                ->orderBy('created_at', 'desc')
                ->paginate(10);
            
            return response()->json([
                'success' => true,
                'reviews' => $reviews,
            ]);
        });
    });
    
    // ====================
    // CATEGORIES (PUBLIC)
    // ====================
    Route::prefix('categories')->group(function () {
        
        // List all categories
        Route::get('/', function () {
            $categories = \App\Models\Category::where('is_active', true)
                ->whereNull('parent_id')
                ->with('children')
                ->withCount('listings')
                ->orderBy('sort_order')
                ->get();
            
            return response()->json([
                'success' => true,
                'categories' => $categories,
            ]);
        });
        
        // Get category with listings
        Route::get('/{slug}', function ($slug) {
            $category = \App\Models\Category::where('slug', $slug)
                ->with('children')
                ->firstOrFail();
            
            $listings = \App\Models\Listing::with(['images', 'vendor'])
                ->where('category_id', $category->id)
                ->where('is_active', true)
                ->paginate(20);
            
            return response()->json([
                'success' => true,
                'category' => $category,
                'listings' => $listings,
            ]);
        });
    });
    
    // ====================
    // JOBS & SERVICES (PUBLIC)
    // ====================
    Route::prefix('jobs')->group(function () {
        Route::get('/', function (Request $request) {
            $query = \App\Models\JobListing::with(['vendor', 'category'])
                ->where('status', 'active');
            
            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }
            
            $jobs = $query->orderBy('created_at', 'desc')->paginate(20);
            
            return response()->json(['success' => true, 'jobs' => $jobs]);
        });
        
        Route::get('/{slug}', function ($slug) {
            $job = \App\Models\JobListing::with(['vendor', 'category'])
                ->where('slug', $slug)
                ->firstOrFail();
            
            $job->increment('views_count');
            
            return response()->json(['success' => true, 'job' => $job]);
        });
    });
    
    Route::prefix('services')->group(function () {
        Route::get('/', function (Request $request) {
            $query = \App\Models\VendorService::with(['vendor', 'category'])
                ->where('status', 'active');
            
            if ($request->has('category_id')) {
                $query->where('category_id', $request->category_id);
            }
            
            $services = $query->orderBy('created_at', 'desc')->paginate(20);
            
            return response()->json(['success' => true, 'services' => $services]);
        });
        
        Route::get('/{slug}', function ($slug) {
            $service = \App\Models\VendorService::with(['vendor', 'category'])
                ->where('slug', $slug)
                ->firstOrFail();
            
            $service->increment('views_count');
            
            return response()->json(['success' => true, 'service' => $service]);
        });
    });
    
    // ====================
    // AUTHENTICATED ROUTES
    // ====================
    Route::middleware('auth:sanctum')->group(function () {
        
        // Get current user
        Route::get('/user', function (Request $request) {
            $user = $request->user();
            $user->load('vendorProfile');
            return response()->json($user);
        });
        
        // Update profile
        Route::post('/user/profile', function (Request $request) {
            $user = $request->user();
            $user->update($request->only(['name', 'email', 'phone']));
            return response()->json(['success' => true, 'user' => $user]);
        });
        
        // Logout
        Route::post('/auth/logout', function (Request $request) {
            $request->user()->currentAccessToken()->delete();
            return response()->json(['success' => true, 'message' => 'Logged out']);
        });
        
        // ====================
        // CART
        // ====================
        Route::prefix('cart')->group(function () {
            
            // Get cart
            Route::get('/', function (Request $request) {
                $cart = \App\Models\Cart::where('user_id', $request->user()->id)
                    ->first();
                
                if (!$cart) {
                    return response()->json([
                        'success' => true,
                        'cart' => ['items' => [], 'subtotal' => 0, 'shipping' => 0, 'tax' => 0, 'total' => 0],
                    ]);
                }
                
                return response()->json(['success' => true, 'cart' => $cart]);
            });
            
            // Add to cart
            Route::post('/add/{listingId}', [CartController::class, 'add']);
            
            // Update quantity
            Route::post('/update/{listingId}', [CartController::class, 'update']);
            
            // Remove item
            Route::delete('/remove/{listingId}', [CartController::class, 'remove']);
            
            // Clear cart
            Route::post('/clear', [CartController::class, 'clear']);
            
            // Get summary
            Route::get('/summary', [CartController::class, 'getCartSummary']);
        });
        
        // ====================
        // WISHLIST
        // ====================
        Route::prefix('wishlist')->group(function () {
            
            Route::get('/', function (Request $request) {
                $wishlists = \App\Models\Wishlist::with('listing.images', 'listing.vendor')
                    ->where('user_id', $request->user()->id)
                    ->get();
                
                return response()->json(['success' => true, 'wishlists' => $wishlists]);
            });
            
            Route::post('/add/{listingId}', [WishlistController::class, 'add']);
            Route::delete('/remove/{listingId}', [WishlistController::class, 'remove']);
            Route::post('/toggle/{listingId}', [WishlistController::class, 'toggle']);
            Route::post('/move-to-cart/{listingId}', [WishlistController::class, 'moveToCart']);
            Route::get('/count', [WishlistController::class, 'getCount']);
        });
        
        // ====================
        // ORDERS
        // ====================
        Route::prefix('orders')->group(function () {
            
            // List orders
            Route::get('/', function (Request $request) {
                $orders = \App\Models\Order::with(['items.listing.images', 'vendorProfile'])
                    ->where('buyer_id', $request->user()->id)
                    ->orderBy('created_at', 'desc')
                    ->paginate(20);
                
                return response()->json(['success' => true, 'orders' => $orders]);
            });
            
            // Get checkout data
            Route::get('/checkout', [BuyerOrderController::class, 'checkout']);
            
            // Place order
            Route::post('/place', [BuyerOrderController::class, 'placeOrder']);
            
            // Get single order
            Route::get('/{id}', function ($id, Request $request) {
                $order = \App\Models\Order::with([
                    'items.listing.images', 
                    'vendorProfile', 
                    'payments', 
                    'escrow'
                ])
                ->where('buyer_id', $request->user()->id)
                ->findOrFail($id);
                
                return response()->json(['success' => true, 'order' => $order]);
            });
            
            // Cancel order
            Route::post('/{id}/cancel', [BuyerOrderController::class, 'cancelOrder']);
            
            // Confirm delivery
            Route::post('/{id}/confirm-delivery', [BuyerOrderController::class, 'confirmDelivery']);
            
            // Pay with wallet
            Route::post('/{id}/pay-with-wallet', [BuyerOrderController::class, 'payWithWallet']);
        });
        
        // ====================
        // SHIPPING ADDRESSES
        // ====================
        Route::prefix('addresses')->group(function () {
            
            Route::get('/', function (Request $request) {
                $addresses = \App\Models\ShippingAddress::where('user_id', $request->user()->id)
                    ->orderBy('is_default', 'desc')
                    ->get();
                
                return response()->json(['success' => true, 'addresses' => $addresses]);
            });
            
            Route::post('/', [ShippingAddressController::class, 'store']);
            Route::put('/{id}', [ShippingAddressController::class, 'update']);
            Route::delete('/{id}', [ShippingAddressController::class, 'destroy']);
            Route::post('/{id}/set-default', [ShippingAddressController::class, 'setDefault']);
        });
        
        // ====================
        // WALLET
        // ====================
        Route::prefix('wallet')->group(function () {
            
            Route::get('/', function (Request $request) {
                $wallet = \App\Models\BuyerWallet::firstOrCreate(
                    ['user_id' => $request->user()->id],
                    ['balance' => 0, 'locked_balance' => 0, 'currency' => 'UGX']
                );
                
                return response()->json(['success' => true, 'wallet' => $wallet]);
            });
            
            Route::get('/transactions', [WalletController::class, 'transactions']);
            Route::post('/deposit', [WalletController::class, 'deposit']);
            Route::post('/withdraw', [WalletController::class, 'withdraw']);
        });
        
        // ====================
        // REVIEWS
        // ====================
        Route::prefix('reviews')->group(function () {
            
            Route::get('/', function (Request $request) {
                $reviews = \App\Models\Review::with('listing.images')
                    ->where('user_id', $request->user()->id)
                    ->orderBy('created_at', 'desc')
                    ->get();
                
                return response()->json(['success' => true, 'reviews' => $reviews]);
            });
            
            Route::post('/', [ReviewController::class, 'store']);
            Route::put('/{id}', [ReviewController::class, 'update']);
            Route::delete('/{id}', [ReviewController::class, 'destroy']);
            Route::post('/{id}/vote', [ReviewController::class, 'vote']);
        });
        
        // ====================
        // DISPUTES
        // ====================
        Route::prefix('disputes')->group(function () {
            Route::get('/', [DisputeController::class, 'index']);
            Route::post('/{orderId}', [DisputeController::class, 'store']);
            Route::get('/{id}', [DisputeController::class, 'show']);
            Route::post('/{id}/add-evidence', [DisputeController::class, 'addEvidence']);
        });
        
        // ====================
        // CHAT
        // ====================
        Route::prefix('chat')->group(function () {
            
            Route::get('/', function (Request $request) {
                $user = $request->user();
                $conversations = \App\Models\Conversation::forUser($user->id)
                    ->with(['buyer', 'vendor', 'listing.images'])
                    ->withCount(['messages as unread_count' => function($q) use ($user) {
                        $q->where('sender_id', '!=', $user->id)->whereNull('read_at');
                    }])
                    ->orderBy('last_message_at', 'desc')
                    ->get();
                
                return response()->json(['success' => true, 'conversations' => $conversations]);
            });
            
            Route::post('/start', [ChatController::class, 'start']);
            Route::get('/unread-count', [ChatController::class, 'unreadCount']);
            Route::get('/{id}', [ChatController::class, 'show']);
            Route::post('/{id}/send', [ChatController::class, 'send']);
            Route::get('/{id}/new-messages', [ChatController::class, 'newMessages']);
            Route::post('/{id}/archive', [ChatController::class, 'archive']);
        });
        
        // ====================
        // JOB APPLICATIONS (Buyer)
        // ====================
        Route::prefix('my-applications')->group(function () {
            Route::get('/', function (Request $request) {
                $applications = \App\Models\JobApplication::with(['jobListing.vendor'])
                    ->where('user_id', $request->user()->id)
                    ->orderBy('created_at', 'desc')
                    ->get();
                
                return response()->json(['success' => true, 'applications' => $applications]);
            });
            
            Route::post('/jobs/{slug}/apply', function ($slug, Request $request) {
                $job = \App\Models\JobListing::where('slug', $slug)->firstOrFail();
                
                $application = \App\Models\JobApplication::create([
                    'job_listing_id' => $job->id,
                    'user_id' => $request->user()->id,
                    'cover_letter' => $request->cover_letter,
                    'cv_path' => $request->file('cv')?->store('cvs', 'public'),
                    'status' => 'pending',
                    'applied_at' => now(),
                ]);
                
                return response()->json(['success' => true, 'application' => $application], 201);
            });
            
            Route::delete('/{id}', function ($id, Request $request) {
                $application = \App\Models\JobApplication::where('user_id', $request->user()->id)
                    ->findOrFail($id);
                $application->delete();
                
                return response()->json(['success' => true, 'message' => 'Application withdrawn']);
            });
        });
        
        // ====================
        // SERVICE REQUESTS (Buyer)
        // ====================
        Route::prefix('service-requests')->group(function () {
            Route::get('/', function (Request $request) {
                $requests = \App\Models\ServiceRequest::with(['service.vendor'])
                    ->where('user_id', $request->user()->id)
                    ->orderBy('created_at', 'desc')
                    ->get();
                
                return response()->json(['success' => true, 'requests' => $requests]);
            });
            
            Route::post('/services/{slug}/request', function ($slug, Request $request) {
                $service = \App\Models\VendorService::where('slug', $slug)->firstOrFail();
                
                $serviceRequest = \App\Models\ServiceRequest::create([
                    'service_id' => $service->id,
                    'user_id' => $request->user()->id,
                    'description' => $request->description,
                    'budget' => $request->budget,
                    'timeline' => $request->timeline,
                    'location' => $request->location,
                    'status' => 'pending',
                ]);
                
                return response()->json(['success' => true, 'request' => $serviceRequest], 201);
            });
            
            Route::post('/{id}/accept', function ($id, Request $request) {
                $serviceRequest = \App\Models\ServiceRequest::where('user_id', $request->user()->id)
                    ->findOrFail($id);
                $serviceRequest->update(['status' => 'accepted', 'accepted_at' => now()]);
                
                return response()->json(['success' => true, 'request' => $serviceRequest]);
            });
            
            Route::post('/{id}/cancel', function ($id, Request $request) {
                $serviceRequest = \App\Models\ServiceRequest::where('user_id', $request->user()->id)
                    ->findOrFail($id);
                $serviceRequest->update(['status' => 'cancelled']);
                
                return response()->json(['success' => true, 'request' => $serviceRequest]);
            });
            
            Route::post('/{id}/complete', function ($id, Request $request) {
                $serviceRequest = \App\Models\ServiceRequest::where('user_id', $request->user()->id)
                    ->findOrFail($id);
                $serviceRequest->update(['status' => 'completed', 'completed_at' => now()]);
                
                return response()->json(['success' => true, 'request' => $serviceRequest]);
            });
        });
        
        // ====================
        // VENDOR ROUTES
        // ====================
        Route::prefix('vendor')->middleware('check.vendor.status')->group(function () {
            
            // Dashboard stats
            Route::get('/dashboard', function (Request $request) {
                $vendor = $request->user()->vendorProfile;
                
                $stats = [
                    'total_listings' => $vendor->listings()->count(),
                    'active_listings' => $vendor->listings()->where('is_active', true)->count(),
                    'pending_orders' => \App\Models\Order::where('vendor_profile_id', $vendor->id)
                        ->whereIn('status', ['pending', 'paid', 'processing'])->count(),
                    'total_sales' => \App\Models\Order::where('vendor_profile_id', $vendor->id)
                        ->where('status', 'delivered')->sum('total'),
                    'monthly_revenue' => \App\Models\Order::where('vendor_profile_id', $vendor->id)
                        ->where('status', 'delivered')
                        ->whereMonth('created_at', now()->month)->sum('total'),
                ];
                
                $recentOrders = \App\Models\Order::where('vendor_profile_id', $vendor->id)
                    ->with('buyer')->orderBy('created_at', 'desc')->take(5)->get();
                
                return response()->json([
                    'success' => true,
                    'stats' => $stats,
                    'recent_orders' => $recentOrders,
                ]);
            });
            
            // Listings
            Route::prefix('listings')->group(function () {
                Route::get('/', [VendorListingController::class, 'index']);
                Route::post('/', [VendorListingController::class, 'store']);
                Route::get('/{id}', [VendorListingController::class, 'show']);
                Route::put('/{id}', [VendorListingController::class, 'update']);
                Route::delete('/{id}', [VendorListingController::class, 'destroy']);
                Route::post('/{id}/toggle-status', [VendorListingController::class, 'toggleStatus']);
            });
            
            // Orders
            Route::prefix('orders')->group(function () {
                Route::get('/', [VendorOrderController::class, 'index']);
                Route::get('/{id}', [VendorOrderController::class, 'show']);
                Route::post('/{id}/status', [VendorOrderController::class, 'updateStatus']);
            });
            
            // Profile
            Route::get('/profile', [VendorProfileController::class, 'show']);
            Route::put('/profile', [VendorProfileController::class, 'update']);
            
            // Analytics
            Route::get('/analytics', function (Request $request) {
                $vendor = $request->user()->vendorProfile;
                
                // Get analytics data
                $analytics = [
                    'total_views' => $vendor->listings()->sum('view_count'),
                    'total_orders' => \App\Models\Order::where('vendor_profile_id', $vendor->id)->count(),
                    'delivered_orders' => \App\Models\Order::where('vendor_profile_id', $vendor->id)
                        ->where('status', 'delivered')->count(),
                    'avg_rating' => $vendor->rating ?? 0,
                ];
                
                return response()->json(['success' => true, 'analytics' => $analytics]);
            });
            
            // Reviews
            Route::get('/reviews', function (Request $request) {
                $vendor = $request->user()->vendorProfile;
                $reviews = \App\Models\Review::whereHas('listing', function($q) use ($vendor) {
                    $q->where('vendor_profile_id', $vendor->id);
                })->with(['user', 'listing'])->orderBy('created_at', 'desc')->paginate(20);
                
                return response()->json(['success' => true, 'reviews' => $reviews]);
            });
            
            Route::post('/reviews/{id}/respond', function ($id, Request $request) {
                $vendor = $request->user()->vendorProfile;
                $review = \App\Models\Review::whereHas('listing', function($q) use ($vendor) {
                    $q->where('vendor_profile_id', $vendor->id);
                })->findOrFail($id);
                
                $review->update([
                    'vendor_response' => $request->response,
                    'vendor_response_at' => now(),
                ]);
                
                return response()->json(['success' => true, 'review' => $review]);
            });
            
            // Jobs
            Route::prefix('jobs')->group(function () {
                Route::get('/', function (Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    $jobs = \App\Models\JobListing::where('vendor_profile_id', $vendor->id)
                        ->withCount('applications')->orderBy('created_at', 'desc')->get();
                    
                    return response()->json(['success' => true, 'jobs' => $jobs]);
                });
                
                Route::post('/', function (Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    
                    $job = \App\Models\JobListing::create([
                        'vendor_profile_id' => $vendor->id,
                        'category_id' => $request->category_id,
                        'title' => $request->title,
                        'slug' => \Illuminate\Support\Str::slug($request->title) . '-' . uniqid(),
                        'description' => $request->description,
                        'location' => $request->location,
                        'employment_type' => $request->employment_type,
                        'salary_min' => $request->salary_min,
                        'salary_max' => $request->salary_max,
                        'requirements' => $request->requirements,
                        'responsibilities' => $request->responsibilities,
                        'benefits' => $request->benefits,
                        'application_deadline' => $request->application_deadline,
                        'status' => 'active',
                    ]);
                    
                    return response()->json(['success' => true, 'job' => $job], 201);
                });
                
                Route::get('/{id}/applications', function ($id, Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    $job = \App\Models\JobListing::where('vendor_profile_id', $vendor->id)
                        ->findOrFail($id);
                    
                    $applications = $job->applications()->with('user')->orderBy('created_at', 'desc')->get();
                    
                    return response()->json(['success' => true, 'applications' => $applications]);
                });
            });
            
            // Services
            Route::prefix('services')->group(function () {
                Route::get('/', function (Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    $services = \App\Models\VendorService::where('vendor_profile_id', $vendor->id)
                        ->orderBy('created_at', 'desc')->get();
                    
                    return response()->json(['success' => true, 'services' => $services]);
                });
                
                Route::post('/', function (Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    
                    $service = \App\Models\VendorService::create([
                        'vendor_profile_id' => $vendor->id,
                        'category_id' => $request->category_id,
                        'title' => $request->title,
                        'slug' => \Illuminate\Support\Str::slug($request->title) . '-' . uniqid(),
                        'description' => $request->description,
                        'pricing_type' => $request->pricing_type,
                        'base_price' => $request->base_price,
                        'location' => $request->location,
                        'service_area' => $request->service_area,
                        'features' => $request->features,
                        'status' => 'active',
                    ]);
                    
                    return response()->json(['success' => true, 'service' => $service], 201);
                });
                
                Route::get('/requests', function (Request $request) {
                    $vendor = $request->user()->vendorProfile;
                    $requests = \App\Models\ServiceRequest::whereHas('service', function($q) use ($vendor) {
                        $q->where('vendor_profile_id', $vendor->id);
                    })->with(['user', 'service'])->orderBy('created_at', 'desc')->get();
                    
                    return response()->json(['success' => true, 'requests' => $requests]);
                });
            });
        });
    });
});
