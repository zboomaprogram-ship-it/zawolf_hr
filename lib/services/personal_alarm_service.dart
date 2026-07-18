import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

class PersonalAlarmSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const PersonalAlarmSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  const PersonalAlarmSettings.disabled()
    : enabled = false,
      hour = 8,
      minute = 45;

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class DatedAttendanceAlarm {
  final String key;
  final DateTime triggerAt;
  final String message;

  const DatedAttendanceAlarm({
    required this.key,
    required this.triggerAt,
    required this.message,
  });

  Map<String, Object> toPlatformMap() => {
    'key': key,
    'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
    'message': message,
  };
}

class PersonalAlarmCapability {
  final bool nativeSystemAlarm;
  final String? systemVersion;
  final String authorization;

  const PersonalAlarmCapability({
    required this.nativeSystemAlarm,
    required this.systemVersion,
    required this.authorization,
  });

  bool get usesIosNotificationFallback => Platform.isIOS && !nativeSystemAlarm;

  bool get isIos26OrNewer {
    if (!Platform.isIOS || systemVersion == null) return false;
    final major = int.tryParse(systemVersion!.split('.').first);
    return major != null && major >= 26;
  }
}

/// A personal, opt-in work alarm. Android uses an exact native alarm.
/// iOS 26+ uses AlarmKit only after the employee turns the feature on;
/// older iOS versions fall back to scheduled local alerts.
class PersonalAlarmService {
  PersonalAlarmService._();
  static final PersonalAlarmService instance = PersonalAlarmService._();

  static const _channel = MethodChannel('zawolf_hr/personal_alarm');
  static const _enabledKeyPrefix = 'personal_alarm_enabled_';
  static const _hourKeyPrefix = 'personal_alarm_hour_';
  static const _minuteKeyPrefix = 'personal_alarm_minute_';
  static const _iosAlarmIdKeyPrefix = 'personal_alarm_ios_id_';
  static const _iosFallbackVersionKeyPrefix =
      'personal_alarm_ios_fallback_version_';
  static const _iosFallbackVersion = 2;
  static const _iosDatedAlarmIdsKeyPrefix = 'attendance_alarm_ios_ids_';
  static const _iosDatedNotificationIdsKeyPrefix =
      'attendance_alarm_notification_ids_';

  bool get usesAndroidClock => Platform.isAndroid;

