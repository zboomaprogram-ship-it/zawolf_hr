import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/utils/user_facing_error.dart';

void main() {
  test('quota errors explain that the request was not saved', () {
    final message = userFacingError(
      FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted'),
    );

    expect(message, contains('لم يتم حفظ الطلب'));
  });

  test('service interruption errors give a retry action', () {
    final message = userFacingError(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    expect(message, contains('حاول مرة أخرى'));
  });

  test('never exposes raw Firebase details from an arbitrary exception', () {
    final message = userFacingError(
      Exception('cloud_firestore/permission-denied: internal path /users/x'),
      fallback: 'تعذر تنفيذ العملية بأمان.',
    );

    expect(message, 'تعذر تنفيذ العملية بأمان.');
    expect(message, isNot(contains('cloud_firestore')));
  });

  test('keeps application-authored Arabic business guidance', () {
    expect(
      userFacingError(Exception('هذا الحساب مربوط بجهاز حضور آخر.')),
      'هذا الحساب مربوط بجهاز حضور آخر.',
    );
  });
}
