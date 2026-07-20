import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_reminder_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedIds = {};
  StreamSubscription? _notifSubscription;

  // Stream for handling notification taps
  final StreamController<String> _onNotificationTap =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _onNotificationTap.stream;

  // Initial route if app was launched via notification
  String? initialRoute;

  String routeForType(String type) {
    final value = type.trim();
    if (value == 'poll_created') return '/polls';
    if (value == 'attendance_security_review') return '/manager/requests';
    if (value == 'attendance_security_reviewed') {
      return '/employee/dashboard';
    }
    if (value == 'salary_deduction_pending') return '/manager/requests';
    if (value == 'salary_deduction_reviewed') return '/employee/dashboard';
    if (value == 'complaint_new') return '/manager/requests';
    if (value.contains('pending_hr') || value.contains('pending_manager')) {
      return '/manager/requests';
    }
    if (value.contains('approved') ||
        value.contains('rejected') ||
        value.contains('reviewed') ||
        value.contains('permission') ||
        value.contains('leave') ||
        value.contains('advance')) {
      return '/employee/requests';
    }
    if (value.contains('task')) return '/employee/tasks';
    if (value.contains('warning') || value.contains('reward')) {
      return '/employee/warnings-rewards';
    }
    if (value.contains('suggestion')) return '/employee/suggestions';
    if (value.contains('kpi') || value.contains('performance')) {
      return '/employee/kpi';
    }
    if (value.contains('payroll')) return '/employee/payroll';
    if (value.contains('attendance')) return '/employee/dashboard';
    return '/employee/dashboard';
  }

  void handleRemoteNotificationRoute(String? route) {
    if (route == null || route.trim().isEmpty) return;
    initialRoute = route;
    _onNotificationTap.add(route);
  }

  /// Expose the raw plugin for advanced use (e.g., DailyReminderService).
  FlutterLocalNotificationsPlugin get plugin => _localNotificationsPlugin;

  // Initialize notifications settings
  Future<void> initialize() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings(
      'ic_stat_onesignal_default',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle smart daily reminder payloads
        final payload = response.payload ?? '';
        if (payload.contains('check_in|') || payload.contains('check_out|')) {
          await DailyReminderService.instance.handleReminderPayload(payload);
        } else if (payload.startsWith('route|')) {
          final route = payload.split('|')[1];
          _onNotificationTap.add(route);
        }
      },
    );

    await requestPermissions();

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails!.notificationResponse?.payload ?? '';
      if (payload.startsWith('route|')) {
        initialRoute = payload.split('|')[1];
      }
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _localNotificationsPlugin.cancel(id);
  }

  // Display a native notification banner
  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'zawolf_hr_notifications',
      'إشعارات ZaWolf',
      channelDescription: 'قناة إشعارات نظام الموارد البشرية ZaWolf',
      icon: 'ic_stat_onesignal_default',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Start real-time listener for current user's unread notifications
  void startListening(String userId) {
    stopListening();
    _notifiedIds.clear();

    bool isInitial = true;
    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (isInitial) {
            isInitial = false;
            for (var doc in snapshot.docs) {
              _notifiedIds.add(doc.id);
            }
            return;
          }
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final docId = change.doc.id;
                if (!_notifiedIds.contains(docId)) {
                  _notifiedIds.add(docId);
                  final title = data['title'] as String? ?? 'تنبيه جديد';
                  final body = data['body'] as String? ?? '';
                  final type = data['type'] as String? ?? '';

                  final route = routeForType(type);

                  showNotification(title, body, payload: 'route|$route');
                }
              }
            }
          }
        });
  }

  // Cancel listener
  void stopListening() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
  }
}
