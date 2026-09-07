import 'dart:math';
import '../entities/conversation.dart';
import '../repositories/conversation_repository.dart';

abstract interface class PendingMessageStore {
  Future<List<ConversationMessage>> load(String actorId, String channelId);
  Future<void> put(ConversationMessage message);
  Future<void> remove(String actorId, String channelId, String messageId);
}

String newChatOperationId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class MessageDelivery {
  MessageDelivery({
    required this.repository,
    required this.store,
    required this.actorId,
    required this.conversationId,
  });
  final ConversationRepository repository;
  final PendingMessageStore store;
  final String actorId, conversationId;
  final Map<String, Future<void>> _running = {};

  Future<void> send({
    required String body,
    List<String> attachmentResourceIds = const [],
  }) async {
    if (body.trim().isEmpty && attachmentResourceIds.isEmpty) {
      throw ArgumentError('empty_message');
    }
    final message = ConversationMessage(
      id: newChatOperationId(),
      conversationId: conversationId,
      senderUserId: actorId,
      body: body,
      sentAt: DateTime.now().toUtc(),
      state: ConversationMessageState.pending,
      attachmentResourceIds: attachmentResourceIds,
    );
    await store.put(message);
    await retry(message.id);
  }

  Future<void> retry(String id) =>
      _running[id] ??= _retry(id).whenComplete(() {
        _running.remove(id);
      });
  Future<void> _retry(String id) async {
    final rows = await store.load(actorId, conversationId);
    final message = rows.where((m) => m.id == id).firstOrNull;
    if (message == null || message.state == ConversationMessageState.sent) {
      return;
    }
    ConversationMessageState state;
    try {
      final result = await repository.sendMessage(
        conversationId: conversationId,
        senderUserId: actorId,
        body: message.body,
        operationId: id,
        attachmentResourceIds: message.attachmentResourceIds,
      );
      state = result.state;
    } catch (_) {
      state = ConversationMessageState.failed;
    }
    await store.put(
      ConversationMessage(
        id: id,
        conversationId: conversationId,
        senderUserId: actorId,
        body: message.body,
        sentAt: message.sentAt,
        state: state,
        attachmentResourceIds: message.attachmentResourceIds,
      ),
    );
  }

  Future<void> reconcile(Iterable<String> acceptedIds) async {
    for (final id in acceptedIds) {
      await store.remove(actorId, conversationId, id);
    }
  }
}
