import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'notification_service.dart';

class OneSignalService {
  OneSignalService._internal();
  static final OneSignalService instance = OneSignalService._internal();

  static const String _appId = String.fromEnvironment('ONESIGNAL_APP_ID');
  bool _initialized = false;
  bool _observersInstalled = false;
  String? _currentFirebaseUid;

  bool get isConfigured => _appId.trim().isNotEmpty;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      OneSignal.initialize(_appId);
      if (kDebugMode) {
        await OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        final route = data['route'] as String?;
        NotificationService.instance.handleRemoteNotificationRoute(route);
      });
      _installObservers();
      await OneSignal.Notifications.requestPermission(true);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal initialization failed: $e');
    }
  }

  Future<void> login(String userId) async {
    if (!isConfigured) return;
    await initialize();
    try {
      _currentFirebaseUid = userId;
      // Firebase Auth UID is the sole OneSignal External ID used by the
      // dispatcher. Never substitute an email, employee code, or Firestore ID.
      await OneSignal.login(userId);
      await OneSignal.User.addTagWithKey('firebase_uid', userId);
      await _waitForPushSubscription();
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal login failed: $e');
    }
  }

  Future<void> logout() async {
    if (!isConfigured || !_initialized) return;
    try {
      OneSignal.logout();
      _currentFirebaseUid = null;
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal logout failed: $e');
    }
  }

  void _installObservers() {
    if (_observersInstalled) return;
    _observersInstalled = true;
    OneSignal.User.pushSubscription.addObserver((state) {
      _logSubscription(
        subscriptionId: state.current.id,
        token: state.current.token,
        optedIn: state.current.optedIn,
      );
      final uid = _currentFirebaseUid;
      if (uid != null && state.current.id != null) {
        unawaited(OneSignal.login(uid));
      }
    });
  }

  Future<void> _waitForPushSubscription() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final subscription = OneSignal.User.pushSubscription;
      final subscriptionId = subscription.id;
      final token = subscription.token;
      final optedIn = subscription.optedIn;
      _logSubscription(
        subscriptionId: subscriptionId,
        token: token,
        optedIn: optedIn,
      );
      if (subscriptionId != null && token != null && optedIn == true) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (kDebugMode) {
      debugPrint(
        'OneSignal push subscription is not ready. Check APNs/FCM setup, '
        'the iOS Push Notifications capability, and notification permission.',
      );
    }
  }

  void _logSubscription({
    required String? subscriptionId,
    required String? token,
    required bool? optedIn,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'OneSignal registration: externalId=$_currentFirebaseUid, '
      'subscriptionId=$subscriptionId, optedIn=$optedIn, '
      'tokenReady=${token != null && token.isNotEmpty}',
    );
  }
}
