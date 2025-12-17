// lib/features/buyer/screens/category_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/listing_model.dart';
import '../../auth/providers/auth_provider.dart'; // Make sure this exists
import '../providers/category_provider.dart'; 
import '../providers/listing_provider.dart'; 
import '../../../shared/widgets/product_card.dart'; // Create this file

class CategoryScreen extends ConsumerStatefulWidget {
  final String slug;
  
  const CategoryScreen({super.key, required this.slug});
  
  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels == 
        _scrollController.position.maxScrollExtent) {
      _loadMoreListings();
    }
  }
  
  Future<void> _loadMoreListings() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // In a real app, you'd implement pagination here
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoadingMore = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryDetailProvider(widget.slug));
    final listingsAsync = ref.watch(listingsByCategoryProvider(widget.slug));
    final user = ref.watch(authProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryAsync.when(
            data: (category) => category?.name ?? 'Category',
            loading: () => 'Loading...',
            error: (error, stack) => 'Category',
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/search');
            },
          ),
          if (user != null)
            IconButton(
              icon: Badge(
                label: Consumer(
                  builder: (context, ref, _) {
                    final cartCount = ref.watch(cartCountProvider);
                    return Text(cartCount.toString());
                  },
                ),
                child: const Icon(Icons.shopping_cart),
              ),
              onPressed: () {
                context.push('/cart');
              },
            ),
        ],
      ),
      body: categoryAsync.when(
        data: (category) {
          if (category == null) return const Center(child: Text('Category not found'));
          return _buildCategoryContent(category, listingsAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(categoryDetailProvider(widget.slug));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoryContent(
    CategoryModel category,
    AsyncValue<List<ListingModel>> listingsAsync,
  ) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _buildCategoryHeader(category),
        ),
        
        listingsAsync.when(
          data: (listings) {
            if (listings.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'There are no products in this category yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final listing = listings[index];
                  return ProductCard(listing: listing);
                },
                childCount: listings.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load products',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.refresh(listingsByCategoryProvider(widget.slug));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildCategoryHeader(CategoryModel category) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (category.icon != null && category.icon!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(category.icon!),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (category.description != null && 
                        category.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        category.description ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (category.children != null && category.children!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Subcategories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: category.children!.length,
                    itemBuilder: (context, index) {
                      final subcategory = category.children![index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            context.push('/category/${subcategory.slug}');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (subcategory.icon != null && 
                                    subcategory.icon!.isNotEmpty)
                                  Icon(
                                    _getIconData(subcategory.icon!),
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  subcategory.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
        ],
      ),
    );
  }
  
  IconData _getIconData(String iconName) {
    // Map Laravel FontAwesome icon names to Flutter Icons
    final iconMap = {
      'car': Icons.directions_car,
      'laptop': Icons.laptop,
      'mobile-alt': Icons.phone_android,
      'couch': Icons.chair,
      'tshirt': Icons.checkroom,
      'blender': Icons.kitchen,
      'futbol': Icons.sports_soccer,
      'baby-carriage': Icons.child_friendly,
      'gem': Icons.diamond,
      'book': Icons.menu_book,
      'pills': Icons.medical_services,
      'gamepad': Icons.videogame_asset,
      'home': Icons.home,
      'store': Icons.store,
      'tag': Icons.local_offer,
      'shopping-cart': Icons.shopping_cart,
      'gift': Icons.card_giftcard,
      'star': Icons.star,
      'fire': Icons.local_fire_department,
      'plane': Icons.airplanemode_active,
      'map-marker-alt': Icons.location_on,
      'briefcase': Icons.business_center,
      'tools': Icons.build,
      'question-circle': Icons.help,
      'comments': Icons.comment,
      'info-circle': Icons.info,
      'envelope': Icons.email,
      'th-large': Icons.grid_view,
      'search': Icons.search,
      'user': Icons.person,
      'heart': Icons.favorite,
      'cart': Icons.shopping_cart,
    };
    
    return iconMap[iconName] ?? Icons.category;
  }
}

// Add missing providers if they don't exist
final cartCountProvider = StateProvider<int>((ref) => 0);