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
        }
      },
    );

    await requestPermissions();
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
                  showNotification(title, body, payload: docId);
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
