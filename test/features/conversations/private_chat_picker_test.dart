import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/rich_chat_repository.dart';
import 'package:zawolf_hr/features/conversations/presentation/pages/direct_chat_picker_page.dart';

class _PickerRepository implements RichChatRepository {
  var startedTarget = '';

  @override
  String get actorId => 'employee';

  @override
  Future<ChatPage<ChatDepartment>> contactDepartments({String? cursor}) async =>
      const ChatPage([
        ChatDepartment(id: 'sales', name: 'المبيعات', eligibleCount: 1),
      ]);

  @override
  Future<ChatPage<ChatUser>> eligibleContacts({
    String? department,
    String? section,
    String? cursor,
  }) async {
    if (department != 'sales') return const ChatPage([]);
    return const ChatPage([
      ChatUser(id: 'peer', name: 'زميلة المبيعات', department: 'المبيعات'),
    ]);
  }

  @override
  Future<RichChannel> startDirect(
    String targetUserId, {
    String? operationId,
  }) async {
    startedTarget = targetUserId;
    if (targetUserId != 'peer') throw const ChatFailure('access_denied');
    return const RichChannel(
      id: 'direct:employee:peer',
      name: 'زميلة المبيعات',
      kind: 'direct',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'department-first picker hides contacts until a department is selected and opens the authorized direct chat',
    (tester) async {
      final repository = _PickerRepository();
      await tester.pumpWidget(
        MaterialApp(home: DirectChatPickerPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('زميلة المبيعات'), findsNothing);

      await tester.tap(find.text('المبيعات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('زميلة المبيعات'));
      await tester.pumpAndSettle();
      expect(repository.startedTarget, 'peer');
    },
  );
}
