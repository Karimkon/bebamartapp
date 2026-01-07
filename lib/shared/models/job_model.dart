// lib/shared/models/job_model.dart
import 'category_model.dart';

class JobListingModel {
  final int id;
  final String title;
  final String slug;
  final String companyName;
  final String? jobType;
  final String? salaryMin;
  final String? salaryMax;
  final String? city;
  final String? description;
  final String? location;
  final List<String>? requirements;
  final JobVendorPreview vendor;
  final JobCategoryPreview? category;

  JobListingModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.companyName,
    this.jobType,
    this.salaryMin,
    this.salaryMax,
    this.city,
    this.description,
    this.location,
    this.requirements,
    required this.vendor,
    this.category,
  });

  factory JobListingModel.fromJson(Map<String, dynamic> json) {
    return JobListingModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Job',
      slug: json['slug'] as String? ?? '',
      companyName: json['company_name'] as String? ?? 'Unknown Company',
      jobType: json['job_type'] as String?,
      salaryMin: json['salary_min']?.toString(),
      salaryMax: json['salary_max']?.toString(),
      city: json['city'] as String?,
      description: json['description'] as String?,
      location: json['location'] as String?,
      requirements: (json['requirements'] as List?)?.map((e) => e.toString()).toList(),
      vendor: JobVendorPreview.fromJson(json['vendor'] as Map<String, dynamic>),
      category: json['category'] != null
          ? JobCategoryPreview.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displaySalary {
    if (salaryMin == null && salaryMax == null) return 'Negotiable';
    if (salaryMin != null && salaryMax == null) return '$salaryMin+';
    if (salaryMin == null && salaryMax != null) return 'Up to $salaryMax';
    return '$salaryMin - $salaryMax';
  }
}

class JobVendorPreview {
  final int id;
  final String businessName;

  JobVendorPreview({
    required this.id,
    required this.businessName,
  });

  factory JobVendorPreview.fromJson(Map<String, dynamic> json) {
    return JobVendorPreview(
      id: json['id'] as int,
      businessName: json['business_name'] as String? ?? 'Unknown Vendor',
    );
  }
}

class JobCategoryPreview {
  final int id;
  final String name;
  final String slug;

  JobCategoryPreview({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory JobCategoryPreview.fromJson(Map<String, dynamic> json) {
    return JobCategoryPreview(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Category',
      slug: json['slug'] as String? ?? '',
    );
  }
}
