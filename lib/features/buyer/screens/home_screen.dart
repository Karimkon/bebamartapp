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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategorySlug;

  @override
  void initState() {
    super.initState();
    print('🏠 HomeScreen initState');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    print('🔄 Loading initial data...');
    try {
      await Future.wait([
        ref.read(allListingsProvider.future),
        ref.read(categoriesProvider.future),
      ]);
      print('✅ Initial data loaded');
    } catch (e) {
      print('❌ Error loading initial data: $e');
    }
  }

  Future<void> _handleRefresh() async {
    print('🔄 Refreshing home screen...');
    
    ref.invalidate(allListingsProvider);
    ref.invalidate(categoriesProvider);
    setState(() {
      _selectedCategorySlug = null;
    });
    
    await _loadInitialData();
  }

  Future<void> _handleAddToCart(int listingId) async {
    final user = ref.read(currentUserProvider);
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to add items to cart'),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Login',
            textColor: AppColors.white,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    // Check if product has variations
    try {
      final variationState = ref.read(variationProvider(listingId));
      
      if (variationState.isLoading) {
        // Load variations first
        await ref.read(variationProvider(listingId).notifier).loadVariations(listingId);
      }
      
      final hasVariations = ref.read(variationProvider(listingId)).hasVariations;
      
      if (hasVariations) {
        // Show variation modal
        final listing = ref.read(allListingsProvider).value?.firstWhere(
          (l) => l.id == listingId,
          orElse: () => throw Exception('Listing not found'),
        );
        
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => VariationModal(
              listingId: listingId,
              productTitle: listing?.title ?? 'Product',
              basePrice: listing?.price ?? 0,
              onSuccess: () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to cart successfully!'),
                      backgroundColor: AppColors.success,
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
      print('Error checking variations: $e');
      // Continue with direct add to cart
    }

    // No variations - add directly to cart
    try {
      final success = await ref.read(cartProvider.notifier).addToCart(listingId, 1);
      
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleToggleWishlist(int listingId) async {
    final user = ref.read(currentUserProvider);
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to add to wishlist'),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Login',
            textColor: AppColors.white,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    try {
      final success = await ref.read(wishlistProvider.notifier).toggleWishlist(listingId);
      
      if (mounted && success) {
        final isNowWishlisted = ref.read(wishlistProvider).isWishlisted(listingId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowWishlisted ? 'Added to wishlist' : 'Removed from wishlist'),
            backgroundColor: isNowWishlisted ? AppColors.success : AppColors.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update wishlist: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final listingsAsync = ref.watch(allListingsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            slivers: [
              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            'Search products...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Welcome Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${user?.displayName ?? 'Guest'}!',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Discover amazing products',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white70, size: 32),
                              onPressed: () => context.push('/cart'),
                            ),
                            if (cartState.itemCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${cartState.itemCount}',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Categories Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/categories'),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: categoriesAsync.when(
                        data: (categories) => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isSelected = _selectedCategorySlug == category.slug;
                            return _buildCategoryItem(category, isSelected);
                          },
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // All Products Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategorySlug != null ? 'Filtered Products' : 'All Products',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_selectedCategorySlug != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategorySlug = null;
                            });
                          },
                          child: const Text('Clear Filter'),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Products Grid
              listingsAsync.when(
                data: (listings) {
                  // Filter by category if selected
                  final filteredListings = _selectedCategorySlug != null
                      ? listings.where((l) => l.category?.slug == _selectedCategorySlug).toList()
                      : listings;

                  if (filteredListings.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _buildEmptyState(),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
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
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: _buildErrorProducts(error.toString()),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel category, bool isSelected) {
    // Generate color based on category index
    final colors = [
      const Color(0xFFE3F2FD),
      const Color(0xFFFCE4EC),
      const Color(0xFFFFF3E0),
      const Color(0xFFE8F5E9),
      const Color(0xFFF3E5F5),
      const Color(0xFFE0F7FA),
    ];
    final iconColors = [
      const Color(0xFF1976D2),
      const Color(0xFFC2185B),
      const Color(0xFFE65100),
      const Color(0xFF388E3C),
      const Color(0xFF7B1FA2),
      const Color(0xFF00838F),
    ];
    
    final colorIndex = category.id % colors.length;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedCategorySlug == category.slug) {
            _selectedCategorySlug = null;
          } else {
            _selectedCategorySlug = category.slug;
          }
        });
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : colors[colorIndex],
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Icon(
                _getCategoryIcon(category.icon),
                color: isSelected ? AppColors.white : iconColors[colorIndex],
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 11,
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

  IconData _getCategoryIcon(String? icon) {
    switch (icon?.toLowerCase()) {
      case 'tv':
        return Icons.tv;
      case 'mobile-alt':
      case 'mobile':
        return Icons.smartphone;
      case 'tools':
        return Icons.build;
      case 'tshirt':
        return Icons.checkroom;
      case 'glasses':
        return Icons.visibility;
      case 'shoe-prints':
        return Icons.directions_walk;
      case 'suitcase':
        return Icons.luggage;
      case 'gem':
        return Icons.diamond;
      case 'car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'laptop':
        return Icons.laptop;
      default:
        return Icons.category;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategorySlug != null 
                ? 'No products in this category yet'
                : 'Check back soon for amazing deals!',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorProducts(String error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Failed to load products',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ListingModel listing) {
    return GestureDetector(
      onTap: () => context.push('/product/${listing.id}'),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280), // Add max height constraint
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            SizedBox(
              height: 150, // Fixed height instead of Expanded
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: listing.primaryImage != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              listing.primaryImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 40),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 48),
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
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              isWishlisted ? Icons.favorite : Icons.favorite_outline,
                              size: 18,
                              color: isWishlisted ? AppColors.error : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Stock Badge
                  if (listing.stock <= 10 && listing.stock > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Only ${listing.stock} left',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (listing.vendor != null)
                      Text(
                        listing.vendor!.businessName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    // Price and Cart Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            listing.formattedPrice,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _handleAddToCart(listing.id),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              color: AppColors.white,
                              size: 16,
                            ),
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
}