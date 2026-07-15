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

/// A personal, opt-in work alarm. Android delegates to the user's Clock app.
/// iOS 26+ uses AlarmKit only after the employee turns the feature on;
/// older iOS versions fall back to a daily local notification.
class PersonalAlarmService {
  PersonalAlarmService._();
  static final PersonalAlarmService instance = PersonalAlarmService._();

  static const _channel = MethodChannel('zawolf_hr/personal_alarm');
  static const _enabledKeyPrefix = 'personal_alarm_enabled_';
  static const _hourKeyPrefix = 'personal_alarm_hour_';
  static const _minuteKeyPrefix = 'personal_alarm_minute_';
  static const _iosAlarmIdKeyPrefix = 'personal_alarm_ios_id_';

  bool get usesAndroidClock => Platform.isAndroid;

  Future<bool> get canUseAndroidAlarm async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('canUseSystemAlarm') ?? false;
  }

  Future<bool> get supportsIosSystemAlarm async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('iosAlarmAvailability') ?? false;
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
        throw Exception('اسمح بإشعارات الهاتف حتى يظهر زر إيقاف منبه الدوام.');
      }
      await _channel.invokeMethod<void>('setSystemAlarm', {
        'userId': userId,
        'hour': hour,
        'minute': minute,
        'message': 'منبه الدوام - ZaWolf HR',
      });
    } else if (Platform.isIOS) {
      if (await supportsIosSystemAlarm) {
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
      } else {
        await NotificationService.instance.requestPermissions();
        await _scheduleIosReminder(userId, settings);
      }
    }
    // Do not mark the setting enabled until the platform has accepted it.
    await prefs.setBool('$_enabledKeyPrefix$userId', true);
    await prefs.setInt('$_hourKeyPrefix$userId', hour);
    await prefs.setInt('$_minuteKeyPrefix$userId', minute);
    return settings;
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
      await NotificationService.instance.cancelNotification(
        _notificationIdFor(userId),
      );
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
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.hour,
      settings.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await NotificationService.instance.plugin.zonedSchedule(
      _notificationIdFor(userId),
      'منبه الدوام',
      'حان وقت الاستعداد للدوام.',
      scheduled,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'route|/employee/dashboard',
    );
  }

  int _notificationIdFor(String userId) {
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return 600000 + (hash % 100000);
  }
}
