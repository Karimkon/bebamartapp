// lib/features/vendor/screens/vendor_service_request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/service_request_provider.dart';

class VendorServiceRequestDetailScreen extends ConsumerStatefulWidget {
  final int requestId;
  const VendorServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<VendorServiceRequestDetailScreen> createState() =>
      _VendorServiceRequestDetailScreenState();
}

class _VendorServiceRequestDetailScreenState
    extends ConsumerState<VendorServiceRequestDetailScreen> {
  final _quoteController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _showQuoteForm = false;

  @override
  void dispose() {
    _quoteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'quoted': return Colors.blue;
      case 'accepted': return Colors.teal;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _submitQuote() async {
    final price = double.tryParse(_quoteController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(vendorServiceRequestsProvider.notifier).submitQuote(
          widget.requestId,
          price,
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
        ),
      );
      if (result['success'] == true) {
        ref.invalidate(vendorServiceRequestDetailProvider(widget.requestId));
        setState(() => _showQuoteForm = false);
      }
    }
  }

  Future<void> _updateStatus(String status, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label?'),
        content: Text('Are you sure you want to mark this request as "$label"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(vendorServiceRequestsProvider.notifier)
        .updateStatus(widget.requestId, status);
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
        ),
      );
      if (result['success'] == true) {
        ref.invalidate(vendorServiceRequestDetailProvider(widget.requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(vendorServiceRequestDetailProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (request) {
          if (request == null) return const Center(child: Text('Request not found'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status header
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.requestNumber,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(request.service?.title ?? 'Service Request',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusColor(request.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusColor(request.status).withOpacity(0.4)),
                          ),
                          child: Text(
                            request.statusLabel,
                            style: TextStyle(
                              color: _statusColor(request.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Customer info
                _Section(
                  title: 'Customer',
                  children: [
                    _InfoRow(Icons.person_outline, 'Name', request.customerName),
                    _InfoRow(Icons.phone_outlined, 'Phone', request.customerPhone),
                    if (request.customerEmail != null)
                      _InfoRow(Icons.email_outlined, 'Email', request.customerEmail!),
                  ],
                ),
                const SizedBox(height: 12),

                // Request details
                _Section(
                  title: 'Request Details',
                  children: [
                    _InfoRow(Icons.description_outlined, 'Description', request.description),
                    if (request.location != null)
                      _InfoRow(Icons.location_on_outlined, 'Location', request.location!),
                    if (request.preferredDate != null)
                      _InfoRow(Icons.calendar_today_outlined, 'Preferred Date', request.preferredDate!),
                    if (request.preferredTime != null)
                      _InfoRow(Icons.access_time, 'Preferred Time', request.preferredTime!),
                    _InfoRow(Icons.priority_high, 'Urgency', request.urgency.toUpperCase()),
                    if (request.budgetMin != null || request.budgetMax != null)
                      _InfoRow(
                        Icons.attach_money,
                        'Budget',
                        'UGX ${request.budgetMin?.toStringAsFixed(0) ?? '0'} - ${request.budgetMax?.toStringAsFixed(0) ?? 'Open'}',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quote info
                if (request.quotedPrice != null) ...[
                  _Section(
                    title: 'Your Quote',
                    children: [
                      _InfoRow(
                        Icons.attach_money,
                        'Quoted Price',
                        'UGX ${request.quotedPrice!.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Quote form
                if (_showQuoteForm && request.status == 'pending') ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Submit Quote',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _quoteController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quoted Price (UGX)',
                              prefixIcon: Icon(Icons.attach_money),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'Any additional information for the buyer...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _showQuoteForm = false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitQuote,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Submit Quote'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                if (!_showQuoteForm) ...[
                  if (request.status == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _showQuoteForm = true),
                        icon: const Icon(Icons.attach_money),
                        label: const Text('Submit Quote'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (request.status == 'accepted') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _updateStatus('in_progress', 'In Progress'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Mark as In Progress'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (request.status == 'in_progress') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _updateStatus('completed', 'Completed'),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (request.status == 'pending' ||
                      request.status == 'quoted' ||
                      request.status == 'accepted' ||
                      request.status == 'in_progress') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _updateStatus('cancelled', 'Cancelled'),
                        icon: Icon(Icons.cancel_outlined, color: AppColors.error),
                        label: Text('Cancel Request', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
