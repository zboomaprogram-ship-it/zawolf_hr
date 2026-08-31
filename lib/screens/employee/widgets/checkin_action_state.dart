import 'package:flutter/material.dart';

import '../../../models/attendance_policy.dart';
import '../../../models/company_day_off_status.dart';
import '../../../services/attendance_service.dart'
    show AttendanceActionIntent;

/// Inputs for the dashboard check-in/out gate. Pure data; no services.
class CheckInGateInputs {
  const CheckInGateInputs({
    required this.now,
    required this.hasTodayRecord,
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    required this.policyConfig,
    required this.scheduleStartTime,
    required this.scheduleEndTime,
    required this.checkoutAllowedFromOverride,
    required this.checkoutEnabled,
    required this.dayOffStatus,
    required this.actionLoading,
    required this.pilotAwaitingConfirmation,
  });

  final DateTime now;
  final bool hasTodayRecord;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final AttendancePolicyConfig policyConfig;
  final String? scheduleStartTime;
  final String? scheduleEndTime;
  final DateTime? checkoutAllowedFromOverride;
  final bool checkoutEnabled;
  final CompanyDayOffStatus dayOffStatus;
  final bool actionLoading;
  final bool pilotAwaitingConfirmation;
}

/// Resolved radar-button presentation and gating for the current moment.
///
/// Behavior is extracted verbatim from the original
/// `employee_dashboard.dart` build method; see characterization tests in
/// `test/screens/employee/employee_dashboard_gate_test.dart`.
class CheckInActionState {
  const CheckInActionState({
    required this.disabled,
    required this.expectedAction,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final bool disabled;
  final AttendanceActionIntent expectedAction;
  final String title;
  final String subtitle;
  final IconData icon;
}

String formatGateTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

CheckInActionState computeCheckInAction(CheckInGateInputs input) {
  final now = input.now;
  final policyConfig = input.policyConfig;

  final policyCheckInOpenAt = AttendancePolicy.parseTimeOnDate(
    now,
    policyConfig.checkInOpenTime,
  );
  final employeeStartAt = AttendancePolicy.parseTimeOnDate(
    now,
    input.scheduleStartTime ?? policyConfig.defaultStartTime,
  );
  final checkInOpenAt = employeeStartAt.isBefore(policyCheckInOpenAt)
      ? employeeStartAt
      : policyCheckInOpenAt;
  final checkoutAllowedFrom =
      input.checkoutAllowedFromOverride ??
      AttendancePolicy.parseTimeOnDate(
        now,
        input.scheduleEndTime ?? policyConfig.defaultEndTime,
      );
  final latestCheckoutAt = AttendancePolicy.parseTimeOnDate(
    now,
    policyConfig.latestCheckoutTime,
  );
  final checkInNotOpenYet =
      !input.hasCheckedIn && now.isBefore(checkInOpenAt);
  final checkoutNotOpenYet =
      input.hasCheckedIn &&
      !input.hasCheckedOut &&
      now.isBefore(checkoutAllowedFrom);
  final checkoutExpired =
      input.hasCheckedIn &&
      !input.hasCheckedOut &&
      now.isAfter(latestCheckoutAt);
  final checkoutPolicyDisabled =
      input.hasCheckedIn && !input.hasCheckedOut && !input.checkoutEnabled;
  final checkInDisabledForDayOff =
      !input.hasTodayRecord && input.dayOffStatus.isDayOff;
  final actionDisabled =
      input.actionLoading ||
      input.pilotAwaitingConfirmation ||
      input.hasCheckedOut ||
      checkInDisabledForDayOff ||
      checkInNotOpenYet ||
      checkoutPolicyDisabled ||
      checkoutNotOpenYet ||
      checkoutExpired;
  final expectedAction = input.hasCheckedIn
      ? AttendanceActionIntent.checkOut
      : AttendanceActionIntent.checkIn;
  final title = input.hasCheckedOut
      ? 'اكتمل اليوم'
      : checkInDisabledForDayOff
      ? 'عطلة اليوم'
      : checkInNotOpenYet
      ? 'يفتح ${formatGateTime(checkInOpenAt)}'
      : checkoutExpired
      ? 'انتهى اليوم'
      : checkoutPolicyDisabled
      ? 'تم تسجيل الحضور'
      : checkoutNotOpenYet
      ? 'يفتح ${formatGateTime(checkoutAllowedFrom)}'
      : input.hasCheckedIn
      ? 'تسجيل انصراف'
      : 'تسجيل حضور';
  final subtitle = input.hasCheckedOut
      ? 'COMPLETED'
      : checkInDisabledForDayOff
      ? 'DAY OFF'
      : checkInNotOpenYet
      ? 'CHECK IN LATER'
      : checkoutExpired
      ? 'CHECKOUT CLOSED'
      : checkoutPolicyDisabled
      ? 'CHECK-IN SAVED'
      : checkoutNotOpenYet
      ? 'CHECK OUT AT ${formatGateTime(checkoutAllowedFrom)}'
      : input.hasCheckedIn
      ? 'CHECK OUT'
      : 'CHECK IN';
  final icon = input.hasCheckedOut
      ? Icons.lock_clock
      : checkInDisabledForDayOff
      ? Icons.event_busy
      : checkInNotOpenYet ||
            checkoutPolicyDisabled ||
            checkoutNotOpenYet ||
            checkoutExpired
      ? Icons.schedule
      : input.hasCheckedIn
      ? Icons.logout
      : Icons.fingerprint;

  return CheckInActionState(
    disabled: actionDisabled,
    expectedAction: expectedAction,
    title: title,
    subtitle: subtitle,
    icon: icon,
  );
}
