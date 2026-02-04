// lib/features/buyer/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedPaymentMethod = AppConstants.paymentCOD;
  bool _isPlacingOrder = false;
  bool _showAddAddressForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutProvider.notifier).loadCheckoutData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleAddAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final address = await ref.read(checkoutProvider.notifier).addAddress(
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      addressLine1: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: 'Uganda',
      isDefault: true,
    );

    if (address != null && mounted) {
      setState(() {
        _showAddAddressForm = false;
      });
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _cityController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address added successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handlePlaceOrder() async {
    final checkoutState = ref.read(checkoutProvider);

    if (checkoutState.selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // For mobile money, show phone number dialog first
    if (_selectedPaymentMethod == AppConstants.paymentMobileMoney) {
      final result = await _showMobileMoneyDialog();
      if (result == null) return; // User cancelled
      await _placeOrderWithPayment(
        paymentType: 'mobile_money',
        phoneNumber: result['phone'],
        mobileMoneyProvider: result['provider'],
      );
      return;
    }

    // For card payment
    if (_selectedPaymentMethod == AppConstants.paymentCard) {
      await _placeOrderWithPayment(paymentType: 'card');
      return;
    }

    // For COD, just place the order normally
    await _placeOrderCOD();
  }

  Future<Map<String, String>?> _showMobileMoneyDialog() async {
    String? selectedProvider;
    final phoneController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Mobile Money Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your provider:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedProvider = 'mtn'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedProvider == 'mtn'
                              ? Colors.yellow.shade100
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProvider == 'mtn'
                                ? Colors.yellow.shade700
                                : AppColors.border,
                            width: selectedProvider == 'mtn' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android,
                              color: Colors.yellow.shade700,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'MTN MoMo',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedProvider = 'airtel'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedProvider == 'airtel'
                              ? Colors.red.shade50
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProvider == 'airtel'
                                ? Colors.red
                                : AppColors.border,
                            width: selectedProvider == 'airtel' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Airtel Money',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '07XX XXX XXX',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedProvider != null && phoneController.text.isNotEmpty
                  ? () {
                      Navigator.pop(context, {
                        'provider': selectedProvider!,
                        'phone': phoneController.text.trim(),
                      });
                    }
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrderWithPayment({
    required String paymentType,
    String? phoneNumber,
    String? mobileMoneyProvider,
  }) async {
    setState(() {
      _isPlacingOrder = true;
    });

    // Set payment method and notes
    ref.read(checkoutProvider.notifier).selectPaymentMethod(_selectedPaymentMethod);
    ref.read(checkoutProvider.notifier).setNotes(_notesController.text.trim());

    // First place the order
    final order = await ref.read(checkoutProvider.notifier).placeOrder();

    if (order == null) {
      setState(() {
        _isPlacingOrder = false;
      });
      final error = ref.read(checkoutProvider).error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to place order'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Now initiate Pesapal payment
    final api = ref.read(apiClientProvider);
    final paymentResult = await initiatePesapalPayment(
      api,
      order.id,
      paymentType: paymentType,
      phoneNumber: phoneNumber,
      mobileMoneyProvider: mobileMoneyProvider,
    );

    setState(() {
      _isPlacingOrder = false;
    });

    if (!mounted) return;

    if (paymentResult['success'] == true && paymentResult['payment_url'] != null) {
      // Clear cart
      await ref.read(cartProvider.notifier).clearCart();

      // Navigate to payment webview
      context.push(
        '/payment/${order.id}',
        extra: {
          'paymentUrl': paymentResult['payment_url'],
          'orderNumber': order.orderNumber,
        },
      );
    } else {
      // Payment initialization failed, but order was placed
      // Clear cart and show message to retry payment from orders
      await ref.read(cartProvider.notifier).clearCart();

      _showPaymentPendingDialog(order.orderNumber, paymentResult['message']);
    }
  }

  void _showPaymentPendingDialog(String orderNumber, String? errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment, color: AppColors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Order Created',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Order #$orderNumber',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Payment could not be initiated. You can complete payment from your orders.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/orders');
                },
                child: const Text('View Orders'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrderCOD() async {
    setState(() {
      _isPlacingOrder = true;
    });

    // Set payment method and notes
    ref.read(checkoutProvider.notifier).selectPaymentMethod(_selectedPaymentMethod);
    ref.read(checkoutProvider.notifier).setNotes(_notesController.text.trim());

    final order = await ref.read(checkoutProvider.notifier).placeOrder();

    setState(() {
      _isPlacingOrder = false;
    });

    if (order != null && mounted) {
      // Clear cart
      await ref.read(cartProvider.notifier).clearCart();

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Order #${order.orderNumber}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${order.totalFormatted}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/orders');
                  },
                  child: const Text('View Orders'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/');
                },
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      );
    } else {
      final error = ref.read(checkoutProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to place order'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);

    if (cartState.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Start Shopping'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Address Section
            _buildSectionHeader('Delivery Address', Icons.location_on_outlined),
            const SizedBox(height: 12),
            
            if (checkoutState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_showAddAddressForm)
              _buildAddAddressForm()
            else if (checkoutState.addresses.isEmpty)
              _buildNoAddressCard()
            else
              _buildAddressSelection(checkoutState),

            const SizedBox(height: 24),

            // Payment Method Section
            _buildSectionHeader('Payment Method', Icons.payment_outlined),
            const SizedBox(height: 12),
            _buildPaymentMethods(),

            const SizedBox(height: 24),

            // Order Notes Section
            _buildSectionHeader('Order Notes (Optional)', Icons.note_outlined),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add any special instructions...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Order Summary Section
            _buildSectionHeader('Order Summary', Icons.receipt_outlined),
            const SizedBox(height: 12),
            _buildOrderSummary(cartState),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    cartState.formattedTotal,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _handlePlaceOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) return imagePath;
    final baseUrl = AppConstants.baseUrl;
    if (imagePath.startsWith('/')) return '$baseUrl$imagePath';
    return '$baseUrl/storage/$imagePath';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNoAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.add_location_alt_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No delivery address',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add an address to continue',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showAddAddressForm = true),
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelection(CheckoutState checkoutState) {
    return Column(
      children: [
        ...checkoutState.addresses.map((address) {
          final isSelected = checkoutState.selectedAddress?.id == address.id;
          return GestureDetector(
            onTap: () => ref.read(checkoutProvider.notifier).selectAddress(address),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.recipientName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address.recipientPhone,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${address.addressLine1}, ${address.city}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showAddAddressForm = true),
          icon: const Icon(Icons.add),
          label: const Text('Add New Address'),
        ),
      ],
    );
  }

  Widget _buildAddAddressForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Address',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showAddAddressForm = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Street Address',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleAddAddress,
                child: const Text('Save Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      {
        'value': AppConstants.paymentCOD,
        'title': 'Cash on Delivery',
        'subtitle': 'Pay when you receive',
        'icon': Icons.money_outlined,
      },
      {
        'value': AppConstants.paymentMobileMoney,
        'title': 'Mobile Money',
        'subtitle': 'MTN, Airtel Money',
        'icon': Icons.phone_android_outlined,
      },
      {
        'value': AppConstants.paymentCard,
        'title': 'Card Payment',
        'subtitle': 'Visa, Mastercard',
        'icon': Icons.credit_card_outlined,
      },
    ];

    return Column(
      children: methods.map((method) {
        final isSelected = _selectedPaymentMethod == method['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = method['value'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    method['icon'] as IconData,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        method['subtitle'] as String,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummary(CartState cartState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Cart Items
          ...cartState.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.thumbnail != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _buildImageUrl(item.thumbnail!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_outlined,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : const Icon(Icons.image_outlined, color: AppColors.textTertiary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.formattedPrice} × ${item.quantity}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.formattedTotal,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )).toList(),
          
          const Divider(height: 24),
          
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
              Text(cartState.formattedSubtotal, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          
          // Shipping
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shipping', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                cartState.shipping > 0 ? cartState.formattedShipping : 'Free',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: cartState.shipping > 0 ? AppColors.textPrimary : AppColors.success,
                ),
              ),
            ],
          ),
          
          const Divider(height: 24),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                cartState.formattedTotal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}