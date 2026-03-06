// lib/features/buyer/screens/vendor_store_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/listing_model.dart';
import '../../auth/providers/auth_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final vendorPublicProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, vendorId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/api/vendors/$vendorId/profile');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['vendor']);
    }
  } catch (_) {}
  return null;
});

final vendorPublicListingsProvider =
    FutureProvider.family<List<ListingModel>, int>((ref, vendorId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response =
        await api.get('/api/marketplace?vendor_id=$vendorId&per_page=50');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as List? ?? [];
      return data.map((e) => ListingModel.fromJson(e)).toList();
    }
  } catch (_) {}
  return [];
});

// ── Screen ─────────────────────────────────────────────────────────────────

class VendorStoreScreen extends ConsumerWidget {
  final int vendorId;
  const VendorStoreScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(vendorPublicProfileProvider(vendorId));
    final listingsAsync = ref.watch(vendorPublicListingsProvider(vendorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, profileAsync),
          SliverToBoxAdapter(child: _buildVendorInfo(context, profileAsync)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          listingsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SliverFillRemaining(
                child: Center(child: Text('Failed to load products'))),
            data: (listings) => listings.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text('No products listed yet')))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _ProductCard(listing: listings[index]),
                        childCount: listings.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, AsyncValue<Map<String, dynamic>?> profileAsync) {
    final name = profileAsync.whenOrNull(
            data: (p) => p?['business_name'] as String?) ??
        'Vendor Store';
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorInfo(
      BuildContext context, AsyncValue<Map<String, dynamic>?> profileAsync) {
    return profileAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (vendor) {
        if (vendor == null) return const SizedBox.shrink();
        final phone = vendor['phone'] as String?;
        final city = vendor['city'] as String?;
        final country = vendor['country'] as String?;
        final isVerified = vendor['is_verified'] == true;
        final description = vendor['description'] as String?;
        final logoUrl = vendor['logo'] as String?;
        final location =
            [city, country].where((s) => s != null && s.isNotEmpty).join(', ');

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(vendor['business_name'] as String? ?? 'V', logoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              vendor['business_name'] as String? ?? 'Vendor',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                size: 20, color: Color(0xFF3B82F6)),
                          ],
                        ]),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(location,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Contact:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _callPhone(phone),
                    child: Row(children: [
                      Icon(Icons.phone_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(phone,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, String? logoUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = logoUrl.startsWith('http')
          ? logoUrl
          : '${AppConstants.baseUrl}/storage/$logoUrl';
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.primary,
        child: null,
      );
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primary,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

// ── Product Card ────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ListingModel listing;
  const _ProductCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.primaryImage;
    return GestureDetector(
      onTap: () => context.push('/product/${listing.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    listing.formattedPrice,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: AppColors.background,
      child: const Center(
          child: Icon(Icons.image_outlined,
              size: 40, color: AppColors.textTertiary)));
}
