// lib/features/buyer/screens/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=Support Request - BebaMart App',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: AppConstants.supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact Us Section
          _buildSectionHeader('Contact Us'),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: AppConstants.supportEmail,
            onTap: _launchEmail,
          ),
          _buildContactCard(
            icon: Icons.phone_outlined,
            title: 'Call Us',
            subtitle: AppConstants.supportPhone,
            onTap: _launchPhone,
          ),
          _buildContactCard(
            icon: Icons.chat_outlined,
            title: 'Live Chat',
            subtitle: 'Chat with our support team',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live chat coming soon')),
              );
            },
          ),
          const SizedBox(height: 24),

          // FAQ Section
          _buildSectionHeader('Frequently Asked Questions'),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'How do I track my order?',
            'You can track your order by going to "Orders" in the bottom navigation, then tap on the order you want to track. You\'ll see the current status and delivery timeline.',
          ),
          _buildFAQItem(
            context,
            'How do I return a product?',
            'To return a product, go to your order details and tap "Request Return". Make sure to do this within 7 days of delivery. Our support team will guide you through the process.',
          ),
          _buildFAQItem(
            context,
            'What payment methods are accepted?',
            'We accept Mobile Money (MTN, Airtel), bank transfers, and Cash on Delivery for selected areas.',
          ),
          _buildFAQItem(
            context,
            'How do I become a vendor?',
            'To become a vendor, go to Settings and tap "Become a Vendor". You\'ll need to provide your business details and go through our verification process.',
          ),
          _buildFAQItem(
            context,
            'How is my wallet balance used?',
            'Your wallet balance can be used to pay for orders. You can add funds to your wallet or receive refunds directly to it.',
          ),
          const SizedBox(height: 24),

          // Quick Links Section
          _buildSectionHeader('Quick Links'),
          const SizedBox(height: 12),
          _buildQuickLinkCard(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _launchUrl('https://bebamart.com/terms'),
          ),
          _buildQuickLinkCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchUrl('https://bebamart.com/privacy'),
          ),
          _buildQuickLinkCard(
            icon: Icons.assignment_return_outlined,
            title: 'Return Policy',
            onTap: () => _launchUrl('https://bebamart.com/returns'),
          ),
          const SizedBox(height: 24),

          // App Info
          Center(
            child: Column(
              children: [
                Text(
                  'BebaMart v${AppConstants.appVersion}',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Made with love in Uganda',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: onTap,
      ),
    );
  }
}
