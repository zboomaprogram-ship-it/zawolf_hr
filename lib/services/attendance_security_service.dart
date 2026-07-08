import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:local_auth/local_auth.dart';

class AttendanceSecurityResult {
  final String deviceId;
  final String deviceLabel;
  final bool biometricVerified;
  final bool deviceCredentialFallbackUsed;

  const AttendanceSecurityResult({
    required this.deviceId,
    required this.deviceLabel,
    required this.biometricVerified,
    this.deviceCredentialFallbackUsed = false,
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

  static String deviceDocumentId(String deviceId) {
    final trimmed = deviceId.trim();
    if (trimmed.isEmpty) return 'unknown-device';
    return trimmed.replaceAll('/', '_');
  }

  Future<AttendanceSecurityResult> verifyForAttendance() async {
    final device = await _readDevice();
    await _assertTrustedDevice();

    final availableBiometrics = await _localAuth.getAvailableBiometrics();
    final hasBiometric = availableBiometrics.isNotEmpty;
    final isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!hasBiometric && !isDeviceSupported) {
      throw Exception('يجب تفعيل وسيلة قفل آمنة للجهاز قبل تسجيل الحضور.');
    }

    bool verified = false;
    try {
      verified = await _localAuth.authenticate(
        localizedReason: hasBiometric
            ? 'استخدم البصمة أو الوجه فقط لتسجيل الحضور أو الانصراف'
            : 'هذا الجهاز لا يدعم بصمة/وجه. استخدم قفل الجهاز وسيتم إرسال الحركة لمراجعة HR.',
        biometricOnly: hasBiometric,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('NotEnrolled') ||
          errorStr.contains('noCredentialsSet')) {
        throw Exception(
          'يجب تفعيل بصمة/وجه أو قفل شاشة آمن في إعدادات الهاتف قبل تسجيل الحضور.',
        );
      }
      throw Exception('خطأ في المصادقة: $errorStr');
    }

    if (!verified) {
      throw Exception('فشل التحقق من هوية الجهاز.');
    }

    return AttendanceSecurityResult(
      deviceId: device.$1,
      deviceLabel: device.$2,
      biometricVerified: true,
      deviceCredentialFallbackUsed: !hasBiometric,
    );
  }

  Future<void> _assertTrustedDevice() async {
    try {
      final isNotTrusted = await JailbreakRootDetection.instance.isNotTrust;
      final isJailBroken = await JailbreakRootDetection.instance.isJailBroken;
      final isRealDevice = await JailbreakRootDetection.instance.isRealDevice;
      if (isNotTrusted || isJailBroken || !isRealDevice) {
        throw Exception(
          'لا يمكن تسجيل الحضور من جهاز مكسور الحماية أو غير موثوق. استخدم جهازاً آمناً أو تواصل مع HR.',
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('غير موثوق')) {
        rethrow;
      }
      throw Exception(
        'تعذر التحقق من أمان الجهاز. أعد المحاولة أو تواصل مع HR.',
      );
    }
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
