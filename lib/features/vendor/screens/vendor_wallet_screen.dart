// lib/features/vendor/screens/vendor_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class VendorWalletScreen extends ConsumerStatefulWidget {
  const VendorWalletScreen({super.key});

  @override
  ConsumerState<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends ConsumerState<VendorWalletScreen> {
  double _balance = 0;
  double _pendingBalance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _error;

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      // Load vendor wallet balance
      final balanceResponse = await api.get(ApiEndpoints.vendorWallet);
      if (balanceResponse.statusCode == 200 && balanceResponse.data['success'] == true) {
        final data = balanceResponse.data['data'] ?? {};
        _balance = _parseDouble(data['available_balance'] ?? data['balance']);
        _pendingBalance = _parseDouble(data['pending_balance']);
      }

      // Load transactions
      final txResponse = await api.get(ApiEndpoints.vendorTransactions);
      if (txResponse.statusCode == 200 && txResponse.data['success'] == true) {
        final data = txResponse.data['data'] as List? ?? [];
        _transactions = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return 'UGX ${formatter.format(amount.toInt())}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet & Payouts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadWallet, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWallet,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Balance Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildBalanceCard(
                              'Available Balance',
                              _balance,
                              AppColors.success,
                              Icons.account_balance_wallet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBalanceCard(
                              'Pending',
                              _pendingBalance,
                              AppColors.warning,
                              Icons.schedule,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Request Payout Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _balance > 0 ? _showPayoutDialog : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Request Payout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Transactions Header
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Transactions List
                      if (_transactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: const Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textTertiary),
                              SizedBox(height: 16),
                              Text(
                                'No transactions yet',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your sales earnings will appear here',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._transactions.map((tx) {
                          final isCredit = tx['type'] == 'credit' || tx['type'] == 'sale';
                          final amount = _parseDouble(tx['amount']);
                          final status = tx['status'] ?? 'completed';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isCredit
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isCredit ? AppColors.success : AppColors.primary,
                                ),
                              ),
                              title: Text(
                                tx['description'] ?? _getTransactionTitle(tx['type']),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    _formatDate(tx['created_at']),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (status == 'pending') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Pending',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Text(
                                '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? AppColors.success : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getTransactionTitle(String? type) {
    switch (type) {
      case 'sale':
        return 'Product Sale';
      case 'payout':
        return 'Payout';
      case 'refund':
        return 'Refund';
      case 'commission':
        return 'Platform Commission';
      default:
        return 'Transaction';
    }
  }

  void _showPayoutDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available: ${_formatCurrency(_balance)}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (UGX)',
                  border: OutlineInputBorder(),
                  prefixText: 'UGX ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) return 'Invalid amount';
                  if (amount > _balance) return 'Insufficient balance';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payout request submitted'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}
