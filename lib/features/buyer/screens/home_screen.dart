// lib/features/buyer/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../../shared/models/category_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/listing_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/variation_provider.dart';
import '../../../shared/models/variation_modal.dart';
import '../../chat/providers/chat_provider.dart';
import '../providers/service_category_provider.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/models/job_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedCategorySlug;
  CategoryModel? _selectedCategory; // Store full category for subcategory access
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productsKey = GlobalKey();
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        ref.read(allListingsProvider.future),
        ref.read(categoriesProvider.future),
      ]);
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(allListingsProvider);
    ref.invalidate(categoriesProvider);
    setState(() {
      _selectedCategorySlug = null;
      _selectedCategory = null;
    });
    await _loadInitialData();
  }

  void _showLoginPrompt(String action) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.login_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please login to $action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue Browsing'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/register');
              },
              child: RichText(
                text: TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Sign Up',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddToCart(int listingId) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    _showLoginPrompt('add items to cart');
    return;
  }

  // Clear any "stuck" messages before doing anything else
  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  try {
    // Always load variations first if not already loaded
    final variationState = ref.read(variationProvider(listingId));
    if (!variationState.hasVariations && variationState.variations.isEmpty && !variationState.isLoading) {
      await ref.read(variationProvider(listingId).notifier).loadVariations(listingId);
    }

    final hasVariations = ref.read(variationProvider(listingId)).hasVariations;
    if (hasVariations) {
      final listing = ref.read(allListingsProvider).value?.firstWhere(
            (l) => l.id == listingId,
            orElse: () => throw Exception('Listing not found'),
          );

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => VariationModal(
            listingId: listingId,
            productTitle: listing?.title ?? 'Product',
            basePrice: listing?.price ?? 0,
            onSuccess: () {
              if (mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.white),
                        SizedBox(width: 12),
                        Expanded(child: Text('Added to cart!')),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
          ),
        );
      }
      return;
    }
  } catch (e) {
    debugPrint('Error checking variations: $e');
  }

  try {
    final success = await ref.read(cartProvider.notifier).addToCart(listingId, 1);
    if (mounted && success) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Added to cart!')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }
}

  Future<void> _handleToggleWishlist(int listingId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showLoginPrompt('save items to wishlist');
      return;
    }

    try {
      final success = await ref.read(wishlistProvider.notifier).toggleWishlist(listingId);
      if (mounted && success) {
        final isNowWishlisted = ref.read(wishlistProvider).isWishlisted(listingId);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isNowWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.white,
                ),
                const SizedBox(width: 12),
                Text(isNowWishlisted ? 'Added to wishlist' : 'Removed from wishlist'),
              ],
            ),
            backgroundColor: isNowWishlisted ? AppColors.primary : AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToProducts() {
    // Scroll to products section smoothly
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_productsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _productsKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final listingsAsync = ref.watch(allListingsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(cartProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Modern App Bar
              SliverToBoxAdapter(
                child: _buildAppBar(user, cartState),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),

              // Promotional Banner
              SliverToBoxAdapter(
                child: _buildPromoBanner(size),
              ),

              // Categories Section
              SliverToBoxAdapter(
                child: _buildCategoriesSection(categoriesAsync),
              ),

              // Quick Links (Services & Jobs) side by side
              SliverToBoxAdapter(
                child: _buildQuickLinks(),
              ),

              // Products Section Header
              SliverToBoxAdapter(
                child: _buildProductsHeader(),
              ),

              // Products Grid
              _buildProductsGrid(listingsAsync),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(dynamic user, dynamic cartState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary,
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Welcome Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null ? 'Welcome back,' : 'Welcome to',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  user?.displayName ?? 'BebaMart',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Notification/Messages Icon (if logged in)
          if (user != null)
            Consumer(
              builder: (context, ref, child) {
                final unreadCountAsync = ref.watch(unreadCountProvider);
                final unreadCount = unreadCountAsync.valueOrNull ?? 0;

                return IconButton(
                  onPressed: () => context.push('/chat'),
                  icon: Stack(
                    children: [
                      const Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

          // Cart Icon
          Stack(
            children: [
              IconButton(
                onPressed: () => context.push('/cart'),
                icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${cartState.itemCount > 99 ? '99+' : cartState.itemCount}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // Profile/Login
          if (user == null)
            TextButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.person_outline, size: 20),
              label: const Text('Login'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search for products, brands...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner(Size size) {
    final banners = [
      {'title': 'Flash Sale', 'subtitle': 'Up to 70% Off', 'color': AppColors.primary},
      {'title': 'New Arrivals', 'subtitle': 'Shop Latest Trends', 'color': const Color(0xFF6C5CE7)},
      {'title': 'Free Delivery', 'subtitle': 'On Orders Above UGX 50K', 'color': const Color(0xFF00B894)},
    ];

    // Increased minimum height to 105 to fix the 2.7px overflow
    final bannerHeight = (size.height * 0.13).clamp(105.0, 125.0);

    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) => setState(() => _currentBannerPage = index),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return GestureDetector(
                onTap: _scrollToProducts, // Scroll to products when tapped
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        banner['color'] as Color,
                        (banner['color'] as Color).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (banner['color'] as Color).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative circles (smaller)
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        bottom: -30,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Content (more compact)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              banner['title'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              banner['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 6), // Slightly reduced spacing
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Shop Now',
                                style: TextStyle(
                                  color: banner['color'] as Color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Page indicators (smaller)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerPage == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerPage == index
                    ? AppColors.primary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Product Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/categories'),
                child: Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 85,
          child: categoriesAsync.when(
            data: (categories) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategorySlug == category.slug;
                return _buildCategoryItem(category, isSelected, index);
              },
            ),
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 6,
              itemBuilder: (_, __) => _buildCategoryShimmer(),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLinks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Professional Services Button
          Expanded(
            child: _buildQuickLinkButton(
              title: 'Professional\nServices',
              icon: Icons.handyman_rounded,
              color: const Color(0xFF6C5CE7),
              onTap: () => context.push('/services'),
            ),
          ),
          const SizedBox(width: 12),
          // Jobs & Careers Button
          Expanded(
            child: _buildQuickLinkButton(
              title: 'Jobs &\nCareers',
              icon: Icons.work_rounded,
              color: const Color(0xFF00B894),
              onTap: () => context.push('/jobs'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel category, bool isSelected, int index) {
    final gradients = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFFA8EDEA), const Color(0xFFFED6E3)],
    ];

    final gradient = gradients[index % gradients.length];

    return GestureDetector(
      onTap: () => context.push('/category/${category.slug}'),
      child: Container(
        width: 72, // Reduced from 85
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, // Reduced from 52
              height: 44, // Reduced from 52
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected ? [AppColors.primary, AppColors.primaryDark] : gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12), // Slightly more rounded for small size
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppColors.primary : gradient[0]).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                category.iconData,
                color: AppColors.white,
                size: 18, // Reduced from 22
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 50,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsHeader() {
    return Padding(
      key: _productsKey, // Key for scroll target
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCategory != null ? _selectedCategory!.name : 'Popular Products',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _selectedCategory != null
                      ? 'Products in ${_selectedCategory!.name} & subcategories'
                      : 'Based on your interests',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCategorySlug != null)
            GestureDetector(
              onTap: () => setState(() {
                _selectedCategorySlug = null;
                _selectedCategory = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close, size: 14, color: AppColors.error),
                    const SizedBox(width: 3),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(AsyncValue<List<ListingModel>> listingsAsync) {
    return listingsAsync.when(
      data: (listings) {
        // 1. Filter out vendor's own products
        final currentUser = ref.read(currentUserProvider);
        final vendorId = currentUser?.vendorProfile?.id;
        
        final baseListings = vendorId != null 
            ? listings.where((l) => l.vendorProfileId != vendorId).toList()
            : listings;

        List<ListingModel> filteredListings;

        if (_selectedCategory != null) {
          // Get all child category slugs for this parent category
          final childSlugs = _selectedCategory!.children.map((c) => c.slug).toSet();

          // Filter products that belong to parent category OR any of its subcategories
          filteredListings = baseListings.where((listing) {
            final listingCategorySlug = listing.category?.slug;
            final listingCategoryParentId = listing.category?.parentId;

            // Match if:
            // 1. Product is directly in the selected category
            // 2. Product's category slug is in the child slugs
            // 3. Product's category has parentId matching selected category's id
            return listingCategorySlug == _selectedCategorySlug ||
                   childSlugs.contains(listingCategorySlug) ||
                   listingCategoryParentId == _selectedCategory!.id;
          }).toList();
        } else {
          filteredListings = baseListings;
        }

        if (filteredListings.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              childAspectRatio: 0.60,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(filteredListings[index]),
              childCount: filteredListings.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => _buildProductShimmer(),
            childCount: 6,
          ),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildProductCard(ListingModel listing) {
  return GestureDetector(
    onTap: () => context.push('/product/${listing.id}'),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FIXED IMAGE AREA (Top 60% of card)
          Expanded(
            flex: 6, 
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: listing.primaryImage != null
                        ? Image.network(
                            listing.primaryImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined)),
                          )
                        : Container(color: const Color(0xFFF8F9FA), child: const Icon(Icons.image_outlined)),
                  ),
                ),
                // Wishlist Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isWishlisted = ref.watch(isInWishlistProvider(listing.id));
                      return GestureDetector(
                        onTap: () => _handleToggleWishlist(listing.id),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.white.withOpacity(0.9),
                          child: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_outline,
                            size: 16,
                            color: isWishlisted ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 2. TEXT AREA (Bottom 40% of card)
          // We use a flexible container here to prevent "Pushing"
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Keeps price at bottom
                children: [
                  // Title and Vendor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        style: const TextStyle(
                          fontSize: 12, // Reduced size to fit more text
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Vendor duration + verification badge (like webapp)
                      if (listing.vendor != null)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 10,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                listing.vendor!.durationBadge.replaceAll(' on BebaMart', ''),
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (listing.vendor!.isVerified)
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: Color(0xFF3B82F6), // blue-500
                              ),
                          ],
                        ),
                    ],
                  ),
                  
                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox( // Scales price text down if it's too long
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            listing.formattedPrice,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Compact Cart Button
                      GestureDetector(
                        onTap: () => _handleAddToCart(listing.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_shopping_cart, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProductShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: double.infinity, height: 14, color: AppColors.border),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 12, color: AppColors.border),
                  const Spacer(),
                  Container(width: 60, height: 16, color: AppColors.border),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Products Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategorySlug != null
                ? 'No products in this category yet.\nTry another category!'
                : 'Check back soon for amazing deals!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 50, color: AppColors.error),
          ),
          const SizedBox(height: 20),
          const Text(
            'Oops! Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
