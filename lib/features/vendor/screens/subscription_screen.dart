// lib/features/vendor/screens/subscription_screen.dart
// Vendor Subscription Management Screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(subscriptionProvider.notifier).loadPlans();
      ref.read(subscriptionProvider.notifier).loadCurrentSubscription();
      ref.read(subscriptionProvider.notifier).loadPaymentHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Subscription', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Plans'),
            Tab(text: 'My Subscription'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlansTab(state),
                _buildCurrentSubscriptionTab(state),
              ],
            ),
    );
  }

  Widget _buildPlansTab(SubscriptionState state) {
    if (state.plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No plans available', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.plans.length,
        itemBuilder: (context, index) {
          final plan = state.plans[index];
          final isCurrentPlan = state.currentSubscription?.plan?.id == plan.id;
          return _buildPlanCard(plan, isCurrentPlan, state);
        },
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanModel plan, bool isCurrentPlan, SubscriptionState state) {
    final isPremium = plan.slug == 'gold';
    final isSilver = plan.slug == 'silver';
    final isBronze = plan.slug == 'bronze';

    Color cardColor = Colors.white;
    Color accentColor = AppColors.primary;

    if (isPremium) {
      accentColor = Colors.amber[700]!;
    } else if (isSilver) {
      accentColor = Colors.grey[600]!;
    } else if (isBronze) {
      accentColor = Colors.orange[700]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isPremium ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentPlan
            ? BorderSide(color: AppColors.success, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan Header
          Container(
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'BEST VALUE',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan.formattedPrice,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Plan Features
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeatureItem(
                  Icons.rocket_launch,
                  plan.boostDescription,
                  accentColor,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  Icons.star,
                  plan.featuredDescription,
                  accentColor,
                ),
                if (plan.badgeEnabled) ...[
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.verified,
                    plan.badgeText ?? 'Seller Badge',
                    accentColor,
                  ),
                ],
                if (plan.features.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...plan.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFeatureItem(
                          Icons.check_circle,
                          feature,
                          Colors.green,
                        ),
                      )),
                ],
              ],
            ),
          ),

          // Subscribe Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: isCurrentPlan
                  ? null
                  : () => _onSubscribe(plan, state),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan ? Colors.grey : accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isCurrentPlan
                    ? 'Current Plan'
                    : plan.isFreePlan
                        ? 'Switch to Free'
                        : 'Subscribe Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSubscriptionTab(SubscriptionState state) {
    final subscription = state.currentSubscription;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Card
            _buildCurrentPlanCard(subscription),

            if (subscription != null && !subscription.plan!.isFreePlan) ...[
              const SizedBox(height: 24),
              _buildSubscriptionDetails(subscription),
            ],

            const SizedBox(height: 24),

            // Payment History
            const Text(
              'Payment History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentHistory(state.paymentHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(VendorSubscriptionModel? subscription) {
    final planName = subscription?.plan?.name ?? 'Free';
    final isFreePlan = subscription?.plan?.isFreePlan ?? true;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isFreePlan
                ? [Colors.grey[400]!, Colors.grey[600]!]
                : [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Plan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (subscription?.plan?.badgeEnabled == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subscription?.plan?.badgeText ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              planName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isFreePlan && subscription != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    subscription.isActive
                        ? Icons.check_circle
                        : Icons.warning,
                    color: subscription.isActive ? Colors.green[300] : Colors.orange[300],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subscription.statusDisplay,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subscription.daysRemainingDisplay,
                style: TextStyle(
                  color: subscription.isExpiringSoon
                      ? Colors.orange[300]
                      : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails(VendorSubscriptionModel subscription) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscription Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Expires', subscription.expiryDisplay),
            _buildDetailRow('Auto-Renew', subscription.autoRenew ? 'Enabled' : 'Disabled'),
            _buildDetailRow('Boost', subscription.plan?.boostDescription ?? '1x'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _toggleAutoRenew(subscription),
                    child: Text(
                      subscription.autoRenew ? 'Disable Auto-Renew' : 'Enable Auto-Renew',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelSubscription(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(List<SubscriptionPaymentModel> payments) {
    if (payments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No payment history',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final payment = payments[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: payment.isCompleted
                  ? Colors.green[100]
                  : payment.isPending
                      ? Colors.orange[100]
                      : Colors.red[100],
              child: Icon(
                payment.isCompleted
                    ? Icons.check
                    : payment.isPending
                        ? Icons.access_time
                        : Icons.close,
                color: payment.isCompleted
                    ? Colors.green
                    : payment.isPending
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            title: Text(payment.planName ?? 'Subscription'),
            subtitle: Text(payment.dateDisplay),
            trailing: Text(
              payment.formattedAmount,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onSubscribe(SubscriptionPlanModel plan, SubscriptionState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Subscribe to ${plan.name}'),
        content: Text(
          plan.isFreePlan
              ? 'Switch to the free plan?'
              : 'Subscribe to ${plan.name} for ${plan.formattedPrice}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ref.read(subscriptionProvider.notifier).subscribe(plan.id);

    if (!mounted) return;

    if (result.success) {
      if (result.requiresPayment && result.paymentUrl != null) {
        // Open payment URL - try multiple methods
        final uri = Uri.parse(result.paymentUrl!);
        bool launched = false;

        // Try in-app browser first (most reliable for payment pages)
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        } catch (e) {
          print('InAppBrowserView failed: $e');
        }

        // Fallback to external browser
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            print('ExternalApplication failed: $e');
          }
        }

        // Last resort: platform default
        if (!launched) {
          try {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (e) {
            print('PlatformDefault failed: $e');
          }
        }

        if (launched) {
          _showSnackBar('Complete payment to activate subscription', isError: false);
        } else {
          _showSnackBar('Could not open payment page', isError: true);
        }
      } else {
        _showSnackBar(result.message ?? 'Subscribed successfully!', isError: false);
        _tabController.animateTo(1); // Switch to subscription tab
      }
    } else {
      _showSnackBar(result.message ?? 'Subscription failed', isError: true);
    }
  }

  Future<void> _toggleAutoRenew(VendorSubscriptionModel subscription) async {
    final success = await ref.read(subscriptionProvider.notifier).toggleAutoRenew();
    if (mounted) {
      _showSnackBar(
        success
            ? 'Auto-renew ${subscription.autoRenew ? 'disabled' : 'enabled'}'
            : 'Failed to update auto-renew',
        isError: !success,
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel auto-renewal? '
          'Your subscription will remain active until it expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(subscriptionProvider.notifier).cancelSubscription();
    if (mounted) {
      _showSnackBar(
        success ? 'Subscription cancelled' : 'Failed to cancel subscription',
        isError: !success,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }
}
