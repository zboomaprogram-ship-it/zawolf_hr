import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/attendance_model.dart';
import 'package:zawolf_hr/services/sheets_export_service.dart';

void main() {
  test('attendance export distinguishes a disabled checkout period', () async {
    final csv = await SheetsExportService().exportAttendanceToSheet('audit', [
      _attendance(checkoutPolicyEnabled: false),
    ]);

    expect(csv, contains('حالة الانصراف (Checkout Policy)'));
    expect(csv, contains('لا ينطبق تسجيل الانصراف (سياسة HR)'));
    expect(csv, contains('7'));
    expect(csv, contains('2026-08-20 09:00'));
    expect(csv, isNot(contains('لم يسجل الانصراف')));
  });

  test('historic enabled attendance keeps its recorded checkout', () async {
    final csv = await SheetsExportService().exportAttendanceToSheet('audit', [
      _attendance(checkOutTime: DateTime(2026, 7, 20, 17)),
    ]);

    expect(csv, contains('تم تسجيل الانصراف'));
  });
}

AttendanceModel _attendance({
  bool? checkoutPolicyEnabled,
  DateTime? checkOutTime,
}) => AttendanceModel(
  attendanceId: 'attendance-1',
  userId: 'user-1',
  employeeId: 'EMP-001',
  employeeName: 'Employee',
  locationId: 'hq',
  locationName: 'HQ',
  date: '2026-08-20',
  checkInTime: DateTime(2026, 8, 20, 9),
  checkOutTime: checkOutTime,
  checkInLocation: const GeoPoint(30, 31),
  checkoutPolicyEnabled: checkoutPolicyEnabled,
  checkoutPolicyRevision: checkoutPolicyEnabled == false ? 7 : null,
  checkoutPolicyEvaluatedAt: checkoutPolicyEnabled == false
      ? DateTime(2026, 8, 20, 9)
      : null,
  status: 'present',
);
