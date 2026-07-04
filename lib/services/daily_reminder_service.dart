import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart' hide TextDirection;

import '../models/company_day_off_model.dart';
import 'notification_service.dart';

/// Smart daily reminder IDs — using fixed IDs so we can always cancel/replace them.
const int kMorningCheckInReminderId = 9001;
const int kCheckOutReminderId = 9002;

/// Service responsible for scheduling and managing daily attendance reminders.
/// Reminders are scheduled using TZ-aware local notifications and persist
/// across app kills (handled by the OS alarm/notification system).
class DailyReminderService {
  DailyReminderService._();
  static final DailyReminderService instance = DailyReminderService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Must be called once at app startup (after NotificationService.initialize()).
  Future<void> initializeTimezones() async {
    tz_data.initializeTimeZones();
    // Set to Saudi/Egypt timezone — adjust if needed.
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  }

  /// Called when employee logs in.
  /// Schedules the two daily reminders based on their work schedule.
  Future<void> scheduleForUser({
    required String userId,
    required String startTime, // "HH:mm" e.g. "09:00"
    required String endTime,   // "HH:mm" e.g. "17:00"
  }) async {
    // Cancel any previous reminders first.
    await cancelAll();

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final startHour = int.tryParse(startParts[0]) ?? 9;
    final startMin = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 17;
    final endMin = int.tryParse(endParts[1]) ?? 0;

    // Morning reminder: 10 minutes before shift start
    int morningHour = startHour;
    int morningMin = startMin - 10;
    if (morningMin < 0) {
      morningMin += 60;
      morningHour -= 1;
    }

    await _scheduleSmartDailyNotification(
      id: kMorningCheckInReminderId,
      hour: morningHour,
      minute: morningMin,
      userId: userId,
      checkType: 'check_in',
      startTime: startTime,
      endTime: endTime,
    );

    // Checkout reminder: at shift end time
    await _scheduleSmartDailyNotification(
      id: kCheckOutReminderId,
      hour: endHour,
      minute: endMin,
      userId: userId,
      checkType: 'check_out',
      startTime: startTime,
      endTime: endTime,
    );

    if (kDebugMode) {
      print('DailyReminderService: Scheduled morning reminder at $morningHour:$morningMin');
      print('DailyReminderService: Scheduled checkout reminder at $endHour:$endMin');
    }
  }

  /// Cancels all daily reminders (call on logout).
  Future<void> cancelAll() async {
    await NotificationService.instance.cancelNotification(kMorningCheckInReminderId);
    await NotificationService.instance.cancelNotification(kCheckOutReminderId);
  }

