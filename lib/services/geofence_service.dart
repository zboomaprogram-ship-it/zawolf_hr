import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geolocator_web/web_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/employee_role.dart';
import '../features/attendance_locations/data/attendance_location_assignment_repository_impl.dart';
import '../features/attendance_locations/domain/entities/attendance_location_assignment.dart';
import '../features/attendance_locations/domain/repositories/attendance_location_assignment_repository.dart';
import '../features/attendance_locations/domain/services/attendance_location_matcher.dart';

class GeofenceResult {
  final bool isWithinZone;
  final double distanceMeters;
  final String locationName;
  final String? locationId;
  final String? assignmentId;
  final int? assignmentVersion;
  final double configuredRadius;
  final double allowedRadius;
  final double accuracyToleranceMeters;
  final double accuracyMeters;
  final bool isMocked;
  final Position position;

  GeofenceResult({
    required this.isWithinZone,
    required this.distanceMeters,
    required this.locationName,
    this.locationId,
    this.assignmentId,
    this.assignmentVersion,
    required this.configuredRadius,
    required this.allowedRadius,
    required this.accuracyToleranceMeters,
    required this.accuracyMeters,
    required this.position,
    this.isMocked = false,
  });
}

/// The browser watch API can fail independently of a one-shot location read.
/// Keep that failure locally so the employee receives an actionable, safe
/// message instead of a generic retry instruction.
class _WebPositionWatchResult {
  final Position? position;
  final Object? error;

  const _WebPositionWatchResult({this.position, this.error});
}

class GeofenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AttendanceLocationAssignmentRepository _assignmentRepository;
  final AttendanceLocationMatcher _matcher;

  GeofenceService({
    AttendanceLocationAssignmentRepository? assignmentRepository,
    AttendanceLocationMatcher matcher = const AttendanceLocationMatcher(),
  }) : _assignmentRepository =
           assignmentRepository ?? AttendanceLocationAssignmentRepositoryImpl(),
       _matcher = matcher;

  // Request location permissions if not already granted
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        kIsWeb
            ? 'خدمة الموقع غير متاحة في المتصفح. اسمح للموقع باستخدام موقعك الدقيق من رمز القفل بجانب عنوان الصفحة ثم حدّث الصفحة.'
            : 'خدمة الموقع مغلقة. فعّل GPS / Location من إعدادات الهاتف ثم اضغط تحديث الموقع.',
      );
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          kIsWeb
              ? 'تم رفض إذن الموقع في المتصفح. اسمح للموقع باستخدام موقعك الدقيق ثم أعد المحاولة.'
              : 'تم رفض إذن الموقع. اسمح للتطبيق باستخدام الموقع حتى يمكن تسجيل الحضور.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        kIsWeb
            ? 'تم حظر إذن الموقع للمتصفح. افتح إعدادات الموقع من رمز القفل بجانب عنوان الصفحة واسمح بالموقع، ثم حدّث الصفحة.'
            : 'إذن الموقع مرفوض نهائياً. افتح إعدادات التطبيق وفعّل صلاحية الموقع.',
      );
    }

    if (!kIsWeb) {
      try {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          throw Exception(
            'الموقع التقريبي مفعّل. افتح إعدادات التطبيق وفعّل الموقع الدقيق (Precise location) حتى يمكن التحقق من نطاق الفرع.',
          );
        }
      } catch (error) {
        if (error.toString().contains('الموقع التقريبي')) rethrow;
        // Web and some Android vendors do not expose the accuracy switch through platform API.
      }
    }

    return true;
  }

  // Validate employee position against their assigned branch's geofence
  Future<GeofenceResult> validateCheckIn(
    UserModel employee, {
    bool strictLocationOnly = false,
  }) async {
    // 1. Verify permissions
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) {
      throw Exception('أذونات الموقع الجغرافي مطلوبة لتسجيل الحضور.');
    }

    // The server-owned flag is returned with the bounded employee assignment
    // projection. Failure to load it falls back to the unchanged legacy path.
    AttendanceLocationAssignmentsSnapshot? assignmentSnapshot;
    try {
      assignmentSnapshot = await _assignmentRepository.getMine();
    } catch (_) {
      assignmentSnapshot = null;
    }
    if (assignmentSnapshot?.enabled == true) {
      if (assignmentSnapshot!.isStale) {
        throw Exception(
          'بيانات مواقع الحضور تحتاج تحديثاً. اتصل بالإنترنت ثم أعد المحاولة قبل تسجيل الحضور.',
        );
      }
      return _validateAssignedLocations(
        employee,
        assignmentSnapshot.assignments,
        strictLocationOnly: strictLocationOnly,
      );
    }

    // 2. Fetch employee's assigned location from Firestore
    final locationRef = _db.collection('locations').doc(employee.locationId);
    DocumentSnapshot<Map<String, dynamic>> locationDoc;
    try {
      locationDoc = await locationRef.get();
    } catch (_) {
      locationDoc = await locationRef.get(
        const GetOptions(source: Source.cache),
      );
    }

    if (!locationDoc.exists) {
      throw Exception('لم يتم العثور على الفرع المسند للموظف.');
    }

    var location = LocationModel.fromFirestore(locationDoc);

    // 3. Get device GPS position (high accuracy with Web Desktop fallback)
    var position = await _getReliablePosition(
      allowLastKnown: !strictLocationOnly,
    );

    // 4. Calculate distance in meters using Haversine formula
    var distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    // A phone can report a precise permission while its first indoor fix is
    // still a stale cell/Wi-Fi estimate. Before declaring the employee out of
    // range, force another best-quality reading and keep the most credible
    // branch-relative sample.
    if (distanceMeters > location.geofenceRadiusMeters && !kIsWeb) {
      final retry = await _retryOutsidePosition(location, position);
      final retryDistance = Geolocator.distanceBetween(
        retry.latitude,
        retry.longitude,
        location.latitude,
        location.longitude,
      );
      if (retryDistance < distanceMeters ||
          (retryDistance == distanceMeters &&
              retry.accuracy < position.accuracy)) {
        position = retry;
        distanceMeters = retryDistance;
      }
    }

    // Super Admin oversees all branches and may record attendance at any active location
    if (distanceMeters > location.geofenceRadiusMeters &&
        employee.role == EmployeeRole.superAdmin) {
      try {
        final activeLocationsSnap = await _db
            .collection('locations')
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in activeLocationsSnap.docs) {
          if (doc.id == location.locationId) continue;
          final altLocation = LocationModel.fromFirestore(doc);
          final altDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            altLocation.latitude,
            altLocation.longitude,
          );
          final altTolerance = strictLocationOnly
              ? position.accuracy.clamp(0, 12).toDouble()
              : position.accuracy.clamp(0, 25).toDouble();
          if (altDistance <= altLocation.geofenceRadiusMeters + altTolerance) {
            location = altLocation;
            distanceMeters = altDistance;
            break;
          }
        }
      } catch (_) {}
    }

    // 5. Check if spoofing app is used
    final isMocked = position.isMocked;

    // 6. Check if user is inside the geofence radius.
    // Location-only attendance uses the configured radius exactly. Biometric
    // mode retains a small tolerance for normal indoor GPS drift.
    // A small capped allowance prevents a good but imperfect indoor GPS fix
    // from being reported as outside. Large accuracy values never enlarge the
    // geofence and are rejected by AttendanceService instead.
    final accuracyTolerance = strictLocationOnly
        ? position.accuracy.clamp(0, 12).toDouble()
        : position.accuracy.clamp(0, 25).toDouble();
    final effectiveRadius = location.geofenceRadiusMeters + accuracyTolerance;
    final isWithin = distanceMeters <= effectiveRadius;

    return GeofenceResult(
      isWithinZone: isWithin,
      distanceMeters: distanceMeters,
      locationName: location.name,
      locationId: location.locationId,
      configuredRadius: location.geofenceRadiusMeters,
      allowedRadius: effectiveRadius,
      accuracyToleranceMeters: accuracyTolerance,
      accuracyMeters: position.accuracy,
      isMocked: isMocked,
      position: position,
    );
  }

  Future<GeofenceResult> _validateAssignedLocations(
    UserModel employee,
    List<AttendanceLocationAssignment> assignments, {
    required bool strictLocationOnly,
  }) async {
    if (assignments.isEmpty) {
      throw Exception('لا يوجد موقع حضور نشط مسند إلى حسابك. تواصل مع HR.');
    }
    var position = await _getReliablePosition(
      allowLastKnown: !strictLocationOnly,
    );
    var match = _matcher.nearestMatch(
      assignments: assignments,
      employeeUid: employee.uid,
      eventTime: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      maxAccuracyAllowanceMeters: strictLocationOnly ? 12 : 25,
    );
    if (match == null) {
      try {
        final retry = await _getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
        _throwIfMocked(retry);
        final retryMatch = _matcher.nearestMatch(
          assignments: assignments,
          employeeUid: employee.uid,
          eventTime: DateTime.now(),
          latitude: retry.latitude,
          longitude: retry.longitude,
          accuracyMeters: retry.accuracy,
          maxAccuracyAllowanceMeters: strictLocationOnly ? 12 : 25,
        );
        if (retryMatch != null || retry.accuracy < position.accuracy) {
          position = retry;
          match = retryMatch;
        }
      } catch (_) {}
    }
    if (match == null) {
      throw Exception(
        'أنت خارج نطاق مواقع الحضور المسندة إليك. اقترب من أحد المواقع ثم أعد المحاولة.',
      );
    }
    final tolerance = position.accuracy
        .clamp(0, strictLocationOnly ? 12 : 25)
        .toDouble();
    return GeofenceResult(
      isWithinZone: true,
      distanceMeters: match.distanceMeters,
      locationName: match.locationName,
      locationId: match.locationId,
      assignmentId: match.assignmentId,
      assignmentVersion: match.assignmentVersion,
      configuredRadius: match.allowedRadiusMeters - tolerance,
      allowedRadius: match.allowedRadiusMeters,
      accuracyToleranceMeters: tolerance,
      accuracyMeters: position.accuracy,
      isMocked: position.isMocked,
      position: position,
    );
  }

  Future<Position> _getReliablePosition({required bool allowLastKnown}) async {
    final samples = <Position>[];
    // Chrome can resolve a one-shot request inconsistently on desktop while
    // its watch API delivers the same fresh browser coordinate. Start this in
    // parallel so it is ready as a secure fallback without delaying check-in.
    final webWatch = kIsWeb
        ? _getWebWatchPosition(timeLimit: const Duration(seconds: 28))
        : null;
    Object? webLocationError;
    Position? cachedPosition;
    try {
      cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null) _throwIfMocked(cachedPosition);
    } catch (error) {
      if (_isMockLocationError(error)) rethrow;
    }

    try {
      final first = await _getCurrentPosition(
        // On desktop Chrome, asking for a high-accuracy GPS sample first can
        // time out even though the browser has a valid Wi-Fi/IP-assisted
        // position.  Start with the normal browser fix on web, then request a
        // best-quality retry only when the precision is insufficient.  The
        // same freshness, accuracy and geofence checks still apply.
        desiredAccuracy: kIsWeb
            ? LocationAccuracy.medium
            : LocationAccuracy.high,
        // Desktop browsers commonly need longer than a phone for the first
        // Wi-Fi/GPS fix. An eight-second limit made valid web attendance fail
        // before the browser had a chance to provide its first reading.
        timeLimit: Duration(seconds: kIsWeb ? 22 : 8),
      );
      _throwIfMocked(first);
      if (_isFresh(first)) samples.add(first);
      if (_isFresh(first) && first.accuracy <= 25) return first;

      try {
        final second = await _getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: kIsWeb ? 16 : 6),
        );
        _throwIfMocked(second);
        if (_isFresh(second)) samples.add(second);
      } catch (error) {
        if (kIsWeb) webLocationError ??= error;
      }

      if (samples.isNotEmpty) {
        samples.sort((a, b) => a.accuracy.compareTo(b.accuracy));
        return samples.first;
      }
    } catch (error) {
      if (_isMockLocationError(error)) rethrow;
      if (kIsWeb) webLocationError ??= error;
    }

    if (webWatch != null) {
      final watchResult = await webWatch;
      final watched = watchResult.position;
      webLocationError ??= watchResult.error;
      if (watched != null) {
        _throwIfMocked(watched);
        return watched;
      }
    }

    // Some Android devices have an unhealthy Google fused-location provider
    // even while GPS and internet are enabled. Retry through Android's native
    // LocationManager before reporting location as unavailable.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativePosition = await _getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          forceAndroidLocationManager: true,
          timeLimit: const Duration(seconds: 12),
        );
        _throwIfMocked(nativePosition);
        if (_isFresh(nativePosition, maxAgeMinutes: 2)) {
          return nativePosition;
        }
      } catch (error) {
        if (_isMockLocationError(error)) rethrow;
      }
    }

    if (cachedPosition != null &&
        _isSafeCachedFallback(
          cachedPosition,
          strictLocationOnly: !allowLastKnown,
        )) {
      return cachedPosition;
    }

    try {
      final fallback = await _getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: kIsWeb ? 15 : 6),
      );
      _throwIfMocked(fallback);
      if (_isFresh(fallback)) return fallback;
    } catch (error) {
      if (kIsWeb) webLocationError ??= error;
    }

    if (kIsWeb) {
      throw Exception(_webLocationFailureMessage(webLocationError));
    }

    throw Exception(
      'تعذر الحصول على قراءة GPS حديثة. فعّل الموقع الدقيق وميزة تحسين دقة الموقع من Google، ثم انتقل قرب نافذة واضغط تحديث.',
    );
  }

  void _throwIfMocked(Position position) {
    if (!kDebugMode && position.isMocked) {
      throw Exception(
        'تم اكتشاف موقع وهمي. أوقف تطبيقات تغيير الموقع وأعد تشغيل الهاتف قبل تسجيل الحضور.',
      );
    }
  }

  bool _isMockLocationError(Object error) =>
      error.toString().contains('موقع وهمي');

  /// Requests a current browser position and bounds the wait in Dart.
  ///
  /// `geolocator_web` delegates to the browser Geolocation API, whose timeout
  /// is expressed in milliseconds.  Keeping the timeout outside the platform
  /// settings avoids a platform-unit conversion issue while [WebSettings]
  /// accepts a short-lived browser coordinate. This is important on desktop:
  /// browsers often have no GPS and obtain a reliable Wi-Fi reading only after
  /// their location provider has warmed up. The reading is still rejected by
  /// [_isFresh] and the normal geofence distance check.
  Future<Position> _getCurrentPosition({
    required LocationAccuracy desiredAccuracy,
    required Duration timeLimit,
    bool forceAndroidLocationManager = false,
  }) {
    if (kIsWeb) {
      return GeolocatorPlatform.instance
          .getCurrentPosition(
            locationSettings: WebSettings(
              accuracy: desiredAccuracy,
              // The browser can often provide a just-captured Wi-Fi position
              // from its cache immediately. Accept it only for the same
              // one-minute window enforced by [_isFresh], rather than forcing
              // a slow new hardware lookup after 30 seconds.
              maximumAge: const Duration(minutes: 1),
            ),
          )
          .timeout(timeLimit);
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: desiredAccuracy,
      forceAndroidLocationManager: forceAndroidLocationManager,
      timeLimit: timeLimit,
    );
  }

  /// Uses the browser's `watchPosition` path as a web-only fallback.
  ///
  /// This keeps the same browser permission, freshness, spoofing and
  /// geofence checks as a normal reading. It does not use IP geolocation or
  /// relax the attendance radius; it merely handles desktop browsers where a
  /// one-shot position request never settles although an active position watch
  /// can obtain a fresh Wi-Fi/GPS fix.
  Future<_WebPositionWatchResult> _getWebWatchPosition({
    required Duration timeLimit,
  }) async {
    if (!kIsWeb) return const _WebPositionWatchResult();
    try {
      final position = await GeolocatorPlatform.instance
          .getPositionStream(
            locationSettings: WebSettings(
              // Desktop browsers frequently cannot resolve a high-accuracy
              // GPS fix, while their normal Wi-Fi location is available. The
              // result still goes through freshness and geofence validation.
              accuracy: LocationAccuracy.medium,
              maximumAge: Duration.zero,
            ),
          )
          .where((position) => _isFresh(position))
          .first
          .timeout(timeLimit);
      return _WebPositionWatchResult(position: position);
    } catch (error) {
      return _WebPositionWatchResult(error: error);
    }
  }

  String _webLocationFailureMessage(Object? error) {
    final details = error?.toString().toLowerCase() ?? '';
    if (details.contains('permission') || details.contains('denied')) {
      return 'المتصفح رفض إذن الموقع. من رمز القفل بجانب عنوان الموقع اختر «الموقع: سماح»، ثم فعّل الموقع الدقيق وأعد فتح الصفحة.';
    }
    if (details.contains('timeout') || details.contains('time out')) {
      return 'انتهت مهلة الحصول على الموقع من المتصفح. فعّل خدمات الموقع في نظام التشغيل، واتصل بشبكة Wi‑Fi، ثم أعد المحاولة.';
    }
    if (details.contains('position') ||
        details.contains('unavailable') ||
        details.contains('location')) {
      return 'خدمة الموقع في الجهاز لم تُرجع إحداثيات. فعّل خدمات الموقع في نظام التشغيل واسمح لمتصفح Chrome باستخدامها، ثم أعد المحاولة.';
    }
    return 'تعذر الحصول على موقع حديث من المتصفح. اسمح بالموقع الدقيق، أوقف VPN إن وجد، ثم حدّث الصفحة وأعد المحاولة.';
  }

  Future<Position> _retryOutsidePosition(
    LocationModel location,
    Position initial,
  ) async {
    final candidates = <Position>[initial];
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final candidate = await _getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
        _throwIfMocked(candidate);
        if (_isFresh(candidate)) candidates.add(candidate);
      } catch (error) {
        if (_isMockLocationError(error)) rethrow;
      }
    }
    candidates.sort((a, b) {
      final aDistance = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        location.latitude,
        location.longitude,
      );
      final bDistance = Geolocator.distanceBetween(
        b.latitude,
        b.longitude,
        location.latitude,
        location.longitude,
      );
      final distanceOrder = aDistance.compareTo(bDistance);
      return distanceOrder != 0
          ? distanceOrder
          : a.accuracy.compareTo(b.accuracy);
    });
    return candidates.first;
  }

  bool _isFresh(Position position, {int maxAgeMinutes = 1}) {
    final age = DateTime.now().difference(position.timestamp).abs();
    return age <= Duration(minutes: maxAgeMinutes);
  }

  bool _isSafeCachedFallback(
    Position position, {
    required bool strictLocationOnly,
  }) {
    final maxAgeMinutes = strictLocationOnly ? 2 : 5;
    final maxAccuracyMeters = strictLocationOnly ? 25 : 50;
    return _isFresh(position, maxAgeMinutes: maxAgeMinutes) &&
        position.accuracy <= maxAccuracyMeters;
  }
}
