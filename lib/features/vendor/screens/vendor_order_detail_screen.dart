// lib/features/vendor/screens/vendor_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/vendor_provider.dart';
import '../../chat/providers/chat_provider.dart';

class VendorOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends ConsumerState<VendorOrderDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    final result = await ref.read(vendorOrdersProvider.notifier).updateOrderStatus(
          widget.orderId,
          newStatus,
        );

    setState(() => _isUpdating = false);

    if (mounted) {
      // Check if COD payment confirmation is required
      if (result['requires_payment_confirmation'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('For COD orders, please use "Confirm Payment Received"'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] ? 'Status updated to $newStatus' : (result['message'] ?? 'Failed to update status')),
            backgroundColor: result['success'] ? AppColors.success : AppColors.error,
          ),
        );
        if (result['success']) {
          ref.invalidate(vendorOrderDetailProvider(widget.orderId));
        }
      }
    }
  }

  Future<void> _confirmCodPayment() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment Received'),
        content: const Text(
          'Please confirm that you have received the cash payment from the customer.\n\n'
          'This will mark the order as delivered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Payment Received'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);

    final result = await ref.read(vendorOrdersProvider.notifier).confirmCodPayment(widget.orderId);

    setState(() => _isUpdating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? (result['success'] ? 'Payment confirmed!' : 'Failed to confirm payment')),
          backgroundColor: result['success'] ? AppColors.success : AppColors.error,
        ),
      );
      if (result['success']) {
        ref.invalidate(vendorOrderDetailProvider(widget.orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(vendorOrderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              // TODO: Print packing slip
            },
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load order', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(vendorOrderDetailProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return _buildOrderDetails(order);
        },
      ),
    );
  }

  Widget _buildOrderDetails(VendorOrderModel order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header Card
          _buildHeaderCard(order),
          const SizedBox(height: 16),

          // Status Timeline
          _buildStatusTimeline(order),
          const SizedBox(height: 16),

          // Customer Info
          _buildCustomerCard(order, order.buyer),
          const SizedBox(height: 16),

          // Shipping Address
          if (order.shippingAddress != null) _buildShippingCard(order.shippingAddress!),
          const SizedBox(height: 16),

          // Order Items
          _buildItemsCard(order),
          const SizedBox(height: 16),

          // Order Summary
          _buildSummaryCard(order),
          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(order),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(VendorOrderModel order) {
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${_truncateOrderNumber(order.orderNumber)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM dd, yyyy • hh:mm a').format(order.createdAt),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.payment_outlined,
                  label: 'Payment',
                  value: order.paymentStatus ?? 'Pending',
                  color: order.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Method',
                  value: order.paymentMethod ?? 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'shipped':
        color = Colors.purple;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(VendorOrderModel order) {
    final statuses = ['pending', 'processing', 'shipped', 'delivered'];
    final currentIndex = statuses.indexOf(order.status.toLowerCase());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(statuses.length, (index) {
              final isCompleted = index <= currentIndex;
              final isCurrent = index == currentIndex;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: index <= currentIndex
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                            border: isCurrent
                                ? Border.all(color: AppColors.primary, width: 3)
                                : null,
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                        if (index < statuses.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: index < currentIndex
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statuses[index].capitalize(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(VendorOrderModel order, dynamic buyer) {
    if (buyer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyer.name ?? 'Customer',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (buyer.email != null)
                      Text(buyer.email!, style: TextStyle(color: AppColors.textSecondary)),
                    if (buyer.phone != null)
                      Text(buyer.phone!, style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (buyer.phone != null) {
                      final uri = Uri.parse('tel:${buyer.phone}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  },
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Call', overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openMessageDialog(order, buyer),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Message', overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingCard(ShippingInfo address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Shipping Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (address.fullName != null)
            Text(address.fullName!, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            address.fullAddress,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (address.phone != null) ...[
            const SizedBox(height: 4),
            Text(address.phone!, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(VendorOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) => _buildOrderItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _buildImageUrl(item.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : Icon(Icons.image_outlined, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variant != null)
                  Text(
                    item.variant!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  'UGX ${item.price.toStringAsFixed(0)} × ${item.quantity}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          // Item Total
          Text(
            'UGX ${item.total.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(VendorOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', 'UGX ${order.subtotal.toStringAsFixed(0)}'),
          _buildSummaryRow('Shipping', 'UGX ${order.shippingCost.toStringAsFixed(0)}'),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total',
            'UGX ${order.total.toStringAsFixed(0)}',
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 18 : 14,
              color: isLarge ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(VendorOrderModel order) {
    final status = order.status.toLowerCase();
    final isCOD = order.paymentMethod?.toLowerCase() == 'cash_on_delivery' ||
                  order.paymentMethod?.toLowerCase() == 'cod' ||
                  order.paymentMethod?.toLowerCase() == 'cash';

    if (status == 'delivered' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

    String buttonText;
    String nextStatus;
    Color buttonColor;
    bool useCodConfirmation = false;

    switch (status) {
      case 'pending':
        buttonText = 'Accept Order';
        nextStatus = 'processing';
        buttonColor = Colors.blue;
        break;
      case 'processing':
        buttonText = 'Mark as Shipped';
        nextStatus = 'shipped';
        buttonColor = Colors.purple;
        break;
      case 'shipped':
        // For COD orders, show "Confirm Payment Received" instead
        if (isCOD) {
          buttonText = 'Confirm Payment Received';
          nextStatus = 'delivered';
          buttonColor = Colors.green;
          useCodConfirmation = true;
        } else {
          buttonText = 'Mark as Delivered';
          nextStatus = 'delivered';
          buttonColor = Colors.green;
        }
        break;
      default:
        return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Show COD indicator for shipped COD orders
        if (status == 'shipped' && isCOD) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash on Delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        'Collect UGX ${order.total.toStringAsFixed(0)} from customer',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isUpdating
                ? null
                : (useCodConfirmation ? _confirmCodPayment : () => _updateStatus(nextStatus)),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(useCodConfirmation ? Icons.payments : Icons.check_circle_outline),
            label: Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isUpdating ? null : () => _showCancelConfirmation(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Decline Order', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Order'),
        content: const Text('Are you sure you want to decline this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('cancelled');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Decline'),
          ),
        ],
      ),
    );
  }

  void _openMessageDialog(VendorOrderModel order, dynamic buyer) {
    // Pre-fill message with order details
    final orderItems = order.items.map((item) => '- ${item.title} x${item.quantity}').join('\n');
    final defaultMessage = '''Hi ${buyer?.name ?? "Customer"},

Regarding your order #${order.orderNumber}:
$orderItems

Total: UGX ${order.total.toStringAsFixed(0)}

''';

    final messageController = TextEditingController(text: defaultMessage);
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Send Message',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'To: ${buyer?.name ?? "Customer"} ${buyer?.phone != null ? "(${buyer.phone})" : ""}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // SMS Button
                  if (buyer?.phone != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSending ? null : () async {
                          final message = messageController.text.trim();
                          Navigator.pop(dialogContext);

                          final encodedMessage = Uri.encodeComponent(message);
                          final smsUri = Uri.parse('sms:${buyer.phone}?body=$encodedMessage');
                          if (await canLaunchUrl(smsUri)) {
                            await launchUrl(smsUri);
                          }
                        },
                        icon: const Icon(Icons.sms_outlined),
                        label: const Text('SMS'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (buyer?.phone != null) const SizedBox(width: 12),
                  // In-App Chat Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSending ? null : () async {
                        final message = messageController.text.trim();
                        if (message.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a message')),
                          );
                          return;
                        }

                        // Get buyer ID from order - use buyerId field directly
                        final buyerId = order.buyerId;
                        if (buyerId == 0) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to find buyer information'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSending = true);

                        // Start conversation with buyer
                        final conversationId = await ref
                            .read(conversationsProvider.notifier)
                            .startConversationWithBuyer(
                              buyerId: buyerId,
                              initialMessage: message,
                              subject: 'Order #${_truncateOrderNumber(order.orderNumber)}',
                            );

                        if (!mounted) return;
                        Navigator.pop(dialogContext);

                        if (conversationId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message sent!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Navigate to chat
                          context.push('/chat/$conversationId');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to send message'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(isSending ? 'Sending...' : 'In-App Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) return imagePath;
    final baseUrl = AppConstants.baseUrl.replaceAll('/api', '');
    if (imagePath.startsWith('/')) return '$baseUrl$imagePath';
    return '$baseUrl/storage/$imagePath';
  }

  String _truncateOrderNumber(String orderNumber) {
    if (orderNumber.length > 16) {
      return '${orderNumber.substring(0, 6)}...${orderNumber.substring(orderNumber.length - 6)}';
    }
    return orderNumber;
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}