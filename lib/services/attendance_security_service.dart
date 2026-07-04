import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

class AttendanceSecurityResult {
  final String deviceId;
  final String deviceLabel;
  final bool biometricOrDeviceCredentialVerified;

  const AttendanceSecurityResult({
    required this.deviceId,
    required this.deviceLabel,
    required this.biometricOrDeviceCredentialVerified,
  });
}

class AttendanceSecurityService {
  final LocalAuthentication _localAuth;
  final DeviceInfoPlugin _deviceInfo;

  AttendanceSecurityService({
    LocalAuthentication? localAuth,
    DeviceInfoPlugin? deviceInfo,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<AttendanceSecurityResult> verifyForAttendance() async {
    final device = await _readDevice();
    final canAuthenticate =
        await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();

    if (!canAuthenticate) {
      throw Exception(
        'يجب تفعيل بصمة/وجه أو كلمة مرور للجهاز قبل تسجيل الحضور.',
      );
    }

    final verified = await _localAuth.authenticate(
      localizedReason: 'تحقق من هويتك لتسجيل الحضور أو الانصراف',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );

    if (!verified) {
      throw Exception('فشل التحقق من هوية الجهاز.');
    }

    return AttendanceSecurityResult(
      deviceId: device.$1,
      deviceLabel: device.$2,
      biometricOrDeviceCredentialVerified: true,
    );
  }

  Future<(String, String)> _readDevice() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return (info.id, '${info.manufacturer} ${info.model}'.trim());
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return (
        info.identifierForVendor ?? 'unknown-ios-device',
        '${info.name} ${info.model}'.trim(),
      );
    }
    final info = await _deviceInfo.deviceInfo;
    return (info.data.toString().hashCode.toString(), Platform.operatingSystem);
  }
}
