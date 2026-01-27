// lib/features/vendor/screens/vendor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/vendor_provider.dart';
import '../../../core/constants/app_constants.dart';
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
    // Load data when screen initializes
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
    // Auto-refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshDashboard();
    }
  }

  Future<void> _refreshDashboard() async {
    ref.invalidate(vendorDashboardProvider);
    ref.invalidate(vendorRecentOrdersProvider);
    // Also refresh user data to get updated vendor profile
    ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _checkStatus() async {
    setState(() => _isCheckingStatus = true);

    // Refresh everything
    ref.invalidate(vendorDashboardProvider);
    ref.invalidate(vendorRecentOrdersProvider);
    await ref.read(authProvider.notifier).refreshUser();

    // Wait a bit for the provider to reload
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isCheckingStatus = false);

      // Check if approved now
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCountAsync = ref.watch(unreadCountProvider);
              final unreadCount = unreadCountAsync.valueOrNull ?? 0;

              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => context.push('/vendor/messages'),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            // Check if vendor is deactivated
            if (error is VendorDeactivatedException) {
              return _buildDeactivatedScreen(error);
            }
            // Check if vendor needs onboarding (no vendor profile yet)
            if (error is VendorOnboardingRequiredException) {
              return _buildOnboardingRequiredScreen();
            }
            // Check if pending approval
            if (error is VendorApprovalPendingException) {
              return _buildPendingApprovalScreen();
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load dashboard', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
          data: (stats) {
            // Check if vendor is pending approval
            if (stats.isPending) {
              return _buildPendingApprovalScreen();
            }
            // Check if vendor was rejected
            if (stats.isRejected) {
              return _buildRejectedScreen(stats.vettingNotes);
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeCard(stats),
                  const SizedBox(height: 20),

                  // Stats Grid
                  _buildStatsGrid(stats),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 20),

                  // Revenue Card
                  _buildRevenueCard(stats),
                  const SizedBox(height: 20),

                  // Recent Orders Section
                  _buildRecentOrdersSection(recentOrdersAsync),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(VendorDashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
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
                const Text(
                  'Welcome back!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your Store',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniStat(Icons.star, '${stats.averageRating.toStringAsFixed(1)}', 'Rating'),
                    const SizedBox(width: 20),
                    _buildMiniStat(Icons.visibility, '${stats.totalViews}', 'Views'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatsGrid(VendorDashboardStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1, // Reduced further to prevent overflow
      children: [
        _StatCard(
          title: 'Total Products',
          value: '${stats.totalListings}',
          subtitle: '${stats.activeListings} active',
          icon: Icons.inventory_2_outlined,
          color: Colors.blue,
          onTap: () => context.go('/vendor/products'),
        ),
        _StatCard(
          title: 'Total Orders',
          value: '${stats.totalOrders}',
          subtitle: '${stats.pendingOrders} pending',
          icon: Icons.shopping_bag_outlined,
          color: Colors.orange,
          onTap: () => context.go('/vendor/orders'),
        ),
        _StatCard(
          title: 'Processing',
          value: '${stats.processingOrders}',
          subtitle: 'In progress',
          icon: Icons.local_shipping_outlined,
          color: Colors.purple,
          onTap: () => context.go('/vendor/orders'),
        ),
        _StatCard(
          title: 'Delivered',
          value: '${stats.deliveredOrders}',
          subtitle: 'Completed',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          onTap: () => context.go('/vendor/orders'),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Product',
                color: AppColors.primary,
                onTap: () => context.push('/vendor/products/create'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.list_alt_outlined,
                label: 'Store Orders',
                color: Colors.orange,
                onTap: () => context.go('/vendor/orders'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: Colors.purple,
                onTap: () => context.push('/vendor/analytics'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.shopping_bag_outlined,
                label: 'My Purchases',
                color: Colors.teal,
                onTap: () => context.push('/buyer/orders'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueCard(VendorDashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                'Revenue Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Month',
                  style: TextStyle(color: Colors.green, fontSize: 12),
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
                      'Total Revenue',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UGX ${_formatCurrency(stats.totalRevenue)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade200),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Revenue',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UGX ${_formatCurrency(stats.monthlyRevenue)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BalanceInfo(
                label: 'Available Balance',
                amount: stats.availableBalance,
                color: Colors.green,
              ),
              _BalanceInfo(
                label: 'Pending Balance',
                amount: stats.pendingBalance,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.go('/vendor/orders'),
              child: Text('View All', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentOrdersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to load orders', style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text('No recent orders', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderListItem(order: order);
                },
              ),
            );
          },
        ),
      ],
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

  Widget _buildDeactivatedScreen(VendorDeactivatedException error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Warning Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                size: 50,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            const Text(
              'Account Deactivated',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              error.message,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Contact Support Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (error.supportEmail != null) ...[
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: error.supportEmail!,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (error.supportPhone != null)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: error.supportPhone!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appeal Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Open email or support page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please contact support to submit an appeal'),
                    ),
                  );
                },
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit an Appeal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sign Out Button
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
        ),
      ),
    );
  }

  Widget _buildOnboardingRequiredScreen() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store_mall_directory_outlined,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Complete Your Vendor Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Before you can start selling, you need to complete your vendor registration by providing your business details and documents.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/vendor/onboarding'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Complete Registration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalScreen() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_outlined,
                size: 50,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Application Under Review',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Your vendor application is being reviewed by our team. This usually takes 24-48 hours. You will receive an email notification once approved.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You cannot list products until your application is approved.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCheckingStatus ? null : _checkStatus,
                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isCheckingStatus ? 'Checking...' : 'Check Status'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sign out option
            TextButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/');
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(String? rejectionNotes) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                size: 50,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Application Rejected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Unfortunately, your vendor application was not approved. Please review the feedback below and resubmit your application.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (rejectionNotes != null && rejectionNotes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.feedback_outlined, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Reason for Rejection:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionNotes,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/vendor/onboarding'),
                icon: const Icon(Icons.refresh),
                label: const Text('Resubmit Application'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  title,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceInfo extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceInfo({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          'UGX ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _OrderListItem extends StatelessWidget {
  final VendorOrderModel order;

  const _OrderListItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/vendor/orders/${order.id}'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(order.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getStatusIcon(order.status),
          color: _getStatusColor(order.status),
          size: 20,
        ),
      ),
      title: Text(
        '#${order.orderNumber}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        order.buyer?.name ?? 'Customer',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'UGX ${order.total.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              order.statusDisplay,
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontSize: 10,
                fontWeight: FontWeight.w500,
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