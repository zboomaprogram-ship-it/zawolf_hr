import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/local/checkin_outbox_database.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_action.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/pending_check_in.dart';

void main() {
  late CheckInOutboxDatabase database;
  late DriftCheckInOutbox outbox;

  setUp(() {
    database = CheckInOutboxDatabase.forTesting(NativeDatabase.memory());
    outbox = DriftCheckInOutbox(database);
  });

  tearDown(() => database.close());

  test(
    'persists a pending action with its original immutable evidence',
    () async {
      final item = _pending('employee-a', 'employee-a_2026-08-20');

      await outbox.put(item);

      final restored = await outbox.getForEmployee('employee-a');
      expect(restored?.action.actionId, item.action.actionId);
      expect(restored?.action.capturedAt, item.action.capturedAt);
      expect(restored?.action.payload, item.action.payload);
    },
  );

  test('never exposes or removes another employee pending action', () async {
    final itemA = _pending('employee-a', 'employee-a_2026-08-20');
    final itemB = _pending('employee-b', 'employee-b_2026-08-20');
    await outbox.put(itemA);
    await outbox.put(itemB);

    expect(
      (await outbox.getForEmployee('employee-a'))?.action.actionId,
      itemA.action.actionId,
    );
    expect(
      (await outbox.getForEmployee('employee-b'))?.action.actionId,
      itemB.action.actionId,
    );

    await outbox.remove(itemA.action.actionId, 'employee-b');

    expect(
      (await outbox.getForEmployee('employee-a'))?.action.actionId,
      itemA.action.actionId,
    );
    expect(
      (await outbox.getForEmployee('employee-b'))?.action.actionId,
      itemB.action.actionId,
    );
  });
}

PendingCheckIn _pending(String employeeId, String actionId) => PendingCheckIn(
  action: CheckInAction(
    actionId: actionId,
    employeeScopeId: employeeId,
    dateKey: '2026-08-20',
    capturedAt: DateTime.utc(2026, 8, 20, 8),
    payload: const {'latitude': 30.1, 'deviceId': 'safe-device'},
  ),
  state: PendingCheckInState.pending,
  attemptCount: 3,
  updatedAt: DateTime.utc(2026, 8, 20, 8, 1),
);
