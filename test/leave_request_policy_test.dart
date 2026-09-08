import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:zawolf_hr/models/leave_model.dart';
import 'package:zawolf_hr/models/leave_type_policy.dart';
import 'package:zawolf_hr/models/user_model.dart';
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
    for (final type in ['sick', 'casual', 'unpaid', 'remote']) {
      expect(
        () => LeaveService.validateRequest(
          request(type: type, start: DateTime(2026, 7, 20)),
          now: now,
        ),
        returnsNormally,
      );
    }
  });

  test('casual, birth, and exam leave enforce their approved limits', () {
    final casual = request(type: 'casual', start: DateTime(2026, 7, 20));
    final threeDays = LeaveModel(
      leaveId: casual.leaveId,
      userId: casual.userId,
      employeeId: casual.employeeId,
      employeeName: casual.employeeName,
      department: casual.department,
      locationId: casual.locationId,
      managerId: casual.managerId,
      leaveType: 'casual',
      startDate: casual.startDate,
      endDate: DateTime(2026, 7, 22),
      numberOfDays: 3,
      reason: casual.reason,
      workHandoverTo: casual.workHandoverTo,
      status: 'pending',
    );
    expect(
      () => LeaveService.validateBalance(
        threeDays,
        LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 15),
      ),
      throwsException,
    );
    expect(LeaveTypePolicy.supportedTypes, contains(LeaveTypePolicy.paternity));
    expect(LeaveTypePolicy.balanceKey(LeaveTypePolicy.paternity), isNull);
    expect(
      () => LeaveService.validateRequest(
        request(type: LeaveTypePolicy.paternity, start: DateTime(2026, 7, 20)),
        now: now,
      ),
      returnsNormally,
    );
    expect(
      () => LeaveService.validateRequest(
        request(type: 'exam', start: DateTime(2026, 7, 29)),
        now: now,
      ),
      throwsException,
    );
  });

  test('sick leave does not require an attachment', () {
    final sick = request(type: 'sick', start: DateTime(2026, 7, 20));
    expect(sick.attachmentUrl, isNull);
    expect(() => LeaveService.validateRequest(sick, now: now), returnsNormally);
  });

  test('sick-to-annual conversion is persisted only when chosen', () {
    final converted = LeaveModel(
      leaveId: 'leave-1',
      userId: 'user',
      employeeId: 'EMP-1',
      employeeName: 'Employee',
      department: 'IT',
      locationId: 'SEG',
      managerId: 'manager',
      leaveType: LeaveTypePolicy.sick,
      startDate: DateTime(2026, 7, 20),
      endDate: DateTime(2026, 7, 20),
      numberOfDays: 1,
      workHandoverTo: 'زميل العمل',
      status: 'pending',
      convertToAnnual: true,
    );
    expect(converted.toFirestore()['convertToAnnual'], true);
    expect(
      request(
        type: LeaveTypePolicy.sick,
        start: DateTime(2026, 7, 20),
      ).toFirestore().containsKey('convertToAnnual'),
      isFalse,
    );
  });

  test('casual leave consumes its own quota and the total leave balance', () {
    expect(LeaveTypePolicy.balanceKey('day_off'), 'daysOff');
    expect(LeaveTypePolicy.balanceKey('casual'), 'casual');
    expect(LeaveTypePolicy.balanceKeys('casual'), ['casual', 'daysOff']);
    expect(LeaveTypePolicy.balanceKey('sick'), isNull);
  });

  test('casual leave requires both balances to be available', () {
    final casual = request(type: 'casual', start: DateTime(2026, 7, 20));
    expect(
      () => LeaveService.validateBalance(
        casual,
        LeaveBalance(annual: 15, sick: 14, casual: 0, daysOff: 10),
      ),
      throwsException,
    );
    expect(
      () => LeaveService.validateBalance(
        casual,
        LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 10),
      ),
      returnsNormally,
    );
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

  test('remote day and long leave require CEO approval', () {
    expect(LeaveTypePolicy.requiresCeoApproval('remote', 1), isTrue);
    expect(LeaveTypePolicy.requiresCeoApproval('day_off', 3), isTrue);
    expect(LeaveTypePolicy.requiresCeoApproval('day_off', 2), isFalse);
  });

  test('long leave uses the manager, HR, then CEO route', () {
    final source = File('lib/services/leave_service.dart').readAsStringSync();

    expect(source, contains("'status': 'pending_hr'"));
    expect(source, contains("? 'pending_ceo'"));
    expect(source, contains("where('employeeId', isEqualTo: 'CEO-100')"));
    expect(source, isNot(contains('_assignedCeoFromApprovalChain')));
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

  test('employees can submit separate non-overlapping day-off requests', () {
    final first = request(type: 'day_off', start: DateTime(2026, 7, 22));
    final second = request(type: 'day_off', start: DateTime(2026, 7, 24));
    expect(LeaveService.dateRangesOverlap(first, second), isFalse);
  });

  test('leave balance excludes Friday and active company days off', () {
    final scheduledDays = LeaveService.countChargeableDays(
      start: DateTime(2026, 8, 27), // Thursday
      end: DateTime(2026, 8, 29), // Saturday; Friday is excluded
      schedule: WorkSchedule(),
    );
    expect(scheduledDays, 2);
    expect(
      LeaveService.countChargeableDays(
        start: DateTime(2026, 8, 27),
        end: DateTime(2026, 8, 29),
        schedule: WorkSchedule(),
        companyDayOffKeys: {'2026-08-29'},
      ),
      1,
    );
  });

  test('overlapping leave dates are still rejected', () {
    final first = request(type: 'day_off', start: DateTime(2026, 7, 22));
    final sameDay = request(type: 'day_off', start: DateTime(2026, 7, 22));
    expect(LeaveService.dateRangesOverlap(first, sameDay), isTrue);
  });

  test('early leave, late arrival, and official leave remain selectable', () {
    final requestScreen =
        File('lib/screens/employee/employee_requests.dart').readAsStringSync();

    expect(requestScreen, contains("_permissionType == 'early_leave'"));
    expect(requestScreen, contains("_permissionType == 'late_arrival'"));
    expect(requestScreen, contains("selectedLeaveType == 'day_off'"));
    expect(
      requestScreen,
      isNot(
        contains('الإذن بالمغادرة المبكرة متاح حتى عند إيقاف تسجيل الانصراف'),
      ),
    );
  });
}
