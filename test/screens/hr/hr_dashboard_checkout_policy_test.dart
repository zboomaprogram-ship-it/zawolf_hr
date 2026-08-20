import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/hr/hr_dashboard.dart').readAsStringSync();

  test('HR dashboard keeps the checkout switch role-protected', () {
    expect(source, contains('CheckoutPolicyController'));
    expect(source, contains('value?.canManage == true'));
    expect(source, contains('_confirmCheckoutPolicyChange'));
    expect(source, contains('سجل المراجعة: آخر تغيير معتمد بواسطة'));
  });

  test('HR dashboard tells users the policy is prospective', () {
    expect(source, contains('لا يتم تعديل أي سجل أو خصم سابق'));
    expect(source, contains('الحضور والطلبات تبقى متاحة'));
  });
}
