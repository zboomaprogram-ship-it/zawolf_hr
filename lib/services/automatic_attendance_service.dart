import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'attendance_service.dart';
import 'location_service.dart';

/// Registers the branch boundary with the operating system. It intentionally
/// does not create attendance locally; native events are sent to the server
/// for schedule and security validation.
class AutomaticAttendanceService {
  AutomaticAttendanceService._();
  static final instance = AutomaticAttendanceService._();

  static const _channel = MethodChannel('zawolf_hr/automatic_attendance');

  Future<bool> isEnabledFor(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('automatic_attendance_enabled_$userId') ?? false;
  }

  Future<void> enableFor(UserModel user) async {
    if (user.locationId.isEmpty) {
      throw Exception('لا يوجد فرع عمل محدد لهذا الحساب. تواصل مع HR.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('فعّل خدمة الموقع من إعدادات الهاتف أولاً.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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
    if ((!Platform.isAndroid && !Platform.isIOS) || user.locationId.isEmpty) {
      return;
    }
    if (!force && !await isEnabledFor(user.uid)) return;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) return;
    final location = await LocationService().getLocationById(user.locationId);
    if (location == null || !location.isActive) return;
    final boundDeviceId = deviceId ?? user.registeredAttendanceDeviceId;
    if (boundDeviceId == null || boundDeviceId.trim().isEmpty) return;
    await _channel.invokeMethod<void>(
      Platform.isAndroid ? 'configureAndroidGeofence' : 'configureIosRegion',
      {
        'userId': user.uid,
        'employeeId': user.employeeId,
        'deviceId': boundDeviceId,
        'deviceLabel':
            deviceLabel ?? user.registeredAttendanceDeviceLabel ?? '',
        'locationId': location.locationId,
        'locationName': location.name,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radiusMeters': location.geofenceRadiusMeters,
      },
    );
  }

  Future<void> disable(String userId) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _channel.invokeMethod<void>(
        Platform.isAndroid ? 'disableAndroidGeofence' : 'disableIosRegion',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('automatic_attendance_enabled_$userId');
  }
}
