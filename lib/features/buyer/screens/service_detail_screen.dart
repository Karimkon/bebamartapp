// lib/features/buyer/screens/service_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/service_category_provider.dart';
import '../../../shared/models/service_model.dart';
import '../../chat/providers/chat_provider.dart';

class ServiceDetailScreen extends ConsumerWidget {
  final String slug;
  const ServiceDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      body: servicesAsync.when(
        data: (services) {
          final service = services.firstWhere((s) => s.slug == slug, orElse: () => throw Exception('Service not found'));
          
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    service.fullImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By ${service.vendor.businessName}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (service.price != null)
                        Text(
                          'UGX ${service.price}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        service.description ?? 'No description provided.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: servicesAsync.maybeWhen(
        data: (services) {
          final service = services.firstWhere((s) => s.slug == slug, orElse: () => services.first);
          return _buildBottomBar(context, ref, service);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, VendorServiceModel service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleContactVendor(context, ref, service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Contact Professional'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContactVendor(BuildContext context, WidgetRef ref, VendorServiceModel service) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversationId = await ref.read(conversationsProvider.notifier).startConversation(
        vendorProfileId: service.vendor.id,
        // For services/jobs, we might not have a listing_id in the same sense, 
        // but the backend handles it.
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (conversationId != null) {
          context.push('/chat/$conversationId');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
