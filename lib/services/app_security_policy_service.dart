import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSecurityPolicy {
  static const currentAttendanceProtocolVersion = 2;

  final bool forceUpdateEnabled;
  final int minimumAndroidBuild;
  final int minimumIosBuild;
  final int minimumAttendanceProtocolVersion;
  final bool blockAndroidDeveloperOptions;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String messageAr;

  const AppSecurityPolicy({
    this.forceUpdateEnabled = false,
    this.minimumAndroidBuild = 0,
    this.minimumIosBuild = 0,
    this.minimumAttendanceProtocolVersion = 0,
    this.blockAndroidDeveloperOptions = true,
    this.androidStoreUrl =
        'https://play.google.com/store/apps/details?id=com.zbooma.zawolfhr',
    this.iosStoreUrl = '',
    this.messageAr =
        'يتوفر تحديث أمني مهم. حدّث التطبيق للمتابعة وتسجيل الحضور بأمان.',
  });

  factory AppSecurityPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppSecurityPolicy();
    return AppSecurityPolicy(
      forceUpdateEnabled: map['forceUpdateEnabled'] as bool? ?? false,
      minimumAndroidBuild: (map['minimumAndroidBuild'] as num?)?.toInt() ?? 0,
      minimumIosBuild: (map['minimumIosBuild'] as num?)?.toInt() ?? 0,
      minimumAttendanceProtocolVersion:
          (map['minimumAttendanceProtocolVersion'] as num?)?.toInt() ?? 0,
      blockAndroidDeveloperOptions:
          map['blockAndroidDeveloperOptions'] as bool? ?? true,
      androidStoreUrl:
          map['androidStoreUrl'] as String? ??
          const AppSecurityPolicy().androidStoreUrl,
      iosStoreUrl: map['iosStoreUrl'] as String? ?? '',
      messageAr:
          map['messageAr'] as String? ?? const AppSecurityPolicy().messageAr,
    );
  }

  Map<String, dynamic> toMap() => {
    'forceUpdateEnabled': forceUpdateEnabled,
    'minimumAndroidBuild': minimumAndroidBuild,
    'minimumIosBuild': minimumIosBuild,
    'minimumAttendanceProtocolVersion': minimumAttendanceProtocolVersion,
    'blockAndroidDeveloperOptions': blockAndroidDeveloperOptions,
    'androidStoreUrl': androidStoreUrl,
    'iosStoreUrl': iosStoreUrl,
    'messageAr': messageAr,
  };

  int minimumBuildForCurrentPlatform() {
    if (kIsWeb) return 0;
    if (Platform.isAndroid) return minimumAndroidBuild;
    if (Platform.isIOS) return minimumIosBuild;
    return 0;
  }

  String storeUrlForCurrentPlatform() {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return androidStoreUrl;
    if (Platform.isIOS) return iosStoreUrl;
    return '';
  }
}

class AppSecurityStatus {
  final AppSecurityPolicy policy;
  final int currentBuild;
  final String version;

  const AppSecurityStatus({
    required this.policy,
    required this.currentBuild,
    required this.version,
  });

  bool get updateRequired =>
      policy.forceUpdateEnabled &&
      currentBuild < policy.minimumBuildForCurrentPlatform();
}

class AppSecurityPolicyService {
  AppSecurityPolicyService._();

  static final instance = AppSecurityPolicyService._();
  static const _cachePrefix = 'app_security_policy_';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<AppSecurityStatus> loadStatus({bool serverOnly = false}) async {
    final package = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(package.buildNumber) ?? 0;
    AppSecurityPolicy? policy;

    try {
      final snapshot = await _db
          .collection('publicConfig')
          .doc('appSecurity')
          .get(
            GetOptions(
              source: serverOnly ? Source.server : Source.serverAndCache,
            ),
          );
      policy = AppSecurityPolicy.fromMap(snapshot.data());
      await _cache(policy);
    } catch (_) {
      policy = await _loadCached();
    }

    return AppSecurityStatus(
      policy: policy ?? const AppSecurityPolicy(),
      currentBuild: currentBuild,
      version: package.version,
    );
  }

  Future<AppSecurityPolicy> assertAttendanceClientAllowed() async {
    final status = await loadStatus();
    if (status.updateRequired) {
      throw Exception(status.policy.messageAr);
    }
    if (AppSecurityPolicy.currentAttendanceProtocolVersion <
        status.policy.minimumAttendanceProtocolVersion) {
      throw Exception(status.policy.messageAr);
    }
    return status.policy;
  }

  Future<void> _cache(AppSecurityPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    final values = policy.toMap();
    for (final entry in values.entries) {
      final key = '$_cachePrefix${entry.key}';
      final value = entry.value;
      if (value is bool) await prefs.setBool(key, value);
      if (value is int) await prefs.setInt(key, value);
      if (value is String) await prefs.setString(key, value);
    }
  }

  Future<AppSecurityPolicy?> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('${_cachePrefix}forceUpdateEnabled')) return null;
    return AppSecurityPolicy.fromMap({
      'forceUpdateEnabled':
          prefs.getBool('${_cachePrefix}forceUpdateEnabled') ?? false,
      'minimumAndroidBuild':
          prefs.getInt('${_cachePrefix}minimumAndroidBuild') ?? 0,
      'minimumIosBuild': prefs.getInt('${_cachePrefix}minimumIosBuild') ?? 0,
      'minimumAttendanceProtocolVersion':
          prefs.getInt('${_cachePrefix}minimumAttendanceProtocolVersion') ?? 0,
      'blockAndroidDeveloperOptions':
          prefs.getBool('${_cachePrefix}blockAndroidDeveloperOptions') ?? true,
      'androidStoreUrl':
          prefs.getString('${_cachePrefix}androidStoreUrl') ?? '',
      'iosStoreUrl': prefs.getString('${_cachePrefix}iosStoreUrl') ?? '',
      'messageAr': prefs.getString('${_cachePrefix}messageAr') ?? '',
    });
  }
}
