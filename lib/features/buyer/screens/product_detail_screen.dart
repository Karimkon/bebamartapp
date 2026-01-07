// lib/features/buyer/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../providers/listing_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;
  
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  ListingVariantModel? _selectedVariant;

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingDetailProvider(widget.productId));
    final isWishlisted = ref.watch(isInWishlistProvider(widget.productId));
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: listingAsync.when(
        data: (listing) {
          if (listing == null) return _buildNotFound();
          return _buildContent(listing, isWishlisted);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildContent(ListingModel listing, bool isWishlisted) {
    final availableColors = _getAvailableColors(listing);
    final availableSizes = _getAvailableSizes(listing);
    final hasVariants = listing.variants.isNotEmpty && (availableColors.isNotEmpty || availableSizes.isNotEmpty);
    final effectivePrice = _selectedVariant?.effectivePrice ?? listing.price;
    final effectiveStock = _selectedVariant?.stock ?? listing.stock;

    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.white,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_outline,
                        color: isWishlisted ? AppColors.error : AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    onPressed: _handleToggleWishlist,
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                      child: const Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 20),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ];
          },
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildImageGallery(listing),
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UGX ${NumberFormat('#,##0', 'en_US').format(effectivePrice)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Text(listing.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      _buildRatingAndStock(listing, effectiveStock),
                      if (listing.vendor != null) ...[const SizedBox(height: 16), _buildVendorCard(listing)],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (hasVariants) _buildVariantSection(listing, availableColors, availableSizes),
                if (hasVariants) const SizedBox(height: 8),
                _buildDescriptionSection(listing),
                if (listing.sku != null || listing.origin != null) _buildDetailsSection(listing),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(listing),
        ),
      ],
    );
  }

  Widget _buildBottomBar(ListingModel listing) {
    final hasVariants = listing.variants.isNotEmpty && 
        (_getAvailableColors(listing).isNotEmpty || _getAvailableSizes(listing).isNotEmpty);
    final effectiveStock = _selectedVariant?.stock ?? listing.stock;
    final isInStock = effectiveStock > 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    color: _quantity > 1 ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => setState(() => _quantity++),
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isInStock ? () => _handleAddToCart(listing, hasVariants) : null,
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.textTertiary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('Product not found', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Error: $error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(listingDetailProvider(widget.productId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(ListingModel listing) {
    final images = listing.images;
    if (images.isEmpty) {
      return Container(
        height: 300,
        color: AppColors.background,
        child: const Center(child: Icon(Icons.image, size: 64, color: AppColors.textTertiary)),
      );
    }
    
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(images[_selectedImageIndex].fullPath),
          child: Container(
            height: 300,
            width: double.infinity,
            color: AppColors.white,
            child: Image.network(
              images[_selectedImageIndex].fullPath,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.image_not_supported, size: 64, color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Container(
            height: 80,
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        images[index].fullPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.image, size: 24, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRatingAndStock(ListingModel listing, int effectiveStock) {
    return Row(
      children: [
        const Icon(Icons.star, color: AppColors.warning, size: 20),
        const SizedBox(width: 4),
        Text(listing.displayRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(' (${listing.displayReviewsCount} reviews)', style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: effectiveStock > 0 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            effectiveStock > 0 ? 'In Stock ($effectiveStock)' : 'Out of Stock',
            style: TextStyle(
              color: effectiveStock > 0 ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorCard(ListingModel listing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(
              listing.vendor!.businessName.isNotEmpty ? listing.vendor!.businessName.substring(0, 1).toUpperCase() : 'V',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.vendor!.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(listing.vendor!.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleContactVendor(listing),
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSection(ListingModel listing, List<String> colors, List<String> sizes) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (colors.isNotEmpty) ...[
            Text('Color: ${_selectedColor ?? "Select"}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() { _selectedColor = color; _updateSelectedVariant(listing); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                    ),
                    child: Text(color, style: TextStyle(color: isSelected ? AppColors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (sizes.isNotEmpty) ...[
            Text('Size: ${_selectedSize ?? "Select"}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sizes.map((size) {
                final isSelected = _selectedSize == size;
                return GestureDetector(
                  onTap: () => setState(() { _selectedSize = size; _updateSelectedVariant(listing); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                    ),
                    child: Text(size, style: TextStyle(color: isSelected ? AppColors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ],
          if (_selectedVariant != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Selected Variant', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_selectedVariant!.stock} in stock', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  Text(_selectedVariant!.formattedPrice, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(ListingModel listing) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(listing.description ?? 'No description available', style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(ListingModel listing) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (listing.sku != null) _buildDetailRow('SKU', listing.sku!),
          if (listing.origin != null) _buildDetailRow('Origin', listing.origin!),
          if (listing.condition != null) _buildDetailRow('Condition', listing.condition!),
          _buildDetailRow('Stock', '${listing.stock} available'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  List<String> _getAvailableColors(ListingModel listing) {
    final colors = <String>{};
    for (final variant in listing.variants) {
      if (variant.color != null && variant.stock > 0) colors.add(variant.color!);
    }
    return colors.toList();
  }

  List<String> _getAvailableSizes(ListingModel listing) {
    final sizes = <String>{};
    for (final variant in listing.variants) {
      if (variant.size != null && variant.stock > 0) sizes.add(variant.size!);
    }
    return sizes.toList();
  }

  void _updateSelectedVariant(ListingModel listing) {
    print('🎯 Updating selected variant...');
    print('   Selected color: $_selectedColor');
    print('   Selected size: $_selectedSize');
    
    final matchingVariants = listing.variants.where((v) {
      if (v.stock <= 0) return false;
      bool colorMatch = _selectedColor == null || v.color == _selectedColor;
      bool sizeMatch = _selectedSize == null || v.size == _selectedSize;
      return colorMatch && sizeMatch;
    }).toList();
    
    print('   Found ${matchingVariants.length} matching variants');
    
    _selectedVariant = matchingVariants.firstOrNull;
    
    if (_selectedVariant != null) {
      print('✅ Selected variant: ${_selectedVariant!.id}');
      print('   Price: ${_selectedVariant!.effectivePrice}');
      print('   Stock: ${_selectedVariant!.stock}');
    } else {
      print('❌ No variant found!');
    }
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(imageUrl, fit: BoxFit.contain))),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggleWishlist() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showLoginPrompt('Please login to add items to wishlist');
      return;
    }
    try {
      await ref.read(wishlistProvider.notifier).toggleWishlist(widget.productId);
      if (mounted) {
        final isNowWishlisted = ref.read(wishlistProvider).isWishlisted(widget.productId);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(isNowWishlisted ? 'Added to wishlist' : 'Removed from wishlist'),
              backgroundColor: isNowWishlisted ? AppColors.success : AppColors.textSecondary,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error, duration: const Duration(seconds: 2)));
      }
    }
  }

  Future<void> _handleAddToCart(ListingModel listing, bool hasVariants) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showLoginPrompt('Please login to add items to cart');
      return;
    }
    
    print('🛒 Add to Cart Triggered');
    print('   Product ID: ${widget.productId}');
    print('   Has variants: $hasVariants');
    print('   Selected Variant: ${_selectedVariant?.id}');
    print('   Selected Color: $_selectedColor');
    print('   Selected Size: $_selectedSize');
    print('   Quantity: $_quantity');
    
    if (hasVariants && _selectedVariant == null) {
      print('⚠️ No variant selected - showing picker');
      _showVariantPickerModal(listing);
      return;
    }
    
    try {
      final variantId = hasVariants ? _selectedVariant?.id : null;
      
      print('📦 Sending to cart provider:');
      print('   - Variant ID: $variantId');
      print('   - Attributes: color=$_selectedColor, size=$_selectedSize');
      
      final success = await ref.read(cartProvider.notifier).addToCart(
        widget.productId,
        _quantity,
        variantId: variantId,
        attributes: {
          if (_selectedColor != null) 'color': _selectedColor!,
          if (_selectedSize != null) 'size': _selectedSize!,
        },
      );
      
      if (mounted && success) {
        print('✅ Successfully added to cart!');
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Added to cart!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2)
            ),
          );
      } else {
        print('❌ Failed to add to cart (success=false)');
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2)
            ),
          );
      }
    }
  }

  void _showLoginPrompt(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'Login', textColor: AppColors.white, onPressed: () => context.push('/login')),
        ),
      );
  }

  Future<void> _handleContactVendor(ListingModel listing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showLoginPrompt('Please login to contact the vendor');
      return;
    }

    if (listing.vendor == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Vendor information not available'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversationId = await ref.read(conversationsProvider.notifier).startConversation(
        vendorProfileId: listing.vendor!.id,
        listingId: listing.id,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (conversationId != null) {
          context.push('/chat/$conversationId');
        } else {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Failed to start conversation'),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  void _showVariantPickerModal(ListingModel listing) {
    final availableColors = _getAvailableColors(listing);
    final availableSizes = _getAvailableSizes(listing);
    String? tempColor = _selectedColor;
    String? tempSize = _selectedSize;
    ListingVariantModel? tempVariant = _selectedVariant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateTempVariant() {
            tempVariant = listing.variants.where((v) {
              if (v.stock <= 0) return false;
              return (tempColor == null || v.color == tempColor) && (tempSize == null || v.size == tempSize);
            }).firstOrNull;
          }

          bool isComplete() {
            if (availableColors.isNotEmpty && tempColor == null) return false;
            if (availableSizes.isNotEmpty && tempSize == null) return false;
            return tempVariant != null;
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.tune, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Select Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Choose variant before adding to cart', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (availableColors.isNotEmpty) ...[
                          const Row(children: [Text('Color', style: TextStyle(fontWeight: FontWeight.w600)), Text(' *', style: TextStyle(color: AppColors.error))]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableColors.map((color) {
                              final isSelected = tempColor == color;
                              return GestureDetector(
                                onTap: () => setModalState(() { tempColor = color; updateTempVariant(); }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                                  ),
                                  child: Text(color, style: TextStyle(color: isSelected ? AppColors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (availableSizes.isNotEmpty) ...[
                          const Row(children: [Text('Size', style: TextStyle(fontWeight: FontWeight.w600)), Text(' *', style: TextStyle(color: AppColors.error))]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableSizes.map((size) {
                              final isSelected = tempSize == size;
                              return GestureDetector(
                                onTap: () => setModalState(() { tempSize = size; updateTempVariant(); }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                                  ),
                                  child: Text(size, style: TextStyle(color: isSelected ? AppColors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (tempVariant != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Selected Variant', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text([if (tempColor != null) 'Color: $tempColor', if (tempSize != null) 'Size: $tempSize'].join(' | '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(tempVariant!.formattedPrice, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  Text('${tempVariant!.stock} in stock', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ]),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.border))),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isComplete() ? () async {
                              setState(() { _selectedColor = tempColor; _selectedSize = tempSize; _selectedVariant = tempVariant; });
                              Navigator.pop(context);
                              try {
                                final success = await ref.read(cartProvider.notifier).addToCart(widget.productId, _quantity, variantId: _selectedVariant?.id, attributes: {if (_selectedColor != null) 'color': _selectedColor, if (_selectedSize != null) 'size': _selectedSize});
                                if (mounted && success) {
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(const SnackBar(content: Text('Added to cart!'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)));
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error, duration: Duration(seconds: 2)));
                                }
                              }
                            } : null,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: AppColors.primary, foregroundColor: AppColors.white, disabledBackgroundColor: AppColors.textTertiary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Confirm & Add to Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}