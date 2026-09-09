import '../domain/entities/rich_chat.dart';

Map<String, Object?> objectMap(Object? v) =>
    v is Map ? Map<String, Object?>.from(v) : {};
List<Map<String, Object?>> objectList(Object? v) =>
    (v is List ? v : []).map(objectMap).toList();
List<String> strings(Object? v) =>
    (v is List ? v : []).whereType<String>().toList();
DateTime date(Object? v) =>
    DateTime.tryParse('$v') ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
RichAttachment decodeAttachment(Map<String, Object?> v) => RichAttachment(
  resourceId: '${v['resourceId'] ?? ''}',
  fileName: '${v['fileName'] ?? 'attachment'}',
  mimeType: '${v['mimeType'] ?? 'application/octet-stream'}',
  sizeBytes: (v['sizeBytes'] as num?)?.toInt() ?? 0,
  kind: '${v['kind'] ?? 'file'}',
  status: '${v['status'] ?? 'uploaded'}',
  width: (v['width'] as num?)?.toDouble(),
  height: (v['height'] as num?)?.toDouble(),
  durationSeconds: (v['durationSeconds'] as num?)?.toDouble(),
);
Map<String, Object?> encodeAttachment(RichAttachment a) => {
  'resourceId': a.resourceId,
  'fileName': a.fileName,
  'mimeType': a.mimeType,
  'sizeBytes': a.sizeBytes,
  'kind': a.kind,
  'status': a.status,
  'width': a.width,
  'height': a.height,
  'durationSeconds': a.durationSeconds,
};
RichMessage decodeMessage(Map<String, Object?> v) => RichMessage(
  id: '${v['id']}',
  conversationId: '${v['conversationId']}',
  senderUserId: '${v['senderUserId']}',
  senderDisplayName: '${v['senderDisplayName'] ?? ''}',
  body: '${v['body'] ?? ''}',
  sentAt: date(v['sentAt']),
  attachments: objectList(v['attachments']).map(decodeAttachment).toList(),
  attachmentResourceIds: strings(v['attachmentResourceIds']),
  replyToMessageId: v['replyToMessageId'] as String?,
  forwarded: v['forwarded'] == true,
  revision: (v['revision'] as num?)?.toInt() ?? 0,
  editedAt: v['editedAt'] == null ? null : date(v['editedAt']),
  deletedAt: v['deletedAt'] == null ? null : date(v['deletedAt']),
  reactions: objectMap(v['reactions']).map((k, v) => MapEntry(k, '$v')),
  syncState:
      ChatSyncState.values.where((s) => s.name == v['syncState']).firstOrNull ??
      ChatSyncState.synced,
  errorCode: v['errorCode'] as String?,
  uploadProgress: (v['uploadProgress'] as num?)?.toDouble(),
);
Map<String, Object?> encodeMessage(RichMessage m) => {
  'id': m.id,
  'conversationId': m.conversationId,
  'senderUserId': m.senderUserId,
  'senderDisplayName': m.senderDisplayName,
  'body': m.body,
  'sentAt': m.sentAt.toUtc().toIso8601String(),
  'attachments': m.attachments.map(encodeAttachment).toList(),
  'attachmentResourceIds': m.attachmentResourceIds,
  'replyToMessageId': m.replyToMessageId,
  'forwarded': m.forwarded,
  'revision': m.revision,
  'editedAt': m.editedAt?.toUtc().toIso8601String(),
  'deletedAt': m.deletedAt?.toUtc().toIso8601String(),
  'reactions': m.reactions,
  'syncState': m.syncState.name,
  'errorCode': m.errorCode,
  'uploadProgress': m.uploadProgress,
};
RichChannel decodeChannel(Map<String, Object?> v) => RichChannel(
  id: '${v['id']}',
  name: '${v['name'] ?? ''}',
  kind: '${v['kind'] ?? 'custom'}',
  canPost: v['canPost'] == true,
  memberUserIds: strings(v['memberUserIds']),
  participantUserIds: strings(v['participantUserIds']),
  unreadCount: (v['unreadCount'] as num?)?.toInt() ?? 0,
  hrReadable: v['hrReadable'] == true,
  revision: (v['revision'] as num?)?.toInt() ?? 0,
  latestActivityAt:
      v['latestActivityAt'] == null ? null : date(v['latestActivityAt']),
);
ChatUser decodeUser(Map<String, Object?> v) => ChatUser(
  id: '${v['id'] ?? ''}',
  name: '${v['name'] ?? ''}',
  department: '${v['department'] ?? ''}',
);
ChatDepartment decodeDepartment(Map<String, Object?> v) => ChatDepartment(
  id: '${v['id'] ?? ''}',
  name: '${v['name'] ?? ''}',
  eligibleCount: (v['eligibleCount'] as num?)?.toInt() ?? 0,
);
ChannelRequest decodeRequest(Map<String, Object?> v) => ChannelRequest(
  id: '${v['id']}',
  name: '${v['name'] ?? ''}',
  reason: '${v['reason'] ?? ''}',
  requesterId: '${v['requesterId'] ?? ''}',
  status: '${v['status'] ?? 'pending'}',
  memberUserIds: strings(v['memberUserIds']),
  revision: (v['revision'] as num?)?.toInt() ?? 0,
  rejectionReason: v['rejectionReason'] as String?,
  conversationId: v['conversationId'] as String?,
);
RichChatSnapshot decodeSnapshot(Map<String, Object?> v) => RichChatSnapshot(
  messages: objectList(v['messages']).map(decodeMessage).toList(),
  readers:
      objectMap(v['readers']).entries.map((e) {
        final r = objectMap(e.value);
        return ChatReader(
          userId: e.key,
          messageId: '${r['messageId'] ?? ''}',
          name: '${r['name'] ?? ''}',
          readAt: date(r['readAt']),
          sentAt: r['sentAt'] == null ? null : date(r['sentAt']),
        );
      }).toList(),
  typing:
      objectList(v['typing'])
          .map(
            (t) => ChatTyping(
              userId: '${t['userId']}',
              name: '${t['name'] ?? ''}',
              expiresAt: date(t['expiresAt']),
            ),
          )
          .toList(),
  canPost: v['canPost'] == true,
  nextCursor: v['nextCursor'] as String?,
  changeCursor: v['changeCursor'] as String?,
  hasMore: v['hasMore'] == true,
);
