import '../entities/conversation.dart';
import '../entities/governed_attachment.dart';

abstract interface class ConversationRepository {
  Future<List<String>> listAvailableDepartments();

  Future<Conversation> openDepartmentChannel(String departmentName);

  Future<Conversation> openManagerChannel();

  Stream<List<Conversation>> watchForMember(String memberUserId);

  Stream<List<ConversationMessage>> watchMessages({
    required String conversationId,
    required String memberUserId,
  });

  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String senderUserId,
    required String body,
    required String operationId,
    List<String> attachmentResourceIds = const <String>[],
  });
}

abstract interface class GovernedAttachmentGateway {
  Future<GovernedAttachment> upload({
    required String conversationId,
    required String actorUserId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    required String operationId,
  });

  Future<Uri> createAuditedDownload({
    required String conversationId,
    required String actorUserId,
    required String resourceId,
  });

  Future<GovernedAttachmentFile> download({
    required String conversationId,
    required String actorUserId,
    required String resourceId,
  });
}
