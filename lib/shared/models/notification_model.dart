// lib/shared/models/notification_model.dart
// Notification models for push notification inbox and preferences

import 'package:flutter/material.dart';

class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Route to navigate to when tapped
  String? get targetRoute => data?['route'] as String?;

  /// Icon based on notification type
  IconData get icon => switch (type) {
        'order_update' => Icons.local_shipping_outlined,
        'cart_reminder' => Icons.shopping_cart_outlined,
        'price_drop' => Icons.trending_down,
        'recommendation' => Icons.recommend_outlined,
        'promo' => Icons.campaign_outlined,
        'vendor_order' => Icons.shopping_bag_outlined,
        'vendor_review' => Icons.star_outlined,
        'vendor_payout' => Icons.payments_outlined,
        'vendor_tip' => Icons.lightbulb_outlined,
        _ => Icons.notifications_outlined,
      };

  /// Color based on notification type
  Color get color => switch (type) {
        'order_update' => const Color(0xFF3B82F6),
        'cart_reminder' => const Color(0xFFF59E0B),
        'price_drop' => const Color(0xFF10B981),
        'recommendation' => const Color(0xFF6366F1),
        'promo' => const Color(0xFFEC4899),
        'vendor_order' => const Color(0xFF8B5CF6),
        'vendor_review' => const Color(0xFFF59E0B),
        'vendor_payout' => const Color(0xFF10B981),
        'vendor_tip' => const Color(0xFF06B6D4),
        _ => const Color(0xFF6366F1),
      };

  /// Time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

class NotificationPreferencesModel {
  bool pushEnabled;
  bool emailEnabled;
  bool orderUpdates;
  bool promotions;
  bool recommendations;
  bool priceDrops;
  bool cartReminders;
  bool newOrders;
  bool reviews;
  bool payouts;
  bool vendorTips;

  NotificationPreferencesModel({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.orderUpdates = true,
    this.promotions = true,
    this.recommendations = true,
    this.priceDrops = true,
    this.cartReminders = true,
    this.newOrders = true,
    this.reviews = true,
    this.payouts = true,
    this.vendorTips = false,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      pushEnabled: json['push_enabled'] == true || json['push_enabled'] == 1,
      emailEnabled: json['email_enabled'] == true || json['email_enabled'] == 1,
      orderUpdates: json['order_updates'] == true || json['order_updates'] == 1,
      promotions: json['promotions'] == true || json['promotions'] == 1,
      recommendations:
          json['recommendations'] == true || json['recommendations'] == 1,
      priceDrops: json['price_drops'] == true || json['price_drops'] == 1,
      cartReminders:
          json['cart_reminders'] == true || json['cart_reminders'] == 1,
      newOrders: json['new_orders'] == true || json['new_orders'] == 1,
      reviews: json['reviews'] == true || json['reviews'] == 1,
      payouts: json['payouts'] == true || json['payouts'] == 1,
      vendorTips: json['vendor_tips'] == true || json['vendor_tips'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'email_enabled': emailEnabled,
        'order_updates': orderUpdates,
        'promotions': promotions,
        'recommendations': recommendations,
        'price_drops': priceDrops,
        'cart_reminders': cartReminders,
        'new_orders': newOrders,
        'reviews': reviews,
        'payouts': payouts,
        'vendor_tips': vendorTips,
      };

  NotificationPreferencesModel copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? orderUpdates,
    bool? promotions,
    bool? recommendations,
    bool? priceDrops,
    bool? cartReminders,
    bool? newOrders,
    bool? reviews,
    bool? payouts,
    bool? vendorTips,
  }) {
    return NotificationPreferencesModel(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
      recommendations: recommendations ?? this.recommendations,
      priceDrops: priceDrops ?? this.priceDrops,
      cartReminders: cartReminders ?? this.cartReminders,
      newOrders: newOrders ?? this.newOrders,
      reviews: reviews ?? this.reviews,
      payouts: payouts ?? this.payouts,
      vendorTips: vendorTips ?? this.vendorTips,
    );
  }
}
