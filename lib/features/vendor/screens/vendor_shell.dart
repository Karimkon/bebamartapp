// lib/features/vendor/screens/vendor_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VendorShell extends ConsumerWidget {
  final Widget child;
  const VendorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(body: child, bottomNavigationBar: const VendorBottomNav());
  }
}

class VendorBottomNav extends StatelessWidget {
  const VendorBottomNav({super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/vendor') return 0;
    if (location == '/vendor/products') return 1;
    if (location == '/vendor/orders') return 2;
    if (location == '/vendor/profile') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0: context.go('/vendor'); break;
          case 1: context.go('/vendor/products'); break;
          case 2: context.go('/vendor/orders'); break;
          case 3: context.go('/vendor/profile'); break;
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
        NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Store'),
      ],
    );
  }
}
