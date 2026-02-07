// lib/features/chat/providers/chat_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// Models
class ConversationModel {
  final int id;
  final String participantName;
  final String? participantAvatar;
  final ListingPreview? listing;
  final String? subject;
  final MessagePreview? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.participantName,
    this.participantAvatar,
    this.listing,
    this.subject,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      participantName: json['participant_name'] as String? ?? 'Unknown',
      participantAvatar: json['participant_avatar'] as String?,
      listing: json['listing'] != null
          ? ListingPreview.fromJson(json['listing'])
          : null,
      subject: json['subject'] as String?,
      lastMessage: json['last_message'] != null
          ? MessagePreview.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ListingPreview {
  final int id;
  final String title;
  final String? image;

  ListingPreview({
    required this.id,
    required this.title,
    this.image,
  });

  factory ListingPreview.fromJson(Map<String, dynamic> json) {
    return ListingPreview(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}

class MessagePreview {
  final String body;
  final String type;
  final bool isMine;
  final DateTime createdAt;

  MessagePreview({
    required this.body,
    required this.type,
    required this.isMine,
    required this.createdAt,
  });

  factory MessagePreview.fromJson(Map<String, dynamic> json) {
    return MessagePreview(
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      isMine: json['is_mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MessageModel {
  final int id;
  final String body;
  final String type;
  final String? attachmentPath;
  final String? attachmentName;
  final bool isMine;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.body,
    required this.type,
    this.attachmentPath,
    this.attachmentName,
    required this.isMine,
    this.readAt,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      attachmentPath: json['attachment_path'] as String?,
      attachmentName: json['attachment_name'] as String?,
      isMine: json['is_mine'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ConversationDetail {
  final int id;
  final String participantName;
  final String? participantAvatar;
  final String? subject;
  final int? listingId;

  ConversationDetail({
    required this.id,
    required this.participantName,
    this.participantAvatar,
    this.subject,
    this.listingId,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'] as int,
      participantName: json['participant_name'] as String? ?? 'Unknown',
      participantAvatar: json['participant_avatar'] as String?,
      subject: json['subject'] as String?,
      listingId: json['listing_id'] as int?,
    );
  }
}

// State classes
class ConversationsState {
  final List<ConversationModel> conversations;
  final bool isLoading;
  final String? error;

  ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatState {
  final ConversationDetail? conversation;
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  ChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    ConversationDetail? conversation,
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// Providers
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  return ConversationsNotifier(ref.read(apiClientProvider));
});

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, int>((ref, conversationId) {
  return ChatNotifier(ref.read(apiClientProvider), conversationId);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.get('/api/chat/unread-count');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['unread_count'] as int? ?? 0;
    }
  } catch (e) {
    // Ignore errors
  }
  return 0;
});

// Notifiers
class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ApiClient _api;

  ConversationsNotifier(this._api) : super(ConversationsState()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.get('/api/chat/conversations');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List? ?? [];
        final conversations = data
            .map((json) => ConversationModel.fromJson(json))
            .toList();

        state = state.copyWith(
          conversations: conversations,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load conversations',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error: ${e.toString()}',
      );
    }
  }

  Future<int?> startConversation({
    required int vendorProfileId,
    int? listingId,
    String? initialMessage,
  }) async {
    try {
      print('🔄 Starting conversation with vendor profile ID: $vendorProfileId');
      final response = await _api.post('/api/chat/conversations', data: {
        'vendor_profile_id': vendorProfileId,
        if (listingId != null) 'listing_id': listingId,
        if (initialMessage != null) 'initial_message': initialMessage,
      });

      print('📦 Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Reload conversations
        await loadConversations();
        return response.data['conversation_id'] as int?;
      } else {
        print('❌ Failed: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ Error starting conversation: $e');
    }
    return null;
  }

  /// Vendor starts conversation with a buyer (for order inquiries)
  Future<int?> startConversationWithBuyer({
    required int buyerId,
    String? initialMessage,
    String? subject,
  }) async {
    try {
      print('🔄 Starting conversation with buyer ID: $buyerId');
      final response = await _api.post('/api/chat/conversations/with-buyer', data: {
        'buyer_id': buyerId,
        if (initialMessage != null) 'initial_message': initialMessage,
        if (subject != null) 'subject': subject,
      });

      print('📦 Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Reload conversations
        await loadConversations();
        return response.data['conversation_id'] as int?;
      } else {
        print('❌ Failed: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ Error starting conversation: $e');
    }
    return null;
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _api;
  final int conversationId;
  Timer? _refreshTimer;

  ChatNotifier(this._api, this.conversationId) : super(ChatState()) {
    loadMessages();
    // Poll for new messages every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollNewMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response =
          await _api.get('/api/chat/conversations/$conversationId/messages');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final conversationJson = response.data['conversation'];
        final messagesJson = response.data['messages'] as List? ?? [];

        final conversation = ConversationDetail.fromJson(conversationJson);
        final messages = messagesJson
            .map((json) => MessageModel.fromJson(json))
            .toList();

        state = state.copyWith(
          conversation: conversation,
          messages: messages,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load messages',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error: ${e.toString()}',
      );
    }
  }

  Future<void> _pollNewMessages() async {
    if (state.isLoading || state.isSending) return;

    try {
      final response =
          await _api.get('/api/chat/conversations/$conversationId/messages');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final messagesJson = response.data['messages'] as List? ?? [];
        final messages = messagesJson
            .map((json) => MessageModel.fromJson(json))
            .toList();

        if (messages.length != state.messages.length) {
          state = state.copyWith(messages: messages);
        }
      }
    } catch (e) {
      // Ignore polling errors
    }
  }

  Future<bool> sendMessage(String body) async {
    if (body.trim().isEmpty) return false;

    state = state.copyWith(isSending: true, error: null);

    try {
      final response = await _api.post(
        '/api/chat/conversations/$conversationId/messages',
        data: {'body': body},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final messageJson = response.data['message'];
        final newMessage = MessageModel.fromJson(messageJson);

        state = state.copyWith(
          messages: [...state.messages, newMessage],
          isSending: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isSending: false,
          error: 'Failed to send message',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Error: ${e.toString()}',
      );
      return false;
    }
  }
}
