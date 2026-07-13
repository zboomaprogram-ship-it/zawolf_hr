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
  Future<void>? _initializationFuture;
  String? _currentFirebaseUid;
  String? _boundExternalId;
  bool _bindingExternalId = false;

  bool get isConfigured => _appId.trim().isNotEmpty;
  bool get isInitialized => _initialized;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializationFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'OneSignal is disabled: ONESIGNAL_APP_ID was not supplied at build time.',
        );
      }
      return;
    }
    try {
      if (kDebugMode) {
        await OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      await OneSignal.initialize(_appId).timeout(const Duration(seconds: 8));
      _initialized = true;
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        final route = data['route'] as String?;
        NotificationService.instance.handleRemoteNotificationRoute(route);
      });
      _installObservers();
      OneSignal.Notifications.addPermissionObserver((granted) {
        if (granted) {
          unawaited(OneSignal.User.pushSubscription.optIn());
          final uid = _currentFirebaseUid;
          if (uid != null) unawaited(_bindExternalId(uid));
        }
      });
    } catch (e) {
      _initializationFuture = null;
      if (kDebugMode) debugPrint('OneSignal initialization failed: $e');
    }
  }

  Future<void> login(String userId) async {
    if (!isConfigured) return;
    _currentFirebaseUid = userId;
    await initialize();
    if (!_initialized) return;
    try {
      await _requestPermissionAndOptIn();
      await _bindExternalId(userId);
      unawaited(_waitForPushSubscription());
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal login failed: $e');
    }
  }

  Future<void> _bindExternalId(String userId) async {
    if (_bindingExternalId || _boundExternalId == userId) return;
    _bindingExternalId = true;
    // Firebase Auth UID is the sole OneSignal External ID used by the
    // dispatcher. Never substitute an email, employee code, or Firestore ID.
    try {
      await OneSignal.login(userId).timeout(const Duration(seconds: 8));
      await OneSignal.User.addTagWithKey(
        'firebase_uid',
        userId,
      ).timeout(const Duration(seconds: 8));
      _boundExternalId = userId;
      if (OneSignal.Notifications.permission) {
        await OneSignal.User.pushSubscription.optIn().timeout(
          const Duration(seconds: 5),
        );
      }
    } finally {
      _bindingExternalId = false;
    }
  }

  Future<void> _requestPermissionAndOptIn() async {
    try {
      final granted = await OneSignal.Notifications.requestPermission(
        true,
      ).timeout(const Duration(seconds: 8));
      if (granted) {
        await OneSignal.User.pushSubscription.optIn().timeout(
          const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal permission request failed: $e');
    }
  }

  Future<void> logout() async {
    if (!isConfigured || !_initialized) {
      _currentFirebaseUid = null;
      _boundExternalId = null;
      return;
    }
    try {
      await OneSignal.logout().timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal logout failed: $e');
    } finally {
      _currentFirebaseUid = null;
      _boundExternalId = null;
    }
  }

  Future<OneSignalRegistrationState> ensureRegistered(
    String firebaseUid,
  ) async {
    if (!isConfigured) return const OneSignalRegistrationState.notConfigured();
    await login(firebaseUid);
    await _waitForPushSubscription();
    return registrationState();
  }

  OneSignalRegistrationState registrationState() {
    if (!isConfigured) return const OneSignalRegistrationState.notConfigured();
    if (!_initialized) return const OneSignalRegistrationState.initializing();
    final subscription = OneSignal.User.pushSubscription;
    return OneSignalRegistrationState(
      configured: true,
      initialized: true,
      permissionGranted: OneSignal.Notifications.permission,
      optedIn: subscription.optedIn == true,
      subscriptionId: subscription.id,
      tokenReady: subscription.token?.isNotEmpty == true,
      externalIdBound:
          _boundExternalId == _currentFirebaseUid &&
          _currentFirebaseUid != null,
    );
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
        unawaited(_bindExternalId(uid));
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

class OneSignalRegistrationState {
  final bool configured;
  final bool initialized;
  final bool permissionGranted;
  final bool optedIn;
  final String? subscriptionId;
  final bool tokenReady;
  final bool externalIdBound;

  const OneSignalRegistrationState({
    required this.configured,
    required this.initialized,
    required this.permissionGranted,
    required this.optedIn,
    required this.subscriptionId,
    required this.tokenReady,
    required this.externalIdBound,
  });

  const OneSignalRegistrationState.notConfigured()
    : configured = false,
      initialized = false,
      permissionGranted = false,
      optedIn = false,
      subscriptionId = null,
      tokenReady = false,
      externalIdBound = false;

  const OneSignalRegistrationState.initializing()
    : configured = true,
      initialized = false,
      permissionGranted = false,
      optedIn = false,
      subscriptionId = null,
      tokenReady = false,
      externalIdBound = false;

  bool get isReady =>
      configured &&
      initialized &&
      permissionGranted &&
      optedIn &&
      subscriptionId != null &&
      tokenReady &&
      externalIdBound;
}
