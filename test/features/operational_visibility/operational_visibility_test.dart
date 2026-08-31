import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/entities/operational_visibility_setting.dart';

void main() {
  test('hidden operational account remains active and reversible', () {
    const setting = OperationalVisibilitySetting(
      employeeUserId: 'test-user',
      hiddenFromAttendance: true,
      version: 3,
      reasonAr: 'حساب اختبار',
    );
    expect(setting.hiddenFromAttendance, isTrue);
    expect(setting.remainsActiveAccount, isTrue);
  });
}
