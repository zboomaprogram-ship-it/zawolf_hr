import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/theme.dart';
import 'services/auth_service.dart';
import 'navigation/router.dart';

import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/daily_reminder_service.dart';
import 'services/onesignal_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/required_update_screen.dart';
import 'services/app_security_policy_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);

  // 1. Initialize Firebase Core
  // In a normal build, this will consume GoogleService JSONs from native platforms automatically.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Cloud Firestore enables offline persistence by default on Android and
    // iOS. Do not set Firestore settings here: the native call is asynchronous
    // and can race the first query during launch, which crashes iOS.
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const MyApp());

  unawaited(_initializeAppServicesAfterFirstFrame());
}

Future<void> _initializeAppServicesAfterFirstFrame() async {
  await Future<void>.delayed(Duration.zero);
  if (kIsWeb) return;
  try {
    // Initialize the push SDK before the auth session starts. Authentication
    // later assigns the Firebase UID as the OneSignal External ID.
    await OneSignalService.instance.initialize();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<AppSecurityStatus> _securityStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _securityStatus = AppSecurityPolicyService.instance.loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retrySecurityCheck();
    }
  }

  void _retrySecurityCheck() {
    setState(() {
      _securityStatus = AppSecurityPolicyService.instance.loadStatus(
        serverOnly: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSecurityStatus>(
      future: _securityStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ZaWolfTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
            ),
          );
        }
        final status = snapshot.data;
        if (status?.updateRequired ?? false) {
          return RequiredUpdateScreen(
            status: status!,
            onRetry: _retrySecurityCheck,
          );
        }
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
      },
    );
  }
}
