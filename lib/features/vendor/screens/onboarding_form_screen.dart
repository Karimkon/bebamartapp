import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // China verification controllers
  final _chinaCompanyNameController = TextEditingController();
  final _usccController = TextEditingController();
  final _legalRepController = TextEditingController();
  final _businessScopeController = TextEditingController();
  final _chinaAddressController = TextEditingController();
  final _registeredCapitalController = TextEditingController();

  // State
  String _vendorType = 'local_retail';
  String _country = 'Uganda';
  String _currency = 'UGX';
  bool _agreedToTerms = false;

  // Existing doc files
  File? _idFront;
  File? _idBack;
  File? _bankStatement;
  File? _proofOfAddress;
  File? _guarantorId;
  File? _compReg;
  File? _taxCert;

  // China doc files
  File? _businessLicense;
  List<File> _industryPermits = [];

  bool get _isChinaSupplier => _vendorType == 'china_supplier';

  final _picker = ImagePicker();

  @override
  void dispose() {
    _businessNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _guarantorNameController.dispose();
    _guarantorPhoneController.dispose();
    _annualTurnoverController.dispose();
    _chinaCompanyNameController.dispose();
    _usccController.dispose();
    _legalRepController.dispose();
    _businessScopeController.dispose();
    _chinaAddressController.dispose();
    _registeredCapitalController.dispose();
    super.dispose();
  }

  void _onVendorTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _vendorType = type;
      if (_isChinaSupplier) {
        _country = 'China';
        _currency = 'CNY';
      } else {
        _country = 'Uganda';
        if (_currency == 'CNY') _currency = 'UGX';
      }
    });
  }

  void _showImageSourcePicker(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Upload Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue.shade600),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture document'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(type, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.green.shade600),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select an existing photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(type, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
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

  /// Pick a document file (PDF or image) for business license
  Future<void> _pickDocument(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          switch (type) {
            case 'business_license':
              _businessLicense = File(result.files.single.path!);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _pickIndustryPermit() async {
    if (_industryPermits.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 industry permits allowed')),
        );
      }
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _industryPermits.add(File(result.files.single.path!));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required documents based on vendor type
    if (_isChinaSupplier) {
      if (_businessLicense == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your Business License'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    } else {
      if (_idFront == null || _idBack == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your National ID (front and back)'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
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
      city: _cityController.text.isNotEmpty ? _cityController.text : null,
      address: _addressController.text.isNotEmpty ? _addressController.text : null,
      preferredCurrency: _currency,
      annualTurnover: double.tryParse(_annualTurnoverController.text),
      nationalIdFront: _idFront,
      nationalIdBack: _idBack,
      bankStatement: _bankStatement,
      proofOfAddress: _proofOfAddress,
      guarantorName: _guarantorNameController.text.isNotEmpty ? _guarantorNameController.text : null,
      guarantorPhone: _guarantorPhoneController.text.isNotEmpty ? _guarantorPhoneController.text : null,
      guarantorId: _guarantorId,
      companyRegistration: _compReg,
      taxCertificate: _taxCert,
      chinaCompanyName: _isChinaSupplier ? _chinaCompanyNameController.text : null,
      uscc: _isChinaSupplier ? _usccController.text : null,
      legalRepresentative: _isChinaSupplier ? _legalRepController.text : null,
      businessScope: _isChinaSupplier ? _businessScopeController.text : null,
      chinaRegisteredAddress: _isChinaSupplier ? _chinaAddressController.text : null,
      registeredCapital: _isChinaSupplier ? _registeredCapitalController.text : null,
      businessLicense: _businessLicense,
      industryPermits: _industryPermits.isNotEmpty ? _industryPermits : null,
    );

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
    final bool isPdf = file != null && file.path.toLowerCase().endsWith('.pdf');
    final bool useDocPicker = type == 'business_license';

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
          onTap: () => useDocPicker ? _pickDocument(type) : _showImageSourcePicker(type),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: file != null ? Colors.green.shade300 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: file != null ? Colors.green.shade50 : Colors.grey.shade50,
            ),
            child: file != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isPdf
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 40),
                                    const SizedBox(height: 4),
                                    Text(
                                      file.path.split('/').last.split('\\').last,
                                      style: TextStyle(color: Colors.green.shade700, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(file, fit: BoxFit.cover),
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
                                case 'business_license': _businessLicense = null; break;
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
                      Icon(useDocPicker ? Icons.upload_file : Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 32),
                      const SizedBox(height: 8),
                      Text(useDocPicker ? 'Select File (PDF or Image)' : 'Take Photo or Choose File', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMultiDocPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Industry Permits', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(' (optional, max 5)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ..._industryPermits.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.green.shade50,
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  entry.value.path.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf
                      : Icons.description,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Permit ${entry.key + 1} (${entry.value.path.split('/').last.split('\\').last})',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                  onPressed: () => setState(() => _industryPermits.removeAt(entry.key)),
                ),
              ],
            ),
          ),
        )),
        if (_industryPermits.length < 5)
          InkWell(
            onTap: _pickIndustryPermit,
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text('Add Permit (PDF or Image)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVerificationLink(String title, String description, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade100),
          borderRadius: BorderRadius.circular(8),
          color: Colors.red.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
                  Text(description, style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.red.shade300),
          ],
        ),
      ),
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

                  // Business Details Card
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
                            onChanged: _onVendorTypeChanged,
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
                                child: _isChinaSupplier
                                    ? DropdownButtonFormField<String>(
                                        value: _country,
                                        decoration: const InputDecoration(labelText: 'Country'),
                                        items: const [
                                          DropdownMenuItem(value: 'China', child: Text('China')),
                                          DropdownMenuItem(value: 'Uganda', child: Text('Uganda')),
                                        ],
                                        onChanged: (v) => setState(() => _country = v!),
                                      )
                                    : TextFormField(
                                        initialValue: _country,
                                        decoration: const InputDecoration(labelText: 'Country'),
                                        readOnly: true,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(labelText: 'City (Optional)'),
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
                                  items: [
                                    const DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                                    const DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    const DropdownMenuItem(value: 'KES', child: Text('KES')),
                                    if (_isChinaSupplier)
                                      const DropdownMenuItem(value: 'CNY', child: Text('CNY')),
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
                                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) {
                                    if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                                      return 'Enter a valid whole number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Business Address (Optional)',
                              hintText: 'Plot number, Street, etc.',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // China Verification Section (animated show/hide)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isChinaSupplier
                        ? Column(
                            children: [
                              const SizedBox(height: 24),
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.red.shade300, width: 1.5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.verified_user, color: Colors.red.shade600, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Chinese Company Verification',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade800),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Required for all China-based suppliers',
                                        style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                                      ),
                                      const SizedBox(height: 16),

                                      // Company Chinese Name
                                      TextFormField(
                                        controller: _chinaCompanyNameController,
                                        decoration: InputDecoration(
                                          labelText: 'Company Chinese Name *',
                                          hintText: 'e.g. \u6df1\u5733\u5e02\u534e\u4e3a\u6280\u672f\u6709\u9650\u516c\u53f8',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        validator: (v) => _isChinaSupplier && (v == null || v.isEmpty) ? 'Required for China suppliers' : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // USCC
                                      TextFormField(
                                        controller: _usccController,
                                        decoration: InputDecoration(
                                          labelText: 'USCC (\u7edf\u4e00\u793e\u4f1a\u4fe1\u7528\u4ee3\u7801) *',
                                          hintText: '18-character code',
                                          counterText: '${_usccController.text.length}/18',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        maxLength: 18,
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
                                        onChanged: (_) => setState(() {}),
                                        validator: (v) {
                                          if (!_isChinaSupplier) return null;
                                          if (v == null || v.isEmpty) return 'Required for China suppliers';
                                          if (v.length != 18) return 'USCC must be exactly 18 characters';
                                          if (!RegExp(r'^[A-Za-z0-9]{18}$').hasMatch(v)) return 'Only letters and numbers allowed';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Legal Representative
                                      TextFormField(
                                        controller: _legalRepController,
                                        decoration: InputDecoration(
                                          labelText: 'Legal Representative *',
                                          hintText: 'Name of legal representative',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        validator: (v) => _isChinaSupplier && (v == null || v.isEmpty) ? 'Required for China suppliers' : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // Business Scope
                                      TextFormField(
                                        controller: _businessScopeController,
                                        decoration: InputDecoration(
                                          labelText: 'Business Scope (\u7ecf\u8425\u8303\u56f4) *',
                                          hintText: 'As stated on business license',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        maxLines: 3,
                                        maxLength: 2000,
                                        validator: (v) => _isChinaSupplier && (v == null || v.isEmpty) ? 'Required for China suppliers' : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // Registered Address
                                      TextFormField(
                                        controller: _chinaAddressController,
                                        decoration: InputDecoration(
                                          labelText: 'Registered Address *',
                                          hintText: 'Company registered address in China',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        validator: (v) => _isChinaSupplier && (v == null || v.isEmpty) ? 'Required for China suppliers' : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // Registered Capital
                                      TextFormField(
                                        controller: _registeredCapitalController,
                                        decoration: InputDecoration(
                                          labelText: 'Registered Capital (Optional)',
                                          hintText: 'e.g. 1,000,000 CNY',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),

                                      const SizedBox(height: 20),
                                      const Divider(),
                                      const SizedBox(height: 12),

                                      // Business License Upload
                                      _buildDocPicker('Business License (\u8425\u4e1a\u6267\u7167)', _businessLicense, 'business_license'),

                                      // Industry Permits
                                      _buildMultiDocPicker(),

                                      // Verification Resources
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Verification Resources',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red.shade700),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildVerificationLink('GSXT', 'National Enterprise Credit Information', 'https://www.gsxt.gov.cn'),
                                      const SizedBox(height: 6),
                                      _buildVerificationLink('China Customs', 'General Administration of Customs', 'http://www.customs.gov.cn'),
                                      const SizedBox(height: 6),
                                      _buildVerificationLink('ChinVerify', 'Chinese Company Verification', 'https://www.chinverify.com'),
                                      const SizedBox(height: 6),
                                      _buildVerificationLink('QINCheck', 'Business Registration Lookup', 'https://www.qincheck.com'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // Required Documents - conditional based on vendor type
                  Text(
                    _isChinaSupplier ? 'Identity Documents (Optional)' : 'Required Documents',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  _buildDocPicker('National ID (Front Side)', _idFront, 'id_front', required: !_isChinaSupplier),
                  _buildDocPicker('National ID (Back Side)', _idBack, 'id_back', required: !_isChinaSupplier),

                  const SizedBox(height: 24),
                  const Text('Optional Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('(Higher chance of faster approval)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 16),

                  _buildDocPicker('Bank Statement (Last 3 Months)', _bankStatement, 'bank', required: false),
                  _buildDocPicker('Proof of Address (Utility bill/rental)', _proofOfAddress, 'address', required: false),

                  const SizedBox(height: 24),
                  const Text('Guarantor Information (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _guarantorPhoneController,
                            decoration: const InputDecoration(labelText: 'Guarantor Phone Number'),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildDocPicker('Guarantor ID (Front Side)', _guarantorId, 'guarantor', required: false),
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
