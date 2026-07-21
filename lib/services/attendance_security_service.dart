import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AttendanceSecurityResult {
  final String deviceId;
  final String deviceLabel;
  final String? legacyDeviceId;
  final bool biometricVerified;
  final bool deviceCredentialFallbackUsed;

  const AttendanceSecurityResult({
    required this.deviceId,
    required this.deviceLabel,
    this.legacyDeviceId,
    required this.biometricVerified,
    this.deviceCredentialFallbackUsed = false,
  });
}

class AttendanceSecurityService {
  final LocalAuthentication _localAuth;
  final DeviceInfoPlugin _deviceInfo;
  static const _attendanceInstallDeviceIdKey =
      'attendance_install_device_id_v2';
  static const _securityChannel = MethodChannel('zawolf_hr/device_security');

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

  Future<AttendanceSecurityResult> verifyForAttendance({
    bool requireBiometric = true,
    bool blockAndroidDeveloperOptions = true,
  }) async {
    final device = await _readDevice();
    await _assertTrustedDevice();
    if (blockAndroidDeveloperOptions) {
      await _assertAndroidDeveloperOptionsDisabled();
    }

    if (!requireBiometric) {
      return AttendanceSecurityResult(
        deviceId: device.id,
        deviceLabel: device.label,
        legacyDeviceId: device.legacyId,
        biometricVerified: false,
      );
    }

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
      deviceId: device.id,
      deviceLabel: device.label,
      legacyDeviceId: device.legacyId,
      biometricVerified: true,
      deviceCredentialFallbackUsed: !hasBiometric,
    );
  }

  Future<void> _assertAndroidDeveloperOptionsDisabled() async {
    if (!Platform.isAndroid) return;
    try {
      final signals = await _securityChannel.invokeMapMethod<String, dynamic>(
        'getSecuritySignals',
      );
      if (signals?['developerOptionsEnabled'] == true ||
          signals?['adbEnabled'] == true) {
        throw Exception(
          'لأمان الحضور، أوقف خيارات المطور وUSB debugging ثم أعد تشغيل التطبيق.',
        );
      }
    } on PlatformException {
      throw Exception(
        'تعذر التحقق من إعدادات أمان الجهاز. أعد المحاولة أو تواصل مع HR.',
      );
    }
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

  Future<({String id, String label, String? legacyId})> _readDevice() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return (
        id: 'android-install-${await _attendanceInstallDeviceId()}',
        label: '${info.manufacturer} ${info.model}'.trim(),
        legacyId: info.id.trim().isEmpty ? null : info.id.trim(),
      );
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return (
        id:
            info.identifierForVendor ??
            'ios-install-${await _attendanceInstallDeviceId()}',
        label: '${info.name} ${info.model}'.trim(),
        legacyId: null,
      );
    }
    final info = await _deviceInfo.deviceInfo;
    return (
      id: '${Platform.operatingSystem}-install-${await _attendanceInstallDeviceId()}',
      label: Platform.operatingSystem,
      legacyId: info.data.toString().hashCode.toString(),
    );
  }

  Future<String> _attendanceInstallDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_attendanceInstallDeviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final parts = List.generate(
      4,
      (_) => random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0'),
    );
    final generated =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${parts.join()}';
    await prefs.setString(_attendanceInstallDeviceIdKey, generated);
    return generated;
  }
}
