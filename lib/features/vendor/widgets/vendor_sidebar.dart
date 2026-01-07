// lib/features/vendor/widgets/vendor_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';

class VendorSidebar extends ConsumerWidget {
  const VendorSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final vendor = user?.vendorProfile;
    final userName = user?.name;
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: user?.avatar != null
                  ? CachedNetworkImageProvider(
                      user!.avatar!.startsWith('http')
                          ? user.avatar!
                          : '${AppConstants.storageUrl}/${user.avatar}',
                    )
                  : null,
              child: user?.avatar == null
                  ? Text(
                      (userName != null && userName.isNotEmpty)
                          ? userName[0].toUpperCase()
                          : 'V',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            accountName: Text(
              vendor?.businessName ?? user?.name ?? 'Vendor',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? user?.phone ?? ''),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => context.go('/vendor/dashboard'),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'My Store',
                  onTap: () => context.go('/vendor/products'),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  label: 'Store Orders',
                  onTap: () => context.go('/vendor/orders'),
                ),
                const Divider(),
                _buildMenuItem(
                  context,
                  icon: Icons.shopping_basket_outlined,
                  label: 'My Purchases',
                  color: Colors.teal,
                  onTap: () => context.push('/buyer/orders'),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  badge: unreadCount,
                  onTap: () => context.go('/vendor/messages'),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  onTap: () => context.push('/vendor/analytics'),
                ),
                const Divider(),
                _buildMenuItem(
                  context,
                  icon: Icons.home_outlined,
                  label: 'Return to Shopping',
                  onTap: () => context.go('/home'),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.go('/vendor/profile'),
                ),
              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    int? badge,
  }) {
    final location = GoRouterState.of(context).uri.path;
    bool isSelected = false;

    if (label == 'Dashboard') {
      isSelected = location.startsWith('/vendor/dashboard');
    } else if (label == 'My Store') {
      isSelected = location.startsWith('/vendor/products');
    } else if (label == 'Store Orders') {
      isSelected = location.startsWith('/vendor/orders');
    } else if (label == 'My Purchases') {
      isSelected = location.startsWith('/buyer/orders');
    } else if (label == 'Messages') {
      isSelected = location.startsWith('/vendor/messages');
    } else if (label == 'Return to Shopping') {
      isSelected = location == '/home';
    } else if (label == 'Settings') {
      isSelected = location.startsWith('/vendor/profile');
    }

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color ?? (isSelected ? AppColors.primary : AppColors.textPrimary)),
          if (badge != null && badge > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? (isSelected ? AppColors.primary : AppColors.textPrimary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
    );
  }
}
