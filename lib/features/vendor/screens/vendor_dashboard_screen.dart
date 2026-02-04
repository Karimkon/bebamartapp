// lib/features/vendor/screens/vendor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/vendor_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen>
    with WidgetsBindingObserver {
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.invalidate(vendorDashboardProvider);
      ref.invalidate(vendorRecentOrdersProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only refresh if this screen is actually visible (not covered by another route)
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrentRoute) {
        _refreshDashboard();
      }
    }
  }

  Future<void> _refreshDashboard() async {
    ref.invalidate(vendorDashboardProvider);
    ref.invalidate(vendorRecentOrdersProvider);
    ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _checkStatus() async {
    setState(() => _isCheckingStatus = true);
    ref.invalidate(vendorDashboardProvider);
    ref.invalidate(vendorRecentOrdersProvider);
    await ref.read(authProvider.notifier).refreshUser();
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isCheckingStatus = false);
      final dashboardAsync = ref.read(vendorDashboardProvider);
      dashboardAsync.whenData((stats) {
        if (stats.isApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been approved! Welcome to BebaMart!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(vendorDashboardProvider);
    final recentOrdersAsync = ref.watch(vendorRecentOrdersProvider);
    final user = ref.watch(currentUserProvider);
    final vendor = user?.vendorProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            if (error is VendorDeactivatedException) {
              return _buildDeactivatedScreen(error);
            }
            if (error is VendorOnboardingRequiredException) {
              return _buildOnboardingRequiredScreen();
            }
            if (error is VendorApprovalPendingException) {
              return _buildPendingApprovalScreen();
            }
            return _buildErrorScreen();
          },
          data: (stats) {
            if (stats.isPending) return _buildPendingApprovalScreen();
            if (stats.isRejected) return _buildRejectedScreen(stats.vettingNotes);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom App Bar
                SliverToBoxAdapter(
                  child: _buildHeader(user, vendor, stats),
                ),

                // Stats Cards
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Stats Row
                        _buildQuickStatsRow(stats),
                        const SizedBox(height: 20),

                        // Revenue Card
                        _buildRevenueCard(stats),
                        const SizedBox(height: 20),

                        // Quick Actions
                        _buildQuickActions(),
                        const SizedBox(height: 20),

                        // Recent Orders
                        _buildRecentOrdersSection(recentOrdersAsync),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user, dynamic vendor, VendorDashboardStats stats) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Top Row - Avatar, Name, Actions
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: user?.avatar != null
                          ? CachedNetworkImage(
                              imageUrl: user!.avatar!.startsWith('http')
                                  ? user.avatar!
                                  : '${AppConstants.storageUrl}/${user.avatar}',
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildAvatarPlaceholder(user?.name),
                            )
                          : _buildAvatarPlaceholder(user?.name),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name & Store
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          vendor?.businessName ?? user?.name ?? 'Vendor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  _buildHeaderAction(
                    Icons.storefront_outlined,
                    () => context.go('/home'),
                    tooltip: 'Shop',
                  ),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
                      return _buildHeaderAction(
                        Icons.notifications_outlined,
                        () => context.push('/vendor/notifications'),
                        badge: unread,
                        tooltip: 'Notifications',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderStat('${stats.totalListings}', 'Products'),
                    _buildVerticalDivider(),
                    _buildHeaderStat('${stats.totalOrders}', 'Orders'),
                    _buildVerticalDivider(),
                    _buildHeaderStat('${stats.averageRating.toStringAsFixed(1)}', 'Rating'),
                    _buildVerticalDivider(),
                    _buildHeaderStat('${stats.totalViews}', 'Views'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String? name) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'V',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap, {int? badge, String? tooltip}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, color: Colors.white, size: 22)),
            if (badge != null && badge > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildQuickStatsRow(VendorDashboardStats stats) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            icon: Icons.pending_actions,
            label: 'Pending',
            value: '${stats.pendingOrders}',
            color: Colors.orange,
            onTap: () => context.go('/vendor/orders'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.local_shipping_outlined,
            label: 'Processing',
            value: '${stats.processingOrders}',
            color: Colors.blue,
            onTap: () => context.go('/vendor/orders'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.check_circle_outline,
            label: 'Delivered',
            value: '${stats.deliveredOrders}',
            color: Colors.green,
            onTap: () => context.go('/vendor/orders'),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard(VendorDashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Month',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'UGX ${_formatCurrency(stats.totalRevenue)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.shade200,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'UGX ${_formatCurrency(stats.availableBalance)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Pending: UGX ${_formatCurrency(stats.pendingBalance)}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_box_outlined,
                label: 'Add Product',
                color: AppColors.primary,
                onTap: () => context.push('/vendor/products/create'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: Colors.purple,
                onTap: () => context.push('/vendor/analytics'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.shopping_cart_outlined,
                label: 'My Orders',
                color: Colors.teal,
                onTap: () => context.push('/buyer/orders'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.home_repair_service_outlined,
                label: 'Add Service',
                color: Colors.orange,
                onTap: () => context.push('/vendor/services/create'),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrdersSection(AsyncValue<List<VendorOrderModel>> recentOrdersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/vendor/orders'),
              child: Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentOrdersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => _buildEmptyOrders(),
          data: (orders) {
            if (orders.isEmpty) return _buildEmptyOrders();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (context, index) => _OrderItem(order: orders[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent orders',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshDashboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // Keep the pending/rejected/deactivated screens from original
  Widget _buildDeactivatedScreen(VendorDeactivatedException error) {
    return _buildStatusScreen(
      icon: Icons.block,
      iconColor: AppColors.error,
      title: 'Account Deactivated',
      message: error.message,
      actionLabel: 'Contact Support',
      onAction: () {},
      showLogout: true,
    );
  }

  Widget _buildOnboardingRequiredScreen() {
    return _buildStatusScreen(
      icon: Icons.store_mall_directory_outlined,
      iconColor: AppColors.primary,
      title: 'Complete Your Profile',
      message: 'Before you can start selling, complete your vendor registration.',
      actionLabel: 'Complete Registration',
      onAction: () => context.push('/vendor/onboarding'),
    );
  }

  Widget _buildPendingApprovalScreen() {
    return _buildStatusScreen(
      icon: Icons.hourglass_top_outlined,
      iconColor: Colors.orange,
      title: 'Under Review',
      message: 'Your application is being reviewed. This usually takes 24-48 hours.',
      actionLabel: _isCheckingStatus ? 'Checking...' : 'Check Status',
      onAction: _isCheckingStatus ? null : _checkStatus,
      showLogout: true,
    );
  }

  Widget _buildRejectedScreen(String? notes) {
    return _buildStatusScreen(
      icon: Icons.cancel_outlined,
      iconColor: AppColors.error,
      title: 'Application Rejected',
      message: notes ?? 'Your application was not approved. Please resubmit.',
      actionLabel: 'Resubmit',
      onAction: () => context.push('/vendor/onboarding'),
    );
  }

  Widget _buildStatusScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String actionLabel,
    VoidCallback? onAction,
    bool showLogout = false,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: iconColor),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
            if (showLogout) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem extends StatelessWidget {
  final VendorOrderModel order;

  const _OrderItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => context.push('/vendor/orders/${order.id}'),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getStatusColor(order.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getStatusIcon(order.status),
          color: _getStatusColor(order.status),
          size: 24,
        ),
      ),
      title: Text(
        '#${order.orderNumber}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        order.buyer?.name ?? 'Customer',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'UGX ${order.total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.statusDisplay,
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }
}
