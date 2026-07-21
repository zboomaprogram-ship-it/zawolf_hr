import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/app_security_policy_service.dart';

void main() {
  test('security policy preserves force-update and attendance controls', () {
    final policy = AppSecurityPolicy.fromMap({
      'forceUpdateEnabled': true,
      'minimumAndroidBuild': 43,
      'minimumIosBuild': 44,
      'minimumAttendanceProtocolVersion': 2,
      'blockAndroidDeveloperOptions': true,
      'androidStoreUrl': 'https://example.com/android',
      'iosStoreUrl': 'https://example.com/ios',
      'messageAr': 'حدث التطبيق',
    });

    expect(policy.forceUpdateEnabled, isTrue);
    expect(policy.minimumAndroidBuild, 43);
    expect(policy.minimumIosBuild, 44);
    expect(policy.minimumAttendanceProtocolVersion, 2);
    expect(policy.blockAndroidDeveloperOptions, isTrue);
    expect(policy.toMap()['messageAr'], 'حدث التطبيق');
  });

  test('security policy defaults protect Android developer settings', () {
    const policy = AppSecurityPolicy();

    expect(policy.forceUpdateEnabled, isFalse);
    expect(policy.minimumAttendanceProtocolVersion, 0);
    expect(policy.blockAndroidDeveloperOptions, isTrue);
  });
}
