import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_route_policy.dart';
import 'daily_reminder_service.dart';
import 'safe_diagnostics_service.dart';

typedef AuthorizedNotificationRouteResolver =
    Future<String?> Function(String notificationId);

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
  AuthorizedNotificationRouteResolver? _authorizedRouteResolver;

  // Initial route if app was launched via notification
  String? initialRoute;

  String routeForType(String type) {
    return NotificationRoutePolicy.routeForType(type);
  }

  String safeRoute(String? route, {String type = ''}) {
    final fallback = routeForType(type);
    final candidate = route?.trim() ?? '';
    if (candidate.isEmpty) return fallback;
    final uri = Uri.tryParse(candidate);
    if (uri == null || !_isSupportedNotificationPath(uri.path)) {
      return fallback;
    }
    return candidate;
  }

  static const Set<String> _supportedNotificationPaths = {
    '/notifications',
    '/polls',
    '/employee/dashboard',
    '/employee/requests',
    '/employee/tasks',
    '/employee/warnings-rewards',
    '/employee/suggestions',
    '/employee/kpi',
    '/employee/payroll',
    '/employee/deductions',
    '/manager/requests',
    '/meeting/history',
    '/meeting/approvals',
    '/approver/custom-requests',
    '/employee/custom-requests',
    '/company-os',
  };

  bool _isSupportedNotificationPath(String path) {
    if (_supportedNotificationPaths.contains(path)) return true;
    return RegExp(
      r'^/(?:employee/requests|manager/requests|hr/requests|requests)/operational/[A-Za-z0-9_.:-]{1,128}$|^/conversations/channel/[A-Za-z0-9_.:%-]{1,180}$',
    ).hasMatch(path);
  }

  void handleRemoteNotificationRoute(String? route) {
    final destination = safeRoute(route);
    initialRoute = destination;
    _onNotificationTap.add(destination);
  }

  void configureAuthorizedRouteResolver(
    AuthorizedNotificationRouteResolver? resolver,
  ) {
    _authorizedRouteResolver = resolver;
  }

  Future<void> handleRemoteNotificationData({
    required String? notificationId,
    required String? route,
    String type = '',
  }) async {
    final id = notificationId?.trim() ?? '';
    if (id.isNotEmpty && _authorizedRouteResolver != null) {
      try {
        final resolved = await _authorizedRouteResolver!(id);
        if (resolved != null && resolved.isNotEmpty) {
          handleRemoteNotificationRoute(resolved);
          return;
        }
      } catch (_) {
        // A resolver outage must not expose technical details or block inbox use.
        await SafeDiagnosticsService.instance.capture(
          feature: 'notification_operations',
          safeCode: 'temporarily_unavailable',
          operation: 'resolve_route',
          surface: 'notification',
        );
      }
      handleRemoteNotificationRoute('/notifications');
      return;
    }
    handleRemoteNotificationRoute(safeRoute(route, type: type));
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
        } else if (payload.startsWith('notification|')) {
          final parts = payload.split('|');
          await handleRemoteNotificationData(
            notificationId: parts.length > 1 ? parts[1] : null,
            route: parts.length > 2 ? parts[2] : null,
          );
        } else if (payload.startsWith('route|')) {
          final parts = payload.split('|');
          handleRemoteNotificationRoute(parts.length > 1 ? parts[1] : null);
        }
      },
    );

    await requestPermissions();

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails!.notificationResponse?.payload ?? '';
      if (payload.startsWith('notification|')) {
        final parts = payload.split('|');
        initialRoute = safeRoute(parts.length > 2 ? parts[2] : null);
      } else if (payload.startsWith('route|')) {
        final parts = payload.split('|');
        initialRoute = safeRoute(parts.length > 1 ? parts[1] : null);
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
        .limit(25)
        .snapshots()
        .listen(
          (snapshot) {
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

                    final nestedData = data['data'];
                    final route = safeRoute(
                      nestedData is Map ? nestedData['route'] as String? : null,
                      type: type,
                    );

                    showNotification(
                      title,
                      body,
                      payload: 'notification|$docId|$route',
                    );
                  }
                }
              }
            }
          },
          onError: (_) {
            unawaited(
              SafeDiagnosticsService.instance.capture(
                feature: 'notification_operations',
                safeCode: 'temporarily_unavailable',
                operation: 'listen',
                surface: 'notification',
              ),
            );
          },
        );
  }

  // Cancel listener
  void stopListening() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
  }
}
