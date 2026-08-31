import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/hr/attendance_policy_settings_screen.dart',
  ).readAsStringSync();

  test(
    'attendance policy settings keep the checkout switch role-protected',
    () {
      expect(source, contains('CheckoutPolicyController'));
      expect(source, contains('snapshot?.canManage == true'));
      expect(source, contains('_confirmCheckoutPolicyChange'));
      expect(source, contains('سجل المراجعة: آخر تغيير معتمد بواسطة'));
    },
  );

  test('attendance policy settings tell users the policy is prospective', () {
    expect(source, contains('دون تعديل السجلات السابقة'));
    expect(source, contains('تسجيل الحضور وطلبات الإذن تظل متاحة'));
  });
}
