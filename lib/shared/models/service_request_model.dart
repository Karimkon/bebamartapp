// lib/shared/models/service_request_model.dart

class ServiceRequestModel {
  final int id;
  final String requestNumber;
  final String status;
  final String statusLabel;
  final String description;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? location;
  final String? address;
  final String? preferredDate;
  final String? preferredTime;
  final String urgency;
  final double? budgetMin;
  final double? budgetMax;
  final double? quotedPrice;
  final double? finalPrice;
  final ServiceRequestService? service;
  final ServiceRequestUser? user;
  final String? createdAt;
  final String? acceptedAt;
  final String? completedAt;

  ServiceRequestModel({
    required this.id,
    required this.requestNumber,
    required this.status,
    required this.statusLabel,
    required this.description,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.location,
    this.address,
    this.preferredDate,
    this.preferredTime,
    this.urgency = 'normal',
    this.budgetMin,
    this.budgetMax,
    this.quotedPrice,
    this.finalPrice,
    this.service,
    this.user,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] ?? 0,
      requestNumber: json['request_number'] ?? '',
      status: json['status'] ?? 'pending',
      statusLabel: json['status_label'] ?? _defaultLabel(json['status'] ?? 'pending'),
      description: json['description'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      location: json['location'],
      address: json['address'],
      preferredDate: json['preferred_date'],
      preferredTime: json['preferred_time'],
      urgency: json['urgency'] ?? 'normal',
      budgetMin: json['budget_min'] != null ? double.tryParse(json['budget_min'].toString()) : null,
      budgetMax: json['budget_max'] != null ? double.tryParse(json['budget_max'].toString()) : null,
      quotedPrice: json['quoted_price'] != null ? double.tryParse(json['quoted_price'].toString()) : null,
      finalPrice: json['final_price'] != null ? double.tryParse(json['final_price'].toString()) : null,
      service: json['service'] != null ? ServiceRequestService.fromJson(json['service']) : null,
      user: json['user'] != null ? ServiceRequestUser.fromJson(json['user']) : null,
      createdAt: json['created_at'],
      acceptedAt: json['accepted_at'],
      completedAt: json['completed_at'],
    );
  }

  static String _defaultLabel(String status) {
    switch (status) {
      case 'pending': return 'Awaiting Response';
      case 'quoted': return 'Quote Received';
      case 'accepted': return 'Accepted';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }
}

class ServiceRequestService {
  final int id;
  final String title;
  final String? pricingType;
  final double? price;
  final List<String> images;

  ServiceRequestService({
    required this.id,
    required this.title,
    this.pricingType,
    this.price,
    this.images = const [],
  });

  factory ServiceRequestService.fromJson(Map<String, dynamic> json) {
    List<String> imgs = [];
    if (json['images'] != null) {
      imgs = List<String>.from(json['images'] as List);
    }
    return ServiceRequestService(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      pricingType: json['pricing_type'],
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      images: imgs,
    );
  }
}

class ServiceRequestUser {
  final int id;
  final String name;
  final String? phone;
  final String? email;

  ServiceRequestUser({required this.id, required this.name, this.phone, this.email});

  factory ServiceRequestUser.fromJson(Map<String, dynamic> json) {
    return ServiceRequestUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
    );
  }
}
