// lib/features/vendor/screens/vendor_notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/providers/notification_provider.dart';

class VendorNotificationsScreen extends ConsumerStatefulWidget {
  const VendorNotificationsScreen({super.key});

  @override
  ConsumerState<VendorNotificationsScreen> createState() => _VendorNotificationsScreenState();
}

class _VendorNotificationsScreenState extends ConsumerState<VendorNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationPreferencesProvider.notifier).loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Order Notifications
          _buildSectionHeader('Order Notifications'),
          _buildSwitchTile(
            icon: Icons.shopping_bag_outlined,
            title: 'New Orders',
            subtitle: 'Get notified when you receive new orders',
            value: prefs?.newOrders ?? true,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('new_orders', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.star_outline,
            title: 'Reviews',
            subtitle: 'Get notified when customers leave reviews',
            value: prefs?.reviews ?? true,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('reviews', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.payments_outlined,
            title: 'Payouts',
            subtitle: 'Get notified about payout status',
            value: prefs?.payouts ?? true,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('payouts', value);
            },
          ),
          const SizedBox(height: 16),

          // Marketing
          _buildSectionHeader('Marketing'),
          _buildSwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Promotions & Tips',
            subtitle: 'Get tips to improve your sales',
            value: prefs?.vendorTips ?? false,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('vendor_tips', value);
            },
          ),
          const SizedBox(height: 16),

          // Channels
          _buildSectionHeader('Notification Channels'),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: prefs?.emailEnabled ?? true,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('email_enabled', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            value: prefs?.pushEnabled ?? true,
            onChanged: (value) {
              ref.read(notificationPreferencesProvider.notifier)
                  .updateField('push_enabled', value);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
        ),
      ),
    );
  }
}
