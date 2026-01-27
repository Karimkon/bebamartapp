// lib/features/buyer/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing_model.dart';

class ProductCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onWishlistTap;
  final VoidCallback? onCartTap;
  
  const ProductCard({
    super.key,
    required this.listing,
    this.onWishlistTap,
    this.onCartTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push('/product/${listing.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: listing.primaryImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              listing.primaryImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          ),
                  ),
                  
                  // Wishlist button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: onWishlistTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Product Title
              Text(
                listing.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Rating
              if (listing.rating > 0) ...[
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      listing.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${listing.displayReviewsCount})',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              
              // Price
              Text(
                listing.formattedPrice,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Stock status
              Row(
                children: [
                  Icon(
                    listing.isInStock ? Icons.check_circle : Icons.cancel,
                    size: 12,
                    color: listing.isInStock ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    listing.isInStock ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 10,
                      color: listing.isInStock ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),

              // Vendor info with duration badge and verified tick
              if (listing.vendor != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        listing.vendor!.durationBadge,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (listing.vendor!.isVerified)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1D9BF0), Color(0xFF1A8CD8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1D9BF0).withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}