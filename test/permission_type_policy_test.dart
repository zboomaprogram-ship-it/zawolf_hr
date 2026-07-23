import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/permission_type_policy.dart';

void main() {
  test('deductible permission opens only after regular quota is exhausted', () {
    expect(
      PermissionTypePolicy.isRegularQuotaExhausted(usedCount: 1, usedHours: 4),
      isFalse,
    );
    expect(
      PermissionTypePolicy.isRegularQuotaExhausted(usedCount: 2, usedHours: 4),
      isTrue,
    );
    expect(
      PermissionTypePolicy.isRegularQuotaExhausted(usedCount: 1, usedHours: 5),
      isTrue,
    );
  });

  test('one or two hours deduct a quarter day', () {
    expect(PermissionTypePolicy.deductibleDayFraction(60), 0.25);
    expect(PermissionTypePolicy.deductibleDayFraction(120), 0.25);
  });

  test('three or four hours deduct a half day', () {
    expect(PermissionTypePolicy.deductibleDayFraction(180), 0.5);
    expect(PermissionTypePolicy.deductibleDayFraction(240), 0.5);
  });

  test('permissions longer than four hours are rejected', () {
    expect(
      () => PermissionTypePolicy.deductibleDayFraction(300),
      throwsArgumentError,
    );
  });

  test('mid-shift exit has a clear employee-facing label', () {
    expect(
      PermissionTypePolicy.arabicLabel(PermissionTypePolicy.midShiftExit),
      'مغادرة والعودة أثناء الدوام',
    );
  });
}