  Future<bool> get canUseAndroidAlarm async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('canUseSystemAlarm') ?? false;
  }

  Future<bool> requestAndroidAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('requestExactAlarmPermission') ??
        false;
  }

  Future<bool> get supportsIosSystemAlarm async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('iosAlarmAvailability') ?? false;
  }

  Future<PersonalAlarmCapability> capability() async {
    if (Platform.isAndroid) {
      return const PersonalAlarmCapability(
        nativeSystemAlarm: true,
        systemVersion: null,
        authorization: 'authorized',
      );
    }
    if (!Platform.isIOS) {
      return const PersonalAlarmCapability(
        nativeSystemAlarm: false,
        systemVersion: null,
        authorization: 'unavailable',
      );
    }
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'iosAlarmStatus',
      );
      return PersonalAlarmCapability(
        nativeSystemAlarm:
            status?['available'] == true && status?['alarmKitCompiled'] == true,
        systemVersion: status?['systemVersion'] as String?,
        authorization: status?['authorization'] as String? ?? 'unavailable',
      );
    } on PlatformException {
      return const PersonalAlarmCapability(
        nativeSystemAlarm: false,
        systemVersion: null,
        authorization: 'unavailable',
      );
    } on MissingPluginException {
      return const PersonalAlarmCapability(
        nativeSystemAlarm: false,
        systemVersion: null,
        authorization: 'unavailable',
      );
    }
  }

  Future<PersonalAlarmSettings> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return PersonalAlarmSettings(
      enabled: prefs.getBool('$_enabledKeyPrefix$userId') ?? false,
      hour: prefs.getInt('$_hourKeyPrefix$userId') ?? 8,
      minute: prefs.getInt('$_minuteKeyPrefix$userId') ?? 45,
    );
  }

  Future<PersonalAlarmSettings> enable({
    required String userId,
    required int hour,
    required int minute,
  }) async {
    final settings = PersonalAlarmSettings(
      enabled: true,
      hour: hour,
      minute: minute,
    );
    final prefs = await SharedPreferences.getInstance();

    if (Platform.isAndroid) {
      await NotificationService.instance.requestPermissions();
      if (!await canUseAndroidAlarm) {
        await requestAndroidAlarmPermission();
        throw Exception(
          'فعّل إذن "المنبهات والتذكيرات" من الصفحة التي فُتحت، ثم عد للتطبيق وفعّل المنبه مرة أخرى.',
        );
      }
      await _channel.invokeMethod<void>('setSystemAlarm', {
        'userId': userId,
        'hour': hour,
        'minute': minute,
        'message': 'حان وقت تسجيل الحضور في ZaWolf HR',
      });
    } else if (Platform.isIOS) {
      final alarmCapability = await capability();
      if (alarmCapability.nativeSystemAlarm) {
        final existingAlarmId = prefs.getString('$_iosAlarmIdKeyPrefix$userId');
        final response = await _channel.invokeMapMethod<String, dynamic>(
          'scheduleIosWorkAlarm',
          {'alarmId': existingAlarmId, 'hour': hour, 'minute': minute},
        );
        final alarmId = response?['alarmId'] as String?;
        if (alarmId == null || alarmId.isEmpty) {
          throw Exception('تعذر جدولة منبه iPhone.');
        }
        await prefs.setString('$_iosAlarmIdKeyPrefix$userId', alarmId);
        // Remove reminders created by older builds after AlarmKit succeeds.
        await _cancelIosReminders(userId);
      } else {
        if (alarmCapability.isIos26OrNewer) {
          throw Exception(
            'هذه النسخة لا تحتوي على AlarmKit رغم أن الجهاز يعمل بنظام iOS 26 أو أحدث. ثبّت آخر إصدار كامل من TestFlight أو App Store، وليس تحديث Shorebird فقط.',
          );
        }
        final iosNotifications = NotificationService.instance.plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await iosNotifications?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        final permissions = await iosNotifications?.checkPermissions();
        if (granted != true ||
            permissions?.isAlertEnabled != true ||
            permissions?.isSoundEnabled != true) {
          throw Exception(
            'فعّل السماح بالإشعارات والصوت لتطبيق ZaWolf HR من إعدادات iPhone، ثم حاول مرة أخرى.',
          );
        }
        try {
          await _scheduleIosReminder(userId, settings);
          if (!await _hasAllIosReminders(userId)) {
            throw Exception('تعذر حفظ تذكير الدوام على iPhone. حاول مرة أخرى.');
          }
          await prefs.setInt(
            '$_iosFallbackVersionKeyPrefix$userId',
            _iosFallbackVersion,
          );
        } catch (_) {
          await _cancelIosReminders(userId);
          rethrow;
        }
      }
    }
    // Do not mark the setting enabled until the platform has accepted it.
    await prefs.setBool('$_enabledKeyPrefix$userId', true);
    await prefs.setInt('$_hourKeyPrefix$userId', hour);
    await prefs.setInt('$_minuteKeyPrefix$userId', minute);
    return settings;
  }

  Future<void> replaceDatedAttendanceSchedule({
    required String ownerId,
    required List<DatedAttendanceAlarm> alarms,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await NotificationService.instance.requestPermissions();
      if (!await canUseAndroidAlarm) {
        await requestAndroidAlarmPermission();
        throw Exception(
          'فعّل إذن "المنبهات والتذكيرات" من إعدادات الهاتف، ثم حاول مرة أخرى.',
        );
      }
      await _channel.invokeMethod<void>('setDatedSystemAlarms', {
        'ownerId': ownerId,
        'alarms': alarms.map((alarm) => alarm.toPlatformMap()).toList(),
      });
    } else if (Platform.isIOS) {
      final capability = await this.capability();
      if (capability.nativeSystemAlarm) {
        final oldIds =
            prefs.getStringList('$_iosDatedAlarmIdsKeyPrefix$ownerId') ??
            const <String>[];
        final response = await _channel
            .invokeMapMethod<String, dynamic>('scheduleIosDatedAlarms', {
              'alarmIds': oldIds,
              'alarms': alarms.map((alarm) => alarm.toPlatformMap()).toList(),
            });
        final ids = (response?['alarmIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        await prefs.setStringList('$_iosDatedAlarmIdsKeyPrefix$ownerId', ids);
        await _cancelIosDatedReminders(ownerId);
      } else {
        if (capability.isIos26OrNewer) {
          throw Exception(
            'هذه النسخة لا تحتوي على AlarmKit. ثبّت آخر إصدار كامل من TestFlight أو App Store.',
          );
        }
        await _requireIosNotificationPermission();
        await _scheduleIosDatedReminders(ownerId, alarms);
      }
    }
    await prefs.setBool('$_enabledKeyPrefix$ownerId', true);
  }

  Future<void> disableDatedAttendanceSchedule(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('setDatedSystemAlarms', {
        'ownerId': ownerId,
        'alarms': const <Map<String, Object>>[],
      });
    } else if (Platform.isIOS) {
      final ids =
          prefs.getStringList('$_iosDatedAlarmIdsKeyPrefix$ownerId') ??
          const <String>[];
      if (ids.isNotEmpty) {
        await _channel.invokeMethod<void>('cancelIosDatedAlarms', {
          'alarmIds': ids,
        });
      }
      await prefs.remove('$_iosDatedAlarmIdsKeyPrefix$ownerId');
      await _cancelIosDatedReminders(ownerId);
    }
    await prefs.setBool('$_enabledKeyPrefix$ownerId', false);
  }

  /// Repairs an alarm enabled by an older build. iOS 26+ migrates it to
  /// AlarmKit; older versions refresh it as a standard local reminder.
  Future<void> repairEnabledAlarmIfNeeded(
    String userId,
    PersonalAlarmSettings settings,
    PersonalAlarmCapability alarmCapability,
  ) async {
    if (!Platform.isIOS || !settings.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (!alarmCapability.nativeSystemAlarm) {
      final fallbackVersion =
          prefs.getInt('$_iosFallbackVersionKeyPrefix$userId') ?? 0;
      if (fallbackVersion < _iosFallbackVersion) {
        await enable(
          userId: userId,
          hour: settings.hour,
          minute: settings.minute,
        );
      }
      return;
    }
    final existingAlarmId = prefs.getString('$_iosAlarmIdKeyPrefix$userId');
    if (existingAlarmId != null && existingAlarmId.isNotEmpty) return;
    await enable(userId: userId, hour: settings.hour, minute: settings.minute);
  }

  Future<PersonalAlarmSettings> saveTime({
    required String userId,
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledKeyPrefix$userId', enabled);
    await prefs.setInt('$_hourKeyPrefix$userId', hour);
    await prefs.setInt('$_minuteKeyPrefix$userId', minute);
    return PersonalAlarmSettings(enabled: enabled, hour: hour, minute: minute);
  }

  Future<void> disable(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledKeyPrefix$userId', false);
    if (Platform.isIOS) {
      final alarmId = prefs.getString('$_iosAlarmIdKeyPrefix$userId');
      if (alarmId != null && alarmId.isNotEmpty) {
        await _channel.invokeMethod<void>('cancelIosWorkAlarm', {
          'alarmId': alarmId,
        });
        await prefs.remove('$_iosAlarmIdKeyPrefix$userId');
      }
      await _cancelIosReminders(userId);
      await prefs.remove('$_iosFallbackVersionKeyPrefix$userId');
    }
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('cancelSystemAlarm', {
        'userId': userId,
      });
    }
  }

  Future<void> _scheduleIosReminder(
    String userId,
    PersonalAlarmSettings settings,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    await _cancelIosReminders(userId);

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'wolf_alarm.wav',
        interruptionLevel: InterruptionLevel.active,
        threadIdentifier: 'zawolf_work_alarm',
      ),
    );
    // Dart weekdays: Monday=1 ... Sunday=7. Friday is intentionally excluded.
    for (final weekday in const <int>[1, 2, 3, 4, 6, 7]) {
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        settings.hour,
        settings.minute,
      );
      while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await NotificationService.instance.plugin.zonedSchedule(
        _notificationIdFor(userId) + weekday,
        'منبه تسجيل الحضور',
        'حان وقت تسجيل الحضور في ZaWolf HR.',
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'route|/employee/dashboard',
      );
    }
  }

  Future<void> _requireIosNotificationPermission() async {
    final iosNotifications = NotificationService.instance.plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await iosNotifications?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final permissions = await iosNotifications?.checkPermissions();
    if (granted != true ||
        permissions?.isAlertEnabled != true ||
        permissions?.isSoundEnabled != true) {
      throw Exception(
        'فعّل الإشعارات والصوت لتطبيق ZaWolf HR من إعدادات iPhone، ثم حاول مرة أخرى.',
      );
    }
  }

  Future<void> _scheduleIosDatedReminders(
    String ownerId,
    List<DatedAttendanceAlarm> alarms,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _cancelIosDatedReminders(ownerId);
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'wolf_alarm.wav',
        interruptionLevel: InterruptionLevel.active,
        threadIdentifier: 'zawolf_work_alarm',
      ),
    );
    final ids = <String>[];
    for (final alarm in alarms) {
      if (!alarm.triggerAt.isAfter(DateTime.now())) continue;
      final id = _notificationIdFor('$ownerId:${alarm.key}');
      await NotificationService.instance.plugin.zonedSchedule(
        id,
        'منبه تسجيل الحضور',
        alarm.message,
        tz.TZDateTime.from(alarm.triggerAt, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'route|/employee/dashboard',
      );
      ids.add(id.toString());
    }
    await prefs.setStringList(
      '$_iosDatedNotificationIdsKeyPrefix$ownerId',
      ids,
    );
  }

  Future<void> _cancelIosDatedReminders(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        prefs.getStringList('$_iosDatedNotificationIdsKeyPrefix$ownerId') ??
        const <String>[];
    for (final rawId in ids) {
      final id = int.tryParse(rawId);
      if (id != null) await NotificationService.instance.cancelNotification(id);
    }
    await prefs.remove('$_iosDatedNotificationIdsKeyPrefix$ownerId');
  }

  Future<bool> _hasAllIosReminders(String userId) async {
    final pending = await NotificationService.instance.plugin
        .pendingNotificationRequests();
    final baseId = _notificationIdFor(userId);
    final scheduledIds = pending.map((request) => request.id).toSet();
    return const <int>[
      1,
      2,
      3,
      4,
      6,
      7,
    ].every((weekday) => scheduledIds.contains(baseId + weekday));
  }

  Future<void> _cancelIosReminders(String userId) async {
    final baseId = _notificationIdFor(userId);
    await NotificationService.instance.cancelNotification(baseId);
    for (var weekday = 1; weekday <= 7; weekday++) {
      await NotificationService.instance.cancelNotification(baseId + weekday);
    }
  }

  int _notificationIdFor(String userId) {
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return 600000 + (hash % 100000);
  }
}
