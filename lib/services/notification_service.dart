import 'dart:async';
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

  void handleRemoteNotificationRoute(String? route) {
    if (route == null || route.trim().isEmpty) return;
    initialRoute = route;
    _onNotificationTap.add(route);
  }

  /// Expose the raw plugin for advanced use (e.g., DailyReminderService).
  FlutterLocalNotificationsPlugin get plugin => _localNotificationsPlugin;

  // Initialize notifications settings
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
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
    await _localNotificationsPlugin.cancel(id);
  }

  // Display a native notification banner
  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'zawolf_hr_notifications',
      'إشعارات ZaWolf',
      channelDescription: 'قناة إشعارات نظام الموارد البشرية ZaWolf',
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

                  String route = '/employee/dashboard'; // default fallback
                  if (type.contains('request_submitted')) {
                    // We assume it's for manager/hr (they receive submitted)
                    route = '/manager/requests';
                  } else if (type.contains('request_reviewed') ||
                      type.contains('approved') ||
                      type.contains('rejected')) {
                    route = '/employee/requests';
                  } else if (type.contains('task')) {
                    route = '/employee/tasks';
                  } else if (type.contains('warning') ||
                      type.contains('reward')) {
                    route = '/employee/warnings-rewards';
                  } else if (type.contains('suggestion')) {
                    route = '/employee/suggestions';
                  } else if (type.contains('kpi')) {
                    route = '/employee/kpi';
                  }

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
