import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/attendance_correction_draft.dart';

void main() {
  test('correction draft retains a stable operation id for retry dedupe', () {
    final draft = AttendanceCorrectionDraft.create(
      attendanceId: 'user-1_2026-08-20',
      originalCheckIn: DateTime(2026, 8, 20, 9, 40),
      requestedCheckIn: DateTime(2026, 8, 20, 9),
      reason: 'ازدحام مروري شديد',
      operationId: 'attendance-correction-1',
    );
    expect(draft.operationId, 'attendance-correction-1');
  });

  test('correction cannot move an attendance record to a different day', () {
    expect(
      () => AttendanceCorrectionDraft.create(
        attendanceId: 'user-1_2026-08-20',
        originalCheckIn: DateTime(2026, 8, 20, 9, 40),
        requestedCheckIn: DateTime(2026, 8, 19, 9),
        reason: 'ازدحام مروري شديد',
        operationId: 'attendance-correction-1',
      ),
      throwsArgumentError,
    );
  });
}
