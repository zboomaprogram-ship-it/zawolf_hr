import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_view_query.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_visibility_record.dart';

void main() {
  final record = RequestVisibilityRecord(
    stableId: 'r1',
    sourceType: RequestSourceType.lateArrivalDeduction,
    employeeId: 'e1',
    approvalStage: RequestApprovalStage.finalised,
    lifecycleState: RequestLifecycleState.confirmed,
    occurredAt: DateTime.utc(2026, 7, 22),
    sourceReference: 'deductions/r1',
  );

  test(
    'confirmed salary deductions remain visible in history and deductions',
    () {
      final scope = RequestActorScope(actorId: 'hr', role: 'hr');
      final history = RequestViewQuery(
        actorScope: scope,
        tab: RequestViewTab.history,
        fromDate: DateTime.utc(2026),
        toDate: DateTime.utc(2026, 12, 31),
      );
      final deductions = RequestViewQuery(
        actorScope: scope,
        tab: RequestViewTab.deductions,
        fromDate: DateTime.utc(2026),
        toDate: DateTime.utc(2026, 12, 31),
      );

      expect(history.matches(record), isTrue);
      expect(deductions.matches(record), isTrue);
    },
  );
}
