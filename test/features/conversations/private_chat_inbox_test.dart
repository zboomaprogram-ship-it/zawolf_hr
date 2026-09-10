import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/rich_chat_repository.dart';
import 'package:zawolf_hr/features/conversations/presentation/cubit/chat_inbox_cubit.dart';

class _InboxRepository implements RichChatRepository {
  _InboxRepository(this.pages);
  final Map<String, List<RichChannel>> pages;
  final controllers = <String, StreamController<ChatPage<RichChannel>>>{};

  @override
  String get actorId => 'employee';

  @override
  Future<ChatPage<RichChannel>> channels({
    String? cursor,
    String? section,
  }) async => ChatPage(pages[section ?? 'all'] ?? const []);

  @override
  Stream<ChatPage<RichChannel>> watchInbox({String? section}) {
    final key = section ?? 'all';
    return (controllers[key] ??= StreamController.broadcast()).stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'section inbox subscribes to matching live updates and orders ties stably',
    () async {
      final at = DateTime.utc(2026, 9, 9, 10);
      final repository = _InboxRepository({
        'direct': [
          RichChannel(id: 'a', name: 'أ', kind: 'direct', latestActivityAt: at),
          RichChannel(id: 'b', name: 'ب', kind: 'direct', latestActivityAt: at),
        ],
        'group': [RichChannel(id: 'g', name: 'فريق', latestActivityAt: at)],
      });
      final cubit = ChatInboxCubit(repository, section: 'direct');
      await Future<void>.delayed(Duration.zero);
      repository.controllers['direct']!.add(
        ChatPage(repository.pages['direct']!),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.channels.map((channel) => channel.id), ['b', 'a']);

      repository.controllers['direct']!.add(
        ChatPage([
          RichChannel(
            id: 'a',
            name: 'أ',
            kind: 'direct',
            latestActivityAt: at.add(const Duration(minutes: 1)),
          ),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.channels.single.id, 'a');
      expect(repository.controllers.containsKey('group'), isFalse);
      await cubit.close();
      await repository.controllers['direct']!.close();
    },
  );
}
