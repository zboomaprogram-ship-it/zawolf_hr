import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gateway = File('scripts/attendance-gateway.js').readAsStringSync();
  final client = File(
    'lib/services/attendance_gateway_service.dart',
  ).readAsStringSync();
  final employeeManagement = File(
    'lib/screens/hr/employee_mgmt.dart',
  ).readAsStringSync();

  test('device reset requires an authorised role and an audit reason', () {
    expect(gateway, contains('canResetAttendanceDevice'));
    expect(gateway, contains("'سبب إعادة الضبط مطلوب ويجب أن يكون مختصراً.'"));
    expect(gateway, contains("collection('auditLogs')"));
    expect(gateway, contains("action: 'attendance_device_reset'"));
  });

  test('device reset clears stale binding and removes the old device record', () {
    expect(
      gateway,
      contains('registeredAttendanceDeviceId: admin.firestore.FieldValue.delete()'),
    );
    expect(gateway, contains('if (deviceRef) transaction.delete(deviceRef)'));
    expect(gateway, contains("action: 'device_reset'"));
  });

  test('HR device management routes reset through the guarded gateway', () {
    expect(client, contains("'type': 'resetDevice'"));
    expect(employeeManagement, contains('AttendanceGatewayService().resetDevice'));
    expect(employeeManagement, contains('سبب إعادة الضبط'));
    expect(employeeManagement, isNot(contains('AttendanceSecurityService().reset')));
  });
}
