import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../features/attendance_locations/data/attendance_location_assignment_repository_impl.dart';
import '../features/attendance_locations/domain/services/attendance_region_plan.dart';
import 'attendance_service.dart';
import 'location_service.dart';

/// Registers the branch boundary with the operating system. It intentionally
/// does not create attendance locally; native events are sent to the server
/// for schedule and security validation.
class AutomaticAttendanceService {
  AutomaticAttendanceService._();
  static final instance = AutomaticAttendanceService._();

  static const _channel = MethodChannel('zawolf_hr/automatic_attendance');

  // Both platforms use operating-system region monitoring. The setting is
  // explicit opt-in and the server remains responsible for deciding whether a
  // boundary event is a valid attendance action.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> isEnabledFor(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('automatic_attendance_enabled_$userId') ?? false;
  }

  Future<void> enableFor(UserModel user) async {
    if (!isSupported) {
      throw Exception(
        'الحضور التلقائي غير متاح على iPhone. استخدم زر الحضور والانصراف داخل التطبيق؛ لا يتم تتبع موقعك في الخلفية.',
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('فعّل خدمة الموقع من إعدادات الهاتف أولاً.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        permission == LocationPermission.whileInUse) {
      await _channel.invokeMethod<bool>('requestIosAlwaysPermission');
      permission = await Geolocator.checkPermission();
    }
    if (permission != LocationPermission.always) {
      throw Exception(
        'للحضور التلقائي، اختر السماح بالموقع دائماً (Always allow) من إعدادات التطبيق ثم أعد المحاولة.',
      );
    }
    final device = await AttendanceService().prepareAutomaticAttendance(user);
    await configureFor(
      user,
      force: true,
      deviceId: device.deviceId,
      deviceLabel: device.deviceLabel,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('automatic_attendance_enabled_${user.uid}', true);
  }

  Future<void> configureFor(
    UserModel user, {
    bool force = false,
    String? deviceId,
    String? deviceLabel,
  }) async {
    if (!isSupported) return;
    // iOS restores an already-approved region monitor natively on launch.
    // Give the first Flutter frame time to settle before refreshing its
    // assignment list through the MethodChannel. This preserves HR assignment
    // updates while keeping a native location refresh out of the launch path.
    if (defaultTargetPlatform == TargetPlatform.iOS && !force) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!force && !await isEnabledFor(user.uid)) return;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) return;
    final monitorLocations = await _monitorLocations(user);
    if (monitorLocations.isEmpty) {
      if (force) {
        throw Exception('لا يوجد موقع حضور نشط مسند إلى حسابك. تواصل مع HR.');
      }
      return;
    }
    final boundDeviceId = deviceId ?? user.registeredAttendanceDeviceId;
    if (boundDeviceId == null || boundDeviceId.trim().isEmpty) return;
    final method =
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'configureIosGeofence'
            : 'configureAndroidGeofence';
    await _channel.invokeMethod<void>(method, {
      'userId': user.uid,
      'employeeId': user.employeeId,
      'deviceId': boundDeviceId,
      'deviceLabel': deviceLabel ?? user.registeredAttendanceDeviceLabel ?? '',
      // Scalar fields keep old installed native builds compatible during the
      // staged rollout. New builds consume the bounded locations list.
      ...monitorLocations.first,
      'locations': monitorLocations,
    });
  }

  Future<List<Map<String, Object?>>> _monitorLocations(UserModel user) async {
    try {
      final snapshot =
          await AttendanceLocationAssignmentRepositoryImpl().getMine();
      if (snapshot.enabled) {
        final now = DateTime.now();
        final assignments = AttendanceRegionPlan.build(
          assignments: snapshot.assignments,
          at: now,
        );
        return assignments
            .map(
              (assignment) => <String, Object?>{
                'locationId': assignment.locationId,
                'locationName': assignment.locationName,
                'latitude': assignment.latitude,
                'longitude': assignment.longitude,
                'radiusMeters': assignment.radiusMeters,
                'assignmentId': assignment.id,
                'assignmentVersion': assignment.version,
                'priority': assignment.priority,
              },
            )
            .toList(growable: false);
      }
    } catch (_) {
      // A rollout/cache failure keeps the existing single-location behavior.
    }
    if (user.locationId.isEmpty) return const [];
    final location = await LocationService().getLocationById(user.locationId);
    if (location == null || !location.isActive) return const [];
    return [
      <String, Object?>{
        'locationId': location.locationId,
        'locationName': location.name,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radiusMeters': location.geofenceRadiusMeters,
      },
    ];
  }

  Future<void> disable(String userId) async {
    if (isSupported) {
      final method =
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'disableIosGeofence'
              : 'disableAndroidGeofence';
      await _channel.invokeMethod<void>(method);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('automatic_attendance_enabled_$userId');
  }
}
