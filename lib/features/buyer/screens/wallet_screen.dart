// lib/features/buyer/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  double _balance = 0;
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

      // Load balance
      final balanceResponse = await api.get(ApiEndpoints.wallet);
      if (balanceResponse.statusCode == 200 && balanceResponse.data['success'] == true) {
        _balance = _parseDouble(balanceResponse.data['data']['balance']);
      }

      // Load transactions
      final txResponse = await api.get(ApiEndpoints.walletTransactions);
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
        title: const Text('My Wallet'),
        backgroundColor: AppColors.white,
        elevation: 0,
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
                      // Balance Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF1E3A5F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.white70),
                                SizedBox(width: 8),
                                Text(
                                  'Available Balance',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatCurrency(_balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Deposit feature coming soon')),
                                      );
                                    },
                                    icon: const Icon(Icons.add, color: Colors.white),
                                    label: const Text('Add Funds', style: TextStyle(color: Colors.white)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white30),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Withdraw feature coming soon')),
                                      );
                                    },
                                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                    label: const Text('Withdraw', style: TextStyle(color: Colors.white)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white30),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Transactions Header
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaction History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
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
                            ],
                          ),
                        )
                      else
                        ..._transactions.map((tx) {
                          final isCredit = tx['type'] == 'credit' || tx['type'] == 'deposit';
                          final amount = _parseDouble(tx['amount']);

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
                                      : AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isCredit ? AppColors.success : AppColors.error,
                                ),
                              ),
                              title: Text(
                                tx['description'] ?? tx['type'] ?? 'Transaction',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                _formatDate(tx['created_at']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? AppColors.success : AppColors.error,
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
}
