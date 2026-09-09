import '../entities/rich_chat.dart';

abstract interface class RichChatRepository {
  String get actorId;
  Future<ChatCapabilities> capabilities();
  Future<ChatPage<RichChannel>> channels({String? cursor, String? section});
  Stream<ChatPage<RichChannel>> watchInbox({String? section});
  Stream<RichChatSnapshot> watchChannel(String channelId);
  void setForeground(bool foreground);
  Future<RichChatSnapshot> history(String channelId, {String? before});
  Future<void> send(
    String channelId, {
    required String body,
    List<ChatDraftFile> files = const [],
    String? replyToMessageId,
    String? stickerId,
  });
  Future<void> retry(String channelId, String operationId);
  Future<List<RichMessage>> pending(String channelId);
  Future<void> saveDraft(
    String channelId,
    String body,
    List<ChatDraftFile> files, {
    String? replyToMessageId,
  });
  Future<({String body, List<ChatDraftFile> files, String? replyToMessageId})>
  loadDraft(String channelId);
  Future<RichMessage> action(
    String channelId,
    String messageId, {
    required String action,
    String? body,
    String? emoji,
    String? destinationId,
    int? expectedRevision,
    String? operationId,
  });
  Future<List<Map<String, Object?>>> audit(String channelId, String messageId);
  Future<void> markRead(String channelId, String messageId);
  Future<void> typing(String channelId, bool typing);
  Future<ChatPage<RichMessage>> search(
    String channelId,
    String query, {
    String? cursor,
  });
  Future<ChatLinkPreview?> preview(String channelId, String url);
  Future<ChatPage<ChatUser>> users({String query = '', String? cursor});
  Future<ChatPage<ChatDepartment>> contactDepartments({String? cursor});
  Future<ChatPage<ChatUser>> eligibleContacts({
    String? department,
    String? section,
    String? cursor,
  });
  Future<RichChannel> startDirect(String targetUserId, {String? operationId});
  Future<ChatPage<ChatUser>> members(String channelId);
  Future<ChatPage<ChannelRequest>> requests({String? cursor});
  Future<ChannelRequest> createRequest({
    required String name,
    required String reason,
    required List<String> memberUserIds,
    String? operationId,
  });
  Future<ChannelRequest> reviewRequest(
    String requestId, {
    required String decision,
    required int expectedRevision,
    String? name,
    List<String>? memberUserIds,
    String? reason,
    String? operationId,
  });
  Future<RichChannel> updateMembers(
    String channelId,
    List<String> memberUserIds,
    int expectedRevision, {
    String? operationId,
  });
  Future<RichAttachment> attachment(String channelId, String resourceId);
  Future<ChatDraftFile> download(String channelId, String resourceId);
  Future<void> dispose();
}
