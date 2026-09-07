import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/attendance_gateway_service.dart';
import 'package:zawolf_hr/features/attendance_checkin/presentation/attendance_outcome_mapper.dart';
import 'dart:io';

void main() {
  const mapper = AttendanceOutcomeMapper();

  test('checkout disabled receives a clear Arabic business outcome', () {
    expect(mapper.messageFor('checkout_disabled'), contains('غير مفعّل'));
  });

  test('gateway and Firebase technical details cannot be rendered', () {
    for (final status in <String>[
      'cloud_firestore/permission-denied',
      'FirebaseException: unavailable',
      'https://internal.example/token',
    ]) {
      final message = mapper.messageFor(status).toLowerCase();
      expect(message, isNot(contains('firebase')));
      expect(message, isNot(contains('firestore')));
      expect(message, isNot(contains('http')));
      expect(message, isNot(contains('token')));
    }
  });

  test('gateway exception renders only safe Arabic status', () {
    const error = AttendanceGatewayException(
      'permission_denied',
      'FirebaseException: cloud_firestore/permission-denied',
    );

    expect(error.toString(), contains('لا تملك صلاحية'));
    expect(error.toString(), isNot(contains('Firebase')));
    expect(error.toString(), isNot(contains('permission-denied')));
  });

  test(
    'employee dashboard does not use raw errors as its attendance message',
    () {
      final source = File(
        'lib/screens/employee/employee_dashboard.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('return raw;')));
      expect(source, contains('لن يُسجَّل حضور مكرر'));
    },
  );

  test('employee dashboard keeps the gateway device-binding outcome', () {
    final source = File(
      'lib/screens/employee/employee_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains('if (error is AttendanceGatewayException)'));
    expect(source, contains('return error.userMessage;'));
  });
}