  /// Schedules a single smart daily notification.
  /// When it fires, it checks all conditions before showing.
  Future<void> _scheduleSmartDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String userId,
    required String checkType,
    required String startTime,
    required String endTime,
  }) async {
    final plugin = NotificationService.instance.plugin;

    const androidDetails = AndroidNotificationDetails(
      'zawolf_daily_reminders',
      'تذكيرات الدوام اليومية',
      channelDescription: 'تذكيرات يومية لتسجيل الحضور والانصراف',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Build the next occurrence of this time.
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      hour, minute,
    );
    // If that time has already passed today, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Schedule daily repeat Mon–Sun, but suppress on Fridays via payload check.
    // We store userId + checkType in the payload so the notification handler
    // can run the smart check before displaying.
    final payload = '$checkType|$userId|$startTime|$endTime';

    await plugin.zonedSchedule(
      id,
      checkType == 'check_in'
          ? '⏰ تذكير بتسجيل الحضور'
          : '🚪 تذكير بتسجيل الانصراف',
      checkType == 'check_in'
          ? 'لا تنسَ تسجيل حضورك في الموعد المحدد!'
          : 'انتهى الدوام! لا تنسَ تسجيل انصرافك.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Called by the notification response handler when the user sees a daily reminder.
  /// Also called from a background check to pre-cancel if not needed.
  /// Returns true if the notification should be shown, false if it should be suppressed.
  Future<bool> shouldShowReminder({
    required String checkType,
    required String userId,
    required String startTime,
    required String endTime,
  }) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 1. Skip Fridays
    if (now.weekday == DateTime.friday) {
      if (kDebugMode) print('DailyReminder: Suppressed — Friday');
      return false;
    }

    // 2. Check company day off (applies to all employees)
    try {
      final dayOffKey = CompanyDayOffModel.keyFor(now);
      final dayOffDoc = await _db.collection('companyDayOffs').doc(dayOffKey).get();
      if (dayOffDoc.exists) {
        final data = dayOffDoc.data()!;
        if (data['isActive'] == true) {
          if (kDebugMode) print('DailyReminder: Suppressed — Company day off: ${data['title']}');
          return false;
        }
      }
    } catch (_) {}

    // 3. Check employee's personal approved leave (HR-added or self-submitted)
    //    Suppresses both reminders if today is within an approved leave period.
    try {
      final leavesSnap = await _db
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (final doc in leavesSnap.docs) {
        final data = doc.data();
        // Dates are stored as Timestamps — convert to DateTime for comparison.
        final startTs = data['startDate'];
        final endTs = data['endDate'];
        if (startTs == null || endTs == null) continue;

        final startDate = (startTs as Timestamp).toDate();
        final endDate = (endTs as Timestamp).toDate();

        // Check if today falls within [startDate, endDate] (inclusive).
        final todayDate = DateTime(now.year, now.month, now.day);
        final leaveStart = DateTime(startDate.year, startDate.month, startDate.day);
        final leaveEnd = DateTime(endDate.year, endDate.month, endDate.day);

        if (!todayDate.isBefore(leaveStart) && !todayDate.isAfter(leaveEnd)) {
          final leaveType = data['leaveType'] as String? ?? 'إجازة';
          if (kDebugMode) print('DailyReminder: Suppressed — Employee on approved leave: $leaveType');
          return false;
        }
      }
    } catch (_) {}

    // 3. Check approved permissions for today
    try {
      final permsSnap = await _db
          .collection('permissions')
          .where('userId', isEqualTo: userId)
          .where('requestDate', isEqualTo: todayStr)
          .where('status', isEqualTo: 'approved')
          .get();

      for (final doc in permsSnap.docs) {
        final data = doc.data();
        final permType = data['permissionType'] as String? ?? '';

        if (checkType == 'check_in' && permType == 'late_arrival') {
          // Employee has approved late arrival permission today — suppress morning reminder
          if (kDebugMode) print('DailyReminder: Suppressed check-in — approved late_arrival permission');
          return false;
        }

        if (checkType == 'check_out' && permType == 'early_leave') {
          // Employee has approved early leave permission today — suppress checkout reminder
          if (kDebugMode) print('DailyReminder: Suppressed check-out — approved early_leave permission');
          return false;
        }
      }
    } catch (_) {}

    // 4. Check if employee already checked in today (suppress morning reminder)
    if (checkType == 'check_in') {
      try {
        final attendanceSnap = await _db
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .where('date', isEqualTo: todayStr)
            .limit(1)
            .get();
        if (attendanceSnap.docs.isNotEmpty) {
          if (kDebugMode) print('DailyReminder: Suppressed check-in — already checked in');
          return false;
        }
      } catch (_) {}
    }

    // 5. Check if employee already checked out today (suppress checkout reminder)
    if (checkType == 'check_out') {
      try {
        final attendanceSnap = await _db
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .where('date', isEqualTo: todayStr)
            .limit(1)
            .get();
        if (attendanceSnap.docs.isNotEmpty) {
          final data = attendanceSnap.docs.first.data();
          if (data['checkOutTime'] != null) {
            if (kDebugMode) print('DailyReminder: Suppressed check-out — already checked out');
            return false;
          }
        }
      } catch (_) {}
    }

    return true;
  }

  /// Parses payload string and shows the smart notification if conditions are met.
  Future<void> handleReminderPayload(String payload) async {
    final parts = payload.split('|');
    if (parts.length < 4) return;

    final checkType = parts[0];
    final userId = parts[1];
    final startTime = parts[2];
    final endTime = parts[3];

    final shouldShow = await shouldShowReminder(
      checkType: checkType,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
    );

    if (!shouldShow) return;

    // Show the smart notification with context-aware Arabic message
    String title;
    String body;

    if (checkType == 'check_in') {
      final parts = startTime.split(':');
      final h = parts[0];
      final m = parts[1];
      title = '⏰ تذكير بتسجيل الحضور';
      body = 'موعد بدء الدوام الساعة $h:$m، لا تتأخر! سجِّل حضورك الآن لتجنب الخصم.';
    } else {
      title = '🚪 تذكير بتسجيل الانصراف';
      body = 'انتهى وقت الدوام! لا تنسَ تسجيل انصرافك قبل المغادرة لتجنب خصم ربع يوم.';
    }

    await NotificationService.instance.showNotification(title, body);
  }
}
