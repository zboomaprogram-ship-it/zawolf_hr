import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'theme/theme.dart';
import 'services/auth_service.dart';
import 'navigation/router.dart';

import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/daily_reminder_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);

  // 1. Initialize Firebase Core
  // In a normal build, this will consume GoogleService JSONs from native platforms automatically.
  try {
    await Firebase.initializeApp();
    const forceDebugAppCheck = bool.fromEnvironment(
      'APP_CHECK_DEBUG',
      defaultValue: false,
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode && !forceDebugAppCheck
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode && !forceDebugAppCheck
          ? AppleProvider.appAttestWithDeviceCheckFallback
          : AppleProvider.debug,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    // 2. Enable Firestore Offline Persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const MyApp());

  unawaited(_initializeAppServicesAfterFirstFrame());
}

Future<void> _initializeAppServicesAfterFirstFrame() async {
  await Future<void>.delayed(Duration.zero);
  try {
    await NotificationService.instance.initialize();
    await DailyReminderService.instance.initializeTimezones();

    const enableNotificationPolling = bool.fromEnvironment(
      'ENABLE_NOTIFICATION_POLLING',
      defaultValue: false,
    );
    if (enableNotificationPolling) {
      await BackgroundService.initialize();
      await BackgroundService.registerPeriodicTask();
    }
  } catch (e) {
    debugPrint('Notification service setup failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: Builder(
        builder: (context) {
          final router = ZaWolfRouter.getRouter(context);
          return MaterialApp.router(
            title: 'Zawolf Hr',
            debugShowCheckedModeBanner: false,
            theme: ZaWolfTheme.darkTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
