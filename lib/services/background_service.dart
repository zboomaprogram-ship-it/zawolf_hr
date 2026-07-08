import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

const String kNotificationBackgroundTaskName =
    'zawolf_notification_polling_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // 1. Initialize Firebase inside the background task isolate
      await Firebase.initializeApp();

      // 2. Fetch current authenticated user directly from FirebaseAuth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return true; // No session active
      }

      // 3. Query unread notification documents from Firestore
      final notificationsSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .get();

      if (notificationsSnap.docs.isNotEmpty) {
        // Initialize local notification service
        final notifService = NotificationService.instance;
        await notifService.initialize();

        for (var doc in notificationsSnap.docs) {
          final data = doc.data();
          final title = data['title'] as String? ?? 'تنبيه جديد';
          final body = data['body'] as String? ?? '';
          final type = data['type'] as String? ?? '';
          final rawData = data['data'];
          final route = rawData is Map && rawData['route'] is String
              ? rawData['route'] as String
              : notifService.routeForType(type);

          await notifService.showNotification(
            title,
            body,
            payload: 'route|$route',
          );
        }
      }
    } catch (_) {
      // Ignore background errors
    }
    return true;
  });
}

class BackgroundService {
  // Initialize Workmanager
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  // Register recurring background polling task (run every 15 minutes)
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      'zawolf_periodic_notification_task_id',
      kNotificationBackgroundTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // Cancel background tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }
}
