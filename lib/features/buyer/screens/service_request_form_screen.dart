// lib/features/buyer/screens/service_request_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_request_provider.dart';
import '../../../shared/models/service_model.dart';

class ServiceRequestFormScreen extends ConsumerStatefulWidget {
  final int serviceId;
  final VendorServiceModel service;

  const ServiceRequestFormScreen({
    super.key,
    required this.serviceId,
    required this.service,
  });

  @override
  ConsumerState<ServiceRequestFormScreen> createState() => _ServiceRequestFormScreenState();
}

class _ServiceRequestFormScreenState extends ConsumerState<ServiceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  String _urgency = 'normal';
  DateTime? _preferredDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Pre-fill location if available
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push('/login');
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      'vendor_service_id': widget.serviceId,
      'description': _descController.text.trim(),
      'customer_name': user.name,
      'customer_phone': user.phone.isNotEmpty ? user.phone : 'Not provided',
      'customer_email': user.email,
      'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      'urgency': _urgency,
      if (_preferredDate != null)
        'preferred_date': '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}',
      if (_budgetMinController.text.isNotEmpty)
        'budget_min': double.tryParse(_budgetMinController.text),
      if (_budgetMaxController.text.isNotEmpty)
        'budget_max': double.tryParse(_budgetMaxController.text),
    };

    final result = await ref.read(buyerServiceRequestsProvider.notifier).submitRequest(data);
    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (result['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Request Submitted'),
          content: const Text(
            'Your service request has been sent to the professional. They will review it and send you a quote.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Service', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service info header
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.work_outline, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.service.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              'By ${widget.service.vendor.businessName}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Describe your needs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Explain what you need in detail...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please describe what you need' : null,
              ),
              const SizedBox(height: 20),

              const Text('Location (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Kampala, Kololo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              const Text('Preferred Date (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        _preferredDate != null
                            ? '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}'
                            : 'Select a date',
                        style: TextStyle(
                          color: _preferredDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (_preferredDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _preferredDate = null),
                          child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Urgency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _UrgencyChip(
                    label: 'Normal',
                    value: 'normal',
                    selected: _urgency == 'normal',
                    color: Colors.green,
                    onTap: () => setState(() => _urgency = 'normal'),
                  ),
                  const SizedBox(width: 8),
                  _UrgencyChip(
                    label: 'Urgent',
                    value: 'urgent',
                    selected: _urgency == 'urgent',
                    color: Colors.orange,
                    onTap: () => setState(() => _urgency = 'urgent'),
                  ),
                  const SizedBox(width: 8),
                  _UrgencyChip(
                    label: 'Emergency',
                    value: 'emergency',
                    selected: _urgency == 'emergency',
                    color: Colors.red,
                    onTap: () => setState(() => _urgency = 'emergency'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Budget Range (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min (UGX)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max (UGX)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Request', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _UrgencyChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white,
          border: Border.all(color: selected ? color : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
