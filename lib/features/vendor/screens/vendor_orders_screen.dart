// lib/features/vendor/screens/vendor_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/vendor_provider.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = ['all', 'pending', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load orders when screen initializes
    Future.microtask(() => _loadOrders());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadOrders();
    }
  }

  void _loadOrders() {
    final status = _statusFilters[_tabController.index];
    ref.read(vendorOrdersProvider.notifier).loadOrders(
          status: status,
          refresh: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(vendorOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Shipped'),
            Tab(text: 'Delivered'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadOrders(),
        child: ordersState.isLoading && ordersState.orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ordersState.error != null && ordersState.orders.isEmpty
                ? _buildErrorState(ordersState.error!)
                : ordersState.orders.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersList(ordersState.orders),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final currentTab = _statusFilters[_tabController.index];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            currentTab == 'all' ? 'No orders yet' : 'No ${currentTab} orders',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders from buyers will appear here',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<VendorOrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderCard(
          order: orders[index],
          onTap: () => context.push('/vendor/orders/${orders[index].id}'),
          onUpdateStatus: (newStatus) => _updateOrderStatus(orders[index].id, newStatus),
        );
      },
    );
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    final result = await ref.read(vendorOrdersProvider.notifier).updateOrderStatus(orderId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? 'Order status updated' : (result['message'] ?? 'Failed to update status')),
          backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
        ),
      );
    }
  }
}

class _OrderCard extends StatelessWidget {
  final VendorOrderModel order;
  final VoidCallback onTap;
  final Function(String) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer Info
                if (order.buyer != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.buyer!.name ?? 'Customer',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              if (order.buyer!.phone != null)
                                Text(
                                  order.buyer!.phone!,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (order.buyer!.phone != null)
                          IconButton(
                            icon: const Icon(Icons.phone_outlined),
                            onPressed: () async {
                              final phone = order.buyer!.phone!;
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Order Items Summary
                if (order.items.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.take(2).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantity}x',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.title ?? 'Product',
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (order.items.length > 2)
                        Text(
                          '+${order.items.length - 2} more items',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),

                const Divider(height: 24),

                // Footer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(
                          'UGX ${order.total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    _buildActionButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    // Show different action buttons based on current status
    switch (order.status.toLowerCase()) {
      case 'pending':
        return ElevatedButton(
          onPressed: () => onUpdateStatus('processing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Accept Order'),
        );
      case 'processing':
        return ElevatedButton(
          onPressed: () => onUpdateStatus('shipped'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Mark Shipped'),
        );
      case 'shipped':
        return ElevatedButton(
          onPressed: () => onUpdateStatus('delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Mark Delivered'),
        );
      default:
        return OutlinedButton(
          onPressed: () {},
          child: const Text('View Details'),
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor().withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: _getColor()),
          const SizedBox(width: 4),
          Text(
            _getLabel(),
            style: TextStyle(
              color: _getColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
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

  IconData _getIcon() {
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
        return Icons.help_outline;
    }
  }

  String _getLabel() {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}