// lib/features/vendor/screens/vendor_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vendor_provider.dart';
import 'onboarding_form_screen.dart';

class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends ConsumerState<VendorOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vendorOnboardingProvider.notifier).checkStatus());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorOnboardingProvider);

    return state.isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : (state.success || state.currentProfile != null)
            ? Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  title: const Text('Application Status'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () {
                        ref.read(authStateProvider.notifier).logout();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
                body: _buildStatusContent(
                  state.currentProfile?.vettingStatus ?? 'pending', 
                  state.currentProfile
                ),
              )
            : const OnboardingFormScreen();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Failed to load status'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(vendorProfileProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(String status, VendorProfileModel? profile) {
    switch (status.toLowerCase()) {
      case 'approved':
        // Vendor is approved, redirect to dashboard
        Future.microtask(() => context.go('/vendor'));
        return const Center(child: CircularProgressIndicator());

      case 'rejected':
        return _buildRejectedStatus(profile);

      case 'pending':
      default:
        return _buildPendingStatus(profile);
    }
  }

  Widget _buildPendingStatus(VendorProfileModel? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Animated Icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule,
                    size: 60,
                    color: Colors.orange,
                  ),
                ),
              );
            },
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
            'Your vendor application is being reviewed by our team. This usually takes 1-2 business days.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Status Steps
          _buildStatusSteps(),
          const SizedBox(height: 40),

          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text(
                      'What happens next?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Our team will verify your business documents\n'
                  '• You\'ll receive an email notification once approved\n'
                  '• After approval, you can start listing products',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Refresh Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(vendorProfileProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Browse as Buyer
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Browse as Buyer'),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedStatus(VendorProfileModel? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              size: 60,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Application Rejected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Unfortunately, your vendor application was not approved. Please review the feedback below and consider reapplying.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Rejection Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text(
                      'Common reasons for rejection:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Incomplete business information\n'
                  '• Invalid or unclear documents\n'
                  '• Business type not supported\n'
                  '• Missing required certifications',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Contact Support Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Open support chat or email
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
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

          // Browse as Buyer
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Continue as Buyer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSteps() {
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
        children: [
          _buildStep(
            number: 1,
            title: 'Application Submitted',
            subtitle: 'Your application has been received',
            isCompleted: true,
          ),
          _buildStepConnector(),
          _buildStep(
            number: 2,
            title: 'Under Review',
            subtitle: 'Our team is reviewing your documents',
            isActive: true,
          ),
          _buildStepConnector(isActive: false),
          _buildStep(
            number: 3,
            title: 'Approval',
            subtitle: 'Start selling on BebaMart',
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String subtitle,
    bool isCompleted = false,
    bool isActive = false,
  }) {
    Color circleColor;
    Widget circleContent;

    if (isCompleted) {
      circleColor = Colors.green;
      circleContent = const Icon(Icons.check, color: Colors.white, size: 20);
    } else if (isActive) {
      circleColor = Colors.orange;
      circleContent = Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
    } else {
      circleColor = Colors.grey.shade300;
      circleContent = Text('$number', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold));
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: circleContent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive || isCompleted ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive || isCompleted ? AppColors.textSecondary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({bool isActive = true}) {
    return Container(
      margin: const EdgeInsets.only(left: 19),
      width: 2,
      height: 30,
      color: isActive ? Colors.green : Colors.grey.shade300,
    );
  }
}