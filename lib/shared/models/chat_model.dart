// lib/shared/models/chat_model.dart
import 'user_model.dart';
import 'listing_model.dart';

class ConversationModel {
  final int id;
  final int buyerId;
  final int vendorProfileId;
  final int? listingId;
  final String? subject;
  final DateTime? lastMessageAt;
  final String status;
  final DateTime? createdAt;
  final UserModel? buyer;
  final VendorProfileModel? vendor;
  final ListingModel? listing;
  final List<MessageModel>? messages;
  final int? unreadCount;
  final MessageModel? lastMessage;
  
  ConversationModel({
    required this.id,
    required this.buyerId,
    required this.vendorProfileId,
    this.listingId,
    this.subject,
    this.lastMessageAt,
    this.status = 'active',
    this.createdAt,
    this.buyer,
    this.vendor,
    this.listing,
    this.messages,
    this.unreadCount,
    this.lastMessage,
  });
  
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      buyerId: json['buyer_id'] as int,
      vendorProfileId: json['vendor_profile_id'] as int,
      listingId: json['listing_id'] as int?,
      subject: json['subject'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      buyer: json['buyer'] != null ? UserModel.fromJson(json['buyer']) : null,
      vendor: json['vendor'] != null || json['vendor_profile'] != null
          ? VendorProfileModel.fromJson(json['vendor'] ?? json['vendor_profile'])
          : null,
      listing: json['listing'] != null ? ListingModel.fromJson(json['listing']) : null,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((e) => MessageModel.fromJson(e)).toList(),
      unreadCount: json['unread_count'] as int?,
      lastMessage: json['last_message'] != null
          ? MessageModel.fromJson(json['last_message']) : null,
    );
  }
  
  bool get isActive => status == 'active';
  bool get hasUnread => unreadCount != null && unreadCount! > 0;
  
  String getOtherPartyName(int currentUserId) {
    if (buyerId == currentUserId) {
      return vendor?.businessName ?? 'Vendor';
    }
    return buyer?.displayName ?? 'Buyer';
  }
}

class MessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String body;
  final String type;
  final String? attachmentPath;
  final String? attachmentName;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime? createdAt;
  final UserModel? sender;
  
  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.type = 'text',
    this.attachmentPath,
    this.attachmentName,
    this.readAt,
    this.isDeleted = false,
    this.createdAt,
    this.sender,
  });
  
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as int,
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      attachmentPath: json['attachment_path'] as String?,
      attachmentName: json['attachment_name'] as String?,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      sender: json['sender'] != null ? UserModel.fromJson(json['sender']) : null,
    );
  }
  
  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get hasAttachment => attachmentPath != null;
  bool get isRead => readAt != null;
  bool isSentBy(int userId) => senderId == userId;
}
