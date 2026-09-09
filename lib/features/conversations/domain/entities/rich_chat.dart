import 'dart:typed_data';

enum ChatSyncState { synced, pending, failed, conflict }

class ChatFailure implements Exception {
  const ChatFailure(this.code);
  final String code;
  @override
  String toString() => code;
}

class RichAttachment {
  const RichAttachment({
    required this.resourceId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.kind = 'file',
    this.status = 'uploaded',
    this.width,
    this.height,
    this.durationSeconds,
  });
  final String resourceId, fileName, mimeType, kind, status;
  final int sizeBytes;
  final double? width, height, durationSeconds;
}

class ChatDraftFile {
  const ChatDraftFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.kind = 'file',
    this.durationSeconds,
  });
  final String fileName, mimeType, kind;
  final Uint8List bytes;
  final double? durationSeconds;
}

class RichMessage {
  const RichMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.sentAt,
    this.senderDisplayName = '',
    this.attachments = const [],
    this.attachmentResourceIds = const [],
    this.replyToMessageId,
    this.forwarded = false,
    this.revision = 0,
    this.editedAt,
    this.deletedAt,
    this.reactions = const {},
    this.syncState = ChatSyncState.synced,
    this.errorCode,
    this.uploadProgress,
  });
  final String id, conversationId, senderUserId, senderDisplayName, body;
  final DateTime sentAt;
  final List<RichAttachment> attachments;
  final List<String> attachmentResourceIds;
  final String? replyToMessageId, errorCode;
  final double? uploadProgress;
  final bool forwarded;
  final int revision;
  final DateTime? editedAt, deletedAt;
  final Map<String, String> reactions;
  final ChatSyncState syncState;
  bool get isDeleted => deletedAt != null;
  bool canEdit(String actor, DateTime now) =>
      actor == senderUserId &&
      !isDeleted &&
      syncState == ChatSyncState.synced &&
      now.difference(sentAt) < const Duration(minutes: 15);
}

class RichChannel {
  const RichChannel({
    required this.id,
    required this.name,
    this.kind = 'custom',
    this.canPost = false,
    this.memberUserIds = const [],
    this.participantUserIds = const [],
    this.unreadCount = 0,
    this.hrReadable = false,
    this.revision = 0,
    this.latestActivityAt,
  });
  final String id, name, kind;
  final bool canPost, hrReadable;
  final List<String> memberUserIds, participantUserIds;
  final int unreadCount, revision;
  final DateTime? latestActivityAt;
}

class ChatUser {
  const ChatUser({required this.id, required this.name, this.department = ''});
  final String id, name, department;
}

class ChatDepartment {
  const ChatDepartment({
    required this.id,
    required this.name,
    this.eligibleCount = 0,
  });
  final String id, name;
  final int eligibleCount;
}

class ChannelRequest {
  const ChannelRequest({
    required this.id,
    required this.name,
    required this.reason,
    required this.requesterId,
    required this.status,
    this.memberUserIds = const [],
    this.revision = 0,
    this.rejectionReason,
    this.conversationId,
  });
  final String id, name, reason, requesterId, status;
  final List<String> memberUserIds;
  final int revision;
  final String? rejectionReason, conversationId;
}

class ChatReader {
  const ChatReader({
    required this.userId,
    required this.messageId,
    required this.name,
    required this.readAt,
    this.sentAt,
  });
  final String userId, messageId, name;
  final DateTime readAt;
  final DateTime? sentAt;
}

class ChatTyping {
  const ChatTyping({
    required this.userId,
    required this.name,
    required this.expiresAt,
  });
  final String userId, name;
  final DateTime expiresAt;
}

class ChatPage<T> {
  const ChatPage(
    this.items, {
    this.nextCursor,
    this.complete = true,
    this.offline = false,
  });
  final List<T> items;
  final String? nextCursor;
  final bool complete, offline;
}

class RichChatSnapshot {
  const RichChatSnapshot({
    this.messages = const [],
    this.readers = const [],
    this.typing = const [],
    this.canPost = false,
    this.nextCursor,
    this.changeCursor,
    this.hasMore = false,
    this.offline = false,
    this.errorCode,
  });
  final List<RichMessage> messages;
  final List<ChatReader> readers;
  final List<ChatTyping> typing;
  final bool canPost, hasMore, offline;
  final String? nextCursor, changeCursor, errorCode;
}

class ChatCapabilities {
  const ChatCapabilities({required this.enabled, required this.canReview});
  final bool enabled, canReview;
}

class ChatLinkPreview {
  const ChatLinkPreview({required this.url, required this.title, this.image});
  final String url, title;
  final String? image;
}
