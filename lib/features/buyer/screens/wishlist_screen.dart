// lib/features/buyer/screens/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_widgets.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Wishlist'), centerTitle: true),
      body: const EmptyState(
        icon: Icons.favorite_outline,
        title: 'Your wishlist is empty',
        message: 'Save items you love to buy them later',
        actionText: 'Explore Products',
      ),
    );
  }
}
