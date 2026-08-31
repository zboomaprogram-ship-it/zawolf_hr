import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/data/local/workspace_operation_outbox_database.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_operation.dart';

void main() {
  late WorkspaceOperationOutboxDatabase database;
  late DriftWorkspaceOperationOutbox outbox;

  setUp(() {
    database = WorkspaceOperationOutboxDatabase.forTesting(
      NativeDatabase.memory(),
    );
    outbox = DriftWorkspaceOperationOutbox(database);
  });
  tearDown(() => database.close());

  test(
    'persists a pending mutation and restores its original operation ID',
    () async {
      final operation = _operation(id: 'operation-1', actorId: 'employee-a');
      await outbox.put(operation);

      final restored = (await outbox.pendingForActor('employee-a')).single;
      expect(restored.id, operation.id);
      expect(restored.expectedVersion, 'v7');
      expect(restored.payload, operation.payload);
    },
  );

  test('never replays or removes another employee operation', () async {
    final first = _operation(id: 'operation-1', actorId: 'employee-a');
    final second = _operation(id: 'operation-2', actorId: 'employee-b');
    await outbox.put(first);
    await outbox.put(second);

    await outbox.remove(first.id, 'employee-b');
    expect((await outbox.pendingForActor('employee-a')).single.id, first.id);
    expect((await outbox.pendingForActor('employee-b')).single.id, second.id);
  });
}

WorkspaceOperation _operation({required String id, required String actorId}) =>
    WorkspaceOperation(
      id: id,
      actorId: actorId,
      resourceId: 'resource-1',
      kind: WorkspaceOperationKind.sheetEdit,
      createdAt: DateTime.utc(2026, 8, 22, 9),
      expectedVersion: 'v7',
      payload: const {'tabName': 'Sheet1', 'cells': <Object?>[]},
    );
