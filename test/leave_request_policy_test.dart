import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/leave_model.dart';
import 'package:zawolf_hr/models/leave_type_policy.dart';
import 'package:zawolf_hr/services/leave_service.dart';

LeaveModel request({
  required String type,
  required DateTime start,
  String reason = 'سبب واضح',
}) {
  return LeaveModel(
    leaveId: '',
    userId: 'user',
    employeeId: 'EMP-1',
    employeeName: 'Employee',
    department: 'IT',
    locationId: 'SEG',
    managerId: 'manager',
    leaveType: type,
    startDate: start,
    endDate: start,
    numberOfDays: 1,
    reason: reason,
    workHandoverTo: 'زميل العمل',
    status: 'pending',
  );
}

void main() {
  final now = DateTime(2026, 7, 20, 9);

  test('normal day off requires two calendar days notice', () {
    expect(
      () => LeaveService.validateRequest(
        request(type: 'day_off', start: DateTime(2026, 7, 21)),
        now: now,
      ),
      throwsException,
    );
    expect(
      () => LeaveService.validateRequest(
        request(type: 'day_off', start: DateTime(2026, 7, 22)),
        now: now,
      ),
      returnsNormally,
    );
  });

  test('sick and casual leave can be requested the same morning', () {
    for (final type in ['sick', 'casual', 'unpaid', 'exam', 'remote']) {
      expect(
        () => LeaveService.validateRequest(
          request(type: type, start: DateTime(2026, 7, 20)),
          now: now,
        ),
        returnsNormally,
      );
    }
  });

  test('sick leave does not require an attachment', () {
    final sick = request(type: 'sick', start: DateTime(2026, 7, 20));
    expect(sick.attachmentUrl, isNull);
    expect(() => LeaveService.validateRequest(sick, now: now), returnsNormally);
  });

  test('normal and casual leave share the total leave balance', () {
    expect(LeaveTypePolicy.balanceKey('day_off'), 'daysOff');
    expect(LeaveTypePolicy.balanceKey('casual'), 'daysOff');
    expect(LeaveTypePolicy.balanceKey('sick'), isNull);
  });

  test('unpaid leave deducts salary but not leave balance', () {
    expect(LeaveTypePolicy.balanceKey('unpaid'), isNull);
    expect(LeaveTypePolicy.requiresFullDaySalaryDeduction('unpaid'), isTrue);
  });

  test('exam leave deducts neither salary nor leave balance', () {
    expect(LeaveTypePolicy.balanceKey('exam'), isNull);
    expect(LeaveTypePolicy.requiresFullDaySalaryDeduction('exam'), isFalse);
  });

  test('remote day deducts neither salary nor leave balance', () {
    expect(LeaveTypePolicy.balanceKey('remote'), isNull);
    expect(LeaveTypePolicy.requiresFullDaySalaryDeduction('remote'), isFalse);
    expect(LeaveTypePolicy.supportedTypes, contains('remote'));
  });

  test('every leave request requires a reason', () {
    expect(
      () => LeaveService.validateRequest(
        request(type: 'casual', start: DateTime(2026, 7, 20), reason: ' '),
        now: now,
      ),
      throwsException,
    );
  });
}
