import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_database.dart';
import 'package:zawolf_hr/features/company_os/data/local/company_os_outbox.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_pending_operation.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_os_sync_state.dart';

void main() {
  late CompanyOsDatabase database;
  late CompanyOsOutbox outbox;
  final now = DateTime.utc(2026, 8, 24, 9);

  setUp(() {
    database = CompanyOsDatabase.forTesting(NativeDatabase.memory());
    outbox = CompanyOsOutbox(database);
  });
  tearDown(() => database.close());

  test('restores pending operations after database-backed restart', () async {
    await outbox.put(_operation(now));
    final restored = (await CompanyOsOutbox(
      database,
    ).readyForActor('actor-1', now)).single;
    expect(restored.operationId, 'operation-0001');
    expect(restored.payload, {'subject': 'حاسوب'});
    expect(restored.expectedVersion, 3);
  });

  test('isolates actors, bounds replay, and reconciles conflict', () async {
    for (var index = 0; index < 30; index++) {
      await outbox.put(
        _operation(now, id: 'operation-${index.toString().padLeft(4, '0')}'),
      );
    }
    await outbox.put(_operation(now, id: 'other-0001', actorUid: 'actor-2'));
    expect((await outbox.readyForActor('actor-1', now, limit: 100)).length, 25);
    expect(await outbox.readyForActor('actor-2', now), hasLength(1));

    await outbox.reconcile(
      operationId: 'operation-0000',
      actorUid: 'actor-1',
      state: CompanyOsSyncState.conflict,
      lastSafeCode: 'conflict',
    );
    expect(
      (await outbox.readyForActor(
        'actor-1',
        now,
      )).any((item) => item.operationId == 'operation-0000'),
      isFalse,
    );
    expect(outbox.retryDelay(99), const Duration(minutes: 2));
  });
}

CompanyOsPendingOperation _operation(
  DateTime now, {
  String id = 'operation-0001',
  String actorUid = 'actor-1',
}) => CompanyOsPendingOperation(
  operationId: id,
  actorUid: actorUid,
  operationType: 'ticket_create',
  targetId: 'ticket-1',
  payload: const {'subject': 'حاسوب'},
  expectedVersion: 3,
  state: CompanyOsSyncState.pending,
  attemptCount: 0,
  nextAttemptAt: now,
  createdAt: now,
);
