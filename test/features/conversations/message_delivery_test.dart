import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/conversation.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/conversation_repository.dart';
import 'package:zawolf_hr/features/conversations/domain/usecases/message_delivery.dart';

void main() {
  test('failed send remains durable and retry reuses message operation ID', () async {
    final store = MemoryPendingMessageStore();
    final repository = FakeRepository();
    final delivery = MessageDelivery(repository: repository, store: store, actorId: 'user', conversationId: 'channel');
    repository.fail = true;
    await delivery.send(body: 'caption', attachmentResourceIds: ['photo']);
    expect((await store.load('user', 'channel')).single.state, ConversationMessageState.failed);
    final id = repository.ids.single;
    repository.fail = false;
    await delivery.retry(id);
    expect(repository.ids, [id, id]);
    expect((await store.load('user', 'channel')).single.state, ConversationMessageState.sent);
    await delivery.reconcile([id]);
    expect(await store.load('user', 'channel'), isEmpty);
  });

  test('new delivery instance recovers persisted pending message without changing ID', () async {
    final store = MemoryPendingMessageStore();
    final repository = FakeRepository()..fail = true;
    await MessageDelivery(repository: repository, store: store, actorId: 'user', conversationId: 'channel')
        .send(body: '', attachmentResourceIds: ['photo']);
    final id = repository.ids.single;
    repository.fail = false;
    await MessageDelivery(repository: repository, store: store, actorId: 'user', conversationId: 'channel').retry(id);
    expect(repository.ids, [id, id]);
    expect(repository.bodies, ['', '']);
  });

  test('concurrent retries dispatch only once and failed local save never sends', () async {
    final store = MemoryPendingMessageStore();
    final repository = FakeRepository()..fail = true;
    final delivery = MessageDelivery(repository: repository, store: store, actorId: 'user', conversationId: 'channel');
    await delivery.send(body: 'draft');
    final id = repository.ids.single;
    repository.gate = Completer<void>();
    final first = delivery.retry(id);
    final second = delivery.retry(id);
    await Future<void>.delayed(Duration.zero);
    expect(repository.ids.length, 2);
    repository.gate!.complete();
    await Future.wait([first, second]);
    store.failWrites = true;
    await expectLater(delivery.send(body: 'unsaved'), throwsStateError);
    expect(repository.ids.length, 2);
  });
}

class FakeRepository implements ConversationRepository {
  bool fail = false;
  Completer<void>? gate;
  final ids = <String>[];
  final bodies = <String>[];
  @override
  Future<ConversationMessage> sendMessage({required String conversationId, required String senderUserId, required String body, required String operationId, List<String> attachmentResourceIds = const []}) async {
    ids.add(operationId); bodies.add(body);
    await gate?.future;
    return ConversationMessage(id: operationId, conversationId: conversationId, senderUserId: senderUserId, body: body, sentAt: DateTime.now(), state: fail ? ConversationMessageState.failed : ConversationMessageState.sent, attachmentResourceIds: attachmentResourceIds);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryPendingMessageStore implements PendingMessageStore {
  final rows = <String, ConversationMessage>{};
  bool failWrites = false;
  @override
  Future<List<ConversationMessage>> load(String actorId, String channelId) async => rows.values.where((m) => m.senderUserId == actorId && m.conversationId == channelId).toList();
  @override
  Future<void> put(ConversationMessage message) async {
    if (failWrites) throw StateError('storage_full');
    rows[message.id] = message;
  }
  @override
  Future<void> remove(String actorId, String channelId, String messageId) async => rows.remove(messageId);
}
