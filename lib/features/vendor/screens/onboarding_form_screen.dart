import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/vendor_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class OnboardingFormScreen extends ConsumerStatefulWidget {
  const OnboardingFormScreen({super.key});

  @override
  ConsumerState<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends ConsumerState<OnboardingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _businessNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _guarantorNameController = TextEditingController();
  final _guarantorPhoneController = TextEditingController();
  final _annualTurnoverController = TextEditingController();

  // State
  String _vendorType = 'local_retail';
  String _country = 'Uganda';
  String _currency = 'UGX';
  bool _agreedToTerms = false;
  
  File? _idFront;
  File? _idBack;
  File? _bankStatement;
  File? _proofOfAddress;
  File? _guarantorId;
  File? _compReg;
  File? _taxCert;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _businessNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _guarantorNameController.dispose();
    _guarantorPhoneController.dispose();
    _annualTurnoverController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          switch (type) {
            case 'id_front': _idFront = File(image.path); break;
            case 'id_back': _idBack = File(image.path); break;
            case 'bank': _bankStatement = File(image.path); break;
            case 'address': _proofOfAddress = File(image.path); break;
            case 'guarantor': _guarantorId = File(image.path); break;
            case 'comp_reg': _compReg = File(image.path); break;
            case 'tax': _taxCert = File(image.path); break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idFront == null || _idBack == null || _bankStatement == null || _proofOfAddress == null || _guarantorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all required verification documents'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show uploading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Uploading documents...'),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    final success = await ref.read(vendorOnboardingProvider.notifier).submitOnboarding(
      vendorType: _vendorType,
      businessName: _businessNameController.text,
      country: _country,
      city: _cityController.text,
      address: _addressController.text,
      preferredCurrency: _currency,
      annualTurnover: double.tryParse(_annualTurnoverController.text),
      nationalIdFront: _idFront!,
      nationalIdBack: _idBack!,
      bankStatement: _bankStatement!,
      proofOfAddress: _proofOfAddress!,
      guarantorName: _guarantorNameController.text,
      guarantorPhone: _guarantorPhoneController.text,
      guarantorId: _guarantorId!,
      companyRegistration: _compReg,
      taxCertificate: _taxCert,
    );

    // Close the loading dialog
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // No need to navigate, the parent VendorOnboardingScreen
      // watches the state and will switch to the status view automatically.
    } else if (mounted) {
      final error = ref.read(vendorOnboardingProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to submit application'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildDocPicker(String label, File? file, String type, {bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(type),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: file != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 12,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => setState(() {
                              switch (type) {
                                case 'id_front': _idFront = null; break;
                                case 'id_back': _idBack = null; break;
                                case 'bank': _bankStatement = null; break;
                                case 'address': _proofOfAddress = null; break;
                                case 'guarantor': _guarantorId = null; break;
                                case 'comp_reg': _compReg = null; break;
                                case 'tax': _taxCert = null; break;
                              }
                            }),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 32),
                      const SizedBox(height: 8),
                      Text('Select File', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorOnboardingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Application'),
        elevation: 0,
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification Documents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please upload clear photos of the following documents to verify your business.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Business Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _vendorType,
                            decoration: const InputDecoration(labelText: 'Vendor Type'),
                            items: const [
                              DropdownMenuItem(value: 'local_retail', child: Text('Local Retailer')),
                              DropdownMenuItem(value: 'china_supplier', child: Text('Importer / International')),
                              DropdownMenuItem(value: 'dropship', child: Text('Dropshipper')),
                            ],
                            onChanged: (v) => setState(() => _vendorType = v!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _businessNameController,
                            decoration: const InputDecoration(
                              labelText: 'Business Name',
                              hintText: 'As it appears on your documents',
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _country,
                                  decoration: const InputDecoration(labelText: 'Country'),
                                  readOnly: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(labelText: 'City'),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _currency,
                                  decoration: const InputDecoration(labelText: 'Currency'),
                                  items: const [
                                    DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    DropdownMenuItem(value: 'KES', child: Text('KES')),
                                  ],
                                  onChanged: (v) => setState(() => _currency = v!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _annualTurnoverController,
                                  decoration: InputDecoration(
                                    labelText: 'Annual Turnover (Optional)',
                                    prefixText: '$_currency ',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Business Address',
                              hintText: 'Plot number, Street, etc.',
                            ),
                            maxLines: 2,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Required Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  _buildDocPicker('National ID (Front Side)', _idFront, 'id_front'),
                  _buildDocPicker('National ID (Back Side)', _idBack, 'id_back'),
                  _buildDocPicker('Bank Statement (Last 3 Months)', _bankStatement, 'bank'),
                  _buildDocPicker('Proof of Address (Utility bill/rental)', _proofOfAddress, 'address'),
                  
                  const SizedBox(height: 24),
                  const Text('Guarantor Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _guarantorNameController,
                            decoration: const InputDecoration(labelText: 'Guarantor Full Name'),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _guarantorPhoneController,
                            decoration: const InputDecoration(labelText: 'Guarantor Phone Number'),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildDocPicker('Guarantor ID (Front Side)', _guarantorId, 'guarantor'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Company Documents (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildDocPicker('Registration Certificate', _compReg, 'comp_reg', required: false),
                  _buildDocPicker('Tax Certificate', _taxCert, 'tax', required: false),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms and Conditions and verify that all provided information is accurate.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}
