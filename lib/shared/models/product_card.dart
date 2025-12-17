import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/buyer/providers/cart_provider.dart';
import '../../features/buyer/providers/variation_provider.dart';
import '../../core/theme/app_theme.dart';
import 'variation_modal.dart';

class ProductCard extends ConsumerStatefulWidget {
  final int id;
  final String title;
  final double price;
  final String? imageUrl;
  final String? vendorName;
  final double rating;
  final int reviewCount;
  final VoidCallback? onTap;
  final bool showAddButton;

  const ProductCard({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    this.imageUrl,
    this.vendorName,
    this.rating = 0,
    this.reviewCount = 0,
    this.onTap,
    this.showAddButton = true,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.grayLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: widget.imageUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image,
                                color: AppColors.textTertiary,
                                size: 40,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            color: AppColors.textTertiary,
                            size: 40,
                          ),
                        ),
                ),
                
                // Wishlist button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border, size: 20),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
            
            // Product Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Vendor
                  if (widget.vendorName != null)
                    Text(
                      widget.vendorName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Rating
                  if (widget.rating > 0)
                    Row(
                      children: [
                        ...List.generate(5, (index) => Icon(
                          Icons.star,
                          size: 14,
                          color: index < widget.rating.floor()
                              ? AppColors.warning
                              : AppColors.textTertiary,
                        )),
                        const SizedBox(width: 4),
                        Text(
                          '(${widget.reviewCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Price & Add to Cart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'UGX ${widget.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      
                      if (widget.showAddButton)
                        IconButton(
                          icon: _isAdding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_shopping_cart),
                          onPressed: () => _handleAddToCart(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddToCart(BuildContext context) async {
    final authState = ref.watch(authProvider);
    
    // Check authentication
    if (!authState.isAuthenticated) {
      // Show login modal
      showModalBottomSheet(
        context: context,
        builder: (context) => const LoginRequiredModal(),
      );
      return;
    }
    
    // Load variations first
    final variationState = ref.watch(variationProvider(widget.id));
    
    if (variationState.isLoading) {
      // Show loading
      setState(() => _isAdding = true);
      await ref.read(variationProvider(widget.id).notifier).loadVariations(widget.id);
      setState(() => _isAdding = false);
    }
    
    final hasVariations = variationState.hasVariations;
    
    if (hasVariations) {
      // Show variation modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => VariationModal(
          listingId: widget.id,
          productTitle: widget.title,
          basePrice: widget.price,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to cart successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
      );
    } else {
      // Add directly to cart
      setState(() => _isAdding = true);
      try {
        await ref.read(cartProvider.notifier).addToCart(
          listingId: widget.id,
          quantity: 1,
        );
        
        setState(() => _isAdding = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class LoginRequiredModal extends StatelessWidget {
  const LoginRequiredModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock,
            size: 60,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please login or create an account to add items to cart',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/register');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}