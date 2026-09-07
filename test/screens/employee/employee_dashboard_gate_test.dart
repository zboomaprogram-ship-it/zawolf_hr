import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_policy.dart';
import 'package:zawolf_hr/models/company_day_off_status.dart';
import 'package:zawolf_hr/screens/employee/widgets/checkin_action_state.dart';
import 'package:zawolf_hr/services/attendance_service.dart'
    show AttendanceActionIntent;

CheckInGateInputs _inputs({
  DateTime? now,
  bool hasTodayRecord = true,
  bool hasCheckedIn = false,
  bool hasCheckedOut = false,
  AttendancePolicyConfig? policyConfig,
  String? scheduleStart,
  String? scheduleEnd,
  DateTime? checkoutAllowedFromOverride,
  bool checkoutEnabled = true,
  CompanyDayOffStatus dayOffStatus = const CompanyDayOffStatus.workDay(),
  bool actionLoading = false,
  bool pilotAwaitingConfirmation = false,
}) {
  final at = now ?? DateTime(2026, 8, 23, 12);
  return CheckInGateInputs(
    now: at,
    hasTodayRecord: hasTodayRecord,
    hasCheckedIn: hasCheckedIn,
    hasCheckedOut: hasCheckedOut,
    policyConfig: policyConfig ?? const AttendancePolicyConfig(),
    scheduleStartTime: scheduleStart,
    scheduleEndTime: scheduleEnd,
    checkoutAllowedFromOverride: checkoutAllowedFromOverride,
    checkoutEnabled: checkoutEnabled,
    dayOffStatus: dayOffStatus,
    actionLoading: actionLoading,
    pilotAwaitingConfirmation: pilotAwaitingConfirmation,
  );
}

void main() {
  test('active Developer Tools access can expose the attendance action for an excluded test account', () {
    final source = File(
      'lib/screens/employee/employee_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains('DeveloperToolsAccess.isAvailableForCurrentUser'));
    expect(source, contains('user.excludeFromAttendanceReports && !_developerAttendanceAccess'));
  });

  test('before check-in window the action is disabled with open time', () {
    // Policy opens at 07:00; at 06:00 check-in is not open yet.
    final state = computeCheckInAction(
      _inputs(now: DateTime(2026, 8, 23, 6)),
    );
    expect(state.disabled, isTrue);
    expect(state.title, 'يفتح 07:00');
    expect(state.subtitle, 'CHECK IN LATER');
    expect(state.expectedAction, AttendanceActionIntent.checkIn);
  });

  test('inside the window without a record offers check-in', () {
    final state = computeCheckInAction(
      _inputs(now: DateTime(2026, 8, 23, 9)),
    );
    expect(state.disabled, isFalse);
    expect(state.title, 'تسجيل حضور');
    expect(state.subtitle, 'CHECK IN');
    expect(state.icon.codePoint, Icons.fingerprint.codePoint);
  });

  test('checked in before checkout allowance stays disabled', () {
    final state = computeCheckInAction(
      _inputs(
        now: DateTime(2026, 8, 23, 14),
        hasCheckedIn: true,
        scheduleEnd: '17:00',
      ),
    );
    expect(state.disabled, isTrue);
    expect(state.title, 'يفتح 17:00');
    expect(state.subtitle, 'CHECK OUT AT 17:00');
  });

  test('checked in after checkout allowance offers check-out', () {
    final state = computeCheckInAction(
      _inputs(
        now: DateTime(2026, 8, 23, 18),
        hasCheckedIn: true,
        scheduleEnd: '17:00',
      ),
    );
    expect(state.disabled, isFalse);
    expect(state.title, 'تسجيل انصراف');
    expect(state.subtitle, 'CHECK OUT');
    expect(state.expectedAction, AttendanceActionIntent.checkOut);
  });

  test('checkout policy disabled hides checkout but keeps record', () {
    final state = computeCheckInAction(
      _inputs(
        now: DateTime(2026, 8, 23, 18),
        hasCheckedIn: true,
        checkoutEnabled: false,
      ),
    );
    expect(state.disabled, isTrue);
    expect(state.title, 'تم تسجيل الحضور');
    expect(state.subtitle, 'CHECK-IN SAVED');
  });

  test('completed day locks the button', () {
    final state = computeCheckInAction(_inputs(hasCheckedOut: true));
    expect(state.disabled, isTrue);
    expect(state.title, 'اكتمل اليوم');
    expect(state.subtitle, 'COMPLETED');
    expect(state.icon.codePoint, Icons.lock_clock.codePoint);
  });

  test('day off blocks first check-in only', () {
    final blocked = computeCheckInAction(
      _inputs(
        hasTodayRecord: false,
        dayOffStatus: const CompanyDayOffStatus(
          isDayOff: true,
          reason: 'عطلة',
        ),
      ),
    );
    expect(blocked.disabled, isTrue);
    expect(blocked.title, 'عطلة اليوم');

    final checkedInOnDayOff = computeCheckInAction(
      _inputs(
        now: DateTime(2026, 8, 23, 18),
        hasTodayRecord: true,
        hasCheckedIn: true,
        dayOffStatus: const CompanyDayOffStatus(
          isDayOff: true,
          reason: 'عطلة',
        ),
      ),
    );
    expect(checkedInOnDayOff.disabled, isFalse);
    expect(checkedInOnDayOff.title, 'تسجيل انصراف');
  });

  test('after latest checkout time the day is closed', () {
    final state = computeCheckInAction(
      _inputs(now: DateTime(2026, 8, 23, 23, 30), hasCheckedIn: true),
    );
    expect(state.disabled, isTrue);
    expect(state.title, 'انتهى اليوم');
    expect(state.subtitle, 'CHECKOUT CLOSED');
  });

  test('loading and pending pilot sync disable the action', () {
    final loading = computeCheckInAction(_inputs(actionLoading: true));
    expect(loading.disabled, isTrue);

    final pilotPending =
        computeCheckInAction(_inputs(pilotAwaitingConfirmation: true));
    expect(pilotPending.disabled, isTrue);
  });
}
