// lib/features/vendor/screens/vendor_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class VendorOnboardingScreen extends ConsumerWidget {
  const VendorOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: const Center(child: Text('Vendor Onboarding - Coming Soon')),
    );
  }
}
