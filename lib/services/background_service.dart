import 'package:workmanager/workmanager.dart';

const String kNotificationBackgroundTaskName =
    'zawolf_notification_polling_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async => true);
}

class BackgroundService {
  // Initialize Workmanager
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  // OneSignal is the single background delivery path. Remove the legacy
  // Firestore poller so unread items are not shown again every 15 minutes.
  static Future<void> registerPeriodicTask() async {
    await Workmanager().cancelByUniqueName(
      'zawolf_periodic_notification_task_id',
    );
  }

  // Cancel background tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }
}
