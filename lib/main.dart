import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
import 'core/feature_flags/company_workspace_feature_flag.dart';
import 'core/feature_flags/phase007_feature_flags.dart';
import 'core/feature_flags/remote_phase007_feature_flags.dart';
import 'core/feature_flags/company_os_feature_flags.dart';
import 'core/feature_flags/remote_company_os_feature_flags.dart';
import 'features/company_workspace/data/datasources/firebase_workspace_session.dart';
import 'features/company_workspace/data/feature_flags/remote_company_workspace_feature_flag.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  Provider.debugCheckInvalidValueType = null;
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
  late final http.Client _workspaceFlagClient;
  late final RemoteCompanyWorkspaceFeatureFlag _workspaceFlag;
  late final http.Client _phase007FlagClient;
  late final RemotePhase007FeatureFlags _phase007Flags;
  late final http.Client _companyOsFlagClient;
  late final RemoteCompanyOsFeatureFlags _companyOsFlags;
  StreamSubscription<User?>? _workspaceFlagSubscription;
  bool _resumeSecurityCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    _workspaceFlagClient = http.Client();
    _workspaceFlag = RemoteCompanyWorkspaceFeatureFlag(
      client: _workspaceFlagClient,
      session: FirebaseWorkspaceSession(FirebaseAuth.instance),
      baseUri: Uri.parse('https://notification.zawolf.ai'),
    );
    _phase007FlagClient = http.Client();
    _phase007Flags = RemotePhase007FeatureFlags(
      client: _phase007FlagClient,
      tokenProvider: () async =>
          FirebaseAuth.instance.currentUser?.getIdToken(),
      baseUri: Uri.parse('https://notification.zawolf.ai'),
    );
    _companyOsFlagClient = http.Client();
    _companyOsFlags = RemoteCompanyOsFeatureFlags(
      client: _companyOsFlagClient,
      tokenProvider: () async =>
          FirebaseAuth.instance.currentUser?.getIdToken(),
      baseUri: Uri.parse('https://notification.zawolf.ai'),
    );
    _workspaceFlagSubscription = FirebaseAuth.instance.idTokenChanges().listen((
      user,
    ) {
      unawaited(_workspaceFlag.refresh());
      if (user == null) {
        _phase007Flags.clear();
        _companyOsFlags.resetForSignedOutUser();
      } else {
        unawaited(_phase007Flags.refresh());
        unawaited(_companyOsFlags.refresh());
      }
    });
    unawaited(_workspaceFlag.refresh());
    unawaited(_phase007Flags.refresh());
    unawaited(_companyOsFlags.refresh());
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
    _securityStatus = AppSecurityPolicyService.instance.loadStatus();
  }

  @override
  void dispose() {
    _workspaceFlagSubscription?.cancel();
    _workspaceFlag.dispose();
    _workspaceFlagClient.close();
    _phase007Flags.dispose();
    _phase007FlagClient.close();
    _companyOsFlags.dispose();
    _companyOsFlagClient.close();
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Browser tab visibility changes must not replace the whole router with
    // the security loading screen. The web session remains protected by the
    // initial policy check and Firestore rules.
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      unawaited(_refreshSecurityStatusOnResume());
    }
  }

  Future<void> _refreshSecurityStatusOnResume() async {
    if (_resumeSecurityCheckInFlight) return;
    _resumeSecurityCheckInFlight = true;
    try {
      final status = await AppSecurityPolicyService.instance.loadStatus(
        serverOnly: true,
      );
      if (!mounted || (status.policyVerified && !status.updateRequired)) return;

      // Keep the current provider and router trees alive during ordinary
      // resume checks. Replacing them with a loading MaterialApp restarts the
      // navigation flow at /splash and makes a backgrounded app look closed.
      setState(() {
        _securityStatus = Future<AppSecurityStatus>.value(status);
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Resume security policy refresh failed: $error');
      }
    } finally {
      _resumeSecurityCheckInFlight = false;
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
        if (!kIsWeb &&
            status != null &&
            (!status.policyVerified || status.updateRequired)) {
          return RequiredUpdateScreen(
            status: status,
            onRetry: _retrySecurityCheck,
          );
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
            ChangeNotifierProvider<RemoteCompanyWorkspaceFeatureFlag>.value(
              value: _workspaceFlag,
            ),
            Provider<CompanyWorkspaceFeatureFlag>.value(value: _workspaceFlag),
            ChangeNotifierProvider<RemotePhase007FeatureFlags>.value(
              value: _phase007Flags,
            ),
            Provider<Phase007FeatureFlags>.value(value: _phase007Flags),
            ChangeNotifierProvider<RemoteCompanyOsFeatureFlags>.value(
              value: _companyOsFlags,
            ),
            Provider<CompanyOsFeatureFlags>.value(value: _companyOsFlags),
          ],
          child: Builder(
            builder: (context) {
              final router = ZaWolfRouter.getRouter(context);
              return MaterialApp.router(
                title: 'Zawolf Hr',
                debugShowCheckedModeBanner: false,
                theme: ZaWolfTheme.darkTheme,
                routerConfig: router,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('ar'),
                  Locale('en'),
                ],
                locale: const Locale('ar'),
                builder: (context, child) => kIsWeb
                    ? SelectionArea(child: child ?? const SizedBox.shrink())
                    : child ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }
}
