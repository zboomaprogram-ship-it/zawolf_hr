import 'dart:convert';

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/governed_attachment.dart';
import '../domain/repositories/conversation_repository.dart';

final class ConversationRepositoryImpl
    implements ConversationRepository, GovernedAttachmentGateway {
  ConversationRepositoryImpl({
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
    Object? firestore,
  }) : _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri;

  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;

  @override
  Future<List<String>> listAvailableDepartments() async {
    final response = await _operationClient.get(
      _operationsBaseUri.resolve('/conversations/departments'),
    );
    if (!response.ok) throw StateError(response.safeCode);
    return List<String>.from(
      (response.data['departments'] as List?)?.map(
            (value) => value.toString(),
          ) ??
          const <String>[],
    );
  }

  @override
  Future<Conversation> openDepartmentChannel(String departmentName) async {
    final encoded = Uri.encodeComponent(departmentName.trim());
    final response = await _operationClient.get(
      _operationsBaseUri.resolve('/conversations/department/$encoded'),
    );
    if (!response.ok) throw StateError(response.safeCode);
    return Conversation(
      id: response.data['conversationId']?.toString() ?? '',
      memberUserIds: const <String>{},
      purposeAr:
          'قناة قسم ${response.data['departmentName'] ?? departmentName}',
      state: ConversationState.active,
    );
  }

  @override
  Future<Conversation> openManagerChannel() async {
    final response = await _operationClient.get(
      _operationsBaseUri.resolve('/conversations/manager-channel'),
    );
    if (!response.ok) throw StateError(response.safeCode);
    return Conversation(
      id: response.data['conversationId']?.toString() ?? '',
      memberUserIds: const <String>{},
      purposeAr: response.data['name']?.toString() ?? 'قناة المديرين',
      state: ConversationState.active,
    );
  }

  @override
  Stream<List<Conversation>> watchForMember(String memberUserId) =>
      const Stream<List<Conversation>>.empty();

  @override
  Stream<List<ConversationMessage>> watchMessages({
    required String conversationId,
    required String memberUserId,
  }) async* {
    while (true) {
      try {
        final response = await _operationClient.get(
          _operationsBaseUri.resolve(
            '/conversations/$conversationId/messages?limit=100',
          ),
        );
        if (response.ok) {
          final messages =
              (response.data['messages'] as List?)
                  ?.whereType<Map>()
                  .map(
                    (value) => _message(
                      value['id']?.toString() ?? '',
                      Map<String, dynamic>.from(value),
                    ),
                  )
                  .toList(growable: false) ??
              const <ConversationMessage>[];
          yield messages;
        }
      } catch (_) {
        // Silently swallow transient network glitches during background polling
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String senderUserId,
    required String body,
    required String operationId,
    List<String> attachmentResourceIds = const <String>[],
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/conversations/$conversationId/messages'),
      operationId: operationId,
      body: {'body': body, 'attachmentResourceIds': attachmentResourceIds},
    );
    return ConversationMessage(
      id: response.data['messageId']?.toString() ?? operationId,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDisplayName: '',
      body: body,
      sentAt: DateTime.now().toUtc(),
      state:
          response.ok
              ? ConversationMessageState.sent
              : ConversationMessageState.failed,
      attachmentResourceIds: attachmentResourceIds,
    );
  }

  @override
  Future<GovernedAttachment> upload({
    required String conversationId,
    required String actorUserId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    required String operationId,
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/conversations/$conversationId/attachments'),
      operationId: operationId,
      body: {
        'name': fileName,
        'mimeType': mimeType,
        'contentsBase64': base64Encode(bytes),
      },
    );
    if (!response.ok) {
      throw StateError(switch (response.safeCode) {
        'session_expired' => 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
        'access_denied' => 'ليس لديك صلاحية رفع مرفق في هذه القناة.',
        'temporarily_unavailable' =>
          'مجلد مرفقات المحادثات في Google Drive غير جاهز حالياً. أعد المحاولة لاحقاً أو تواصل مع HR.',
        'drive_upload_not_ready' =>
          'مرفقات المحادثات تحتاج مجلد Google Shared Drive مهيأً للرفع. تواصل مع HR لإكمال الإعداد.',
        'connection_interrupted' =>
          'تعذر الاتصال بخدمة Google Drive. تحقق من الإنترنت ثم أعد المحاولة.',
        _ => 'تعذر رفع المرفق إلى Google Drive. حاول مرة أخرى.',
      });
    }
    return GovernedAttachment(
      resourceId: response.data['resourceId']?.toString() ?? operationId,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      status: GovernedAttachmentStatus.uploaded,
    );
  }

  @override
  Future<Uri> createAuditedDownload({
    required String conversationId,
    required String actorUserId,
    required String resourceId,
  }) async => _operationsBaseUri.resolve(
    '/conversations/$conversationId/attachments/$resourceId/download',
  );

  @override
  Future<GovernedAttachmentFile> download({
    required String conversationId,
    required String actorUserId,
    required String resourceId,
  }) async {
    final response = await _operationClient.download(
      _operationsBaseUri.resolve(
        '/conversations/$conversationId/attachments/$resourceId/download',
      ),
    );
    if (!response.ok) throw StateError('attachment_download_failed');
    return GovernedAttachmentFile(
      bytes: response.bytes,
      fileName: response.fileName,
      mimeType: response.mimeType,
    );
  }

  static ConversationMessage _message(String id, Map<String, dynamic> data) =>
      ConversationMessage(
        id: id,
        conversationId: data['conversationId']?.toString() ?? '',
        senderUserId: data['senderUserId']?.toString() ?? '',
        senderDisplayName: data['senderDisplayName']?.toString() ?? '',
        body: data['body']?.toString() ?? '',
        sentAt:
            DateTime.tryParse(data['sentAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        state: switch (data['state']) {
          'pending' => ConversationMessageState.pending,
          'failed' => ConversationMessageState.failed,
          _ => ConversationMessageState.sent,
        },
        attachmentResourceIds: List<String>.from(
          (data['attachmentResourceIds'] as List?)?.whereType<String>() ??
              const [],
        ),
      );
}
