import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._internal();
  static final OneSignalService instance = OneSignalService._internal();

  static const String _appId = String.fromEnvironment('ONESIGNAL_APP_ID');
  bool _initialized = false;

  bool get isConfigured => _appId.trim().isNotEmpty;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      OneSignal.initialize(_appId);
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
      OneSignal.login(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal login failed: $e');
    }
  }

  Future<void> logout() async {
    if (!isConfigured || !_initialized) return;
    try {
      OneSignal.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal logout failed: $e');
    }
  }
}
