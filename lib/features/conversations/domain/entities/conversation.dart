enum ConversationState { active, closed }

final class Conversation {
  const Conversation({
    required this.id,
    required this.memberUserIds,
    required this.purposeAr,
    required this.state,
  });

  final String id;
  final Set<String> memberUserIds;
  final String purposeAr;
  final ConversationState state;

  bool includes(String userId) => memberUserIds.contains(userId);
}

enum ConversationMessageState { pending, sent, failed }

final class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    this.senderDisplayName = '',
    required this.body,
    required this.sentAt,
    required this.state,
    this.attachmentResourceIds = const <String>[],
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final String body;
  final DateTime sentAt;
  final ConversationMessageState state;
  final List<String> attachmentResourceIds;
}
