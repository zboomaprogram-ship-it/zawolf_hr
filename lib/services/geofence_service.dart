import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';

class GeofenceResult {
  final bool isWithinZone;
  final double distanceMeters;
  final String locationName;
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
    required this.configuredRadius,
    required this.allowedRadius,
    required this.accuracyToleranceMeters,
    required this.accuracyMeters,
    required this.position,
    this.isMocked = false,
  });
}

class GeofenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Request location permissions if not already granted
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'خدمة الموقع مغلقة. فعّل GPS / Location من إعدادات الهاتف ثم اضغط تحديث الموقع.',
      );
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'تم رفض إذن الموقع. اسمح للتطبيق باستخدام الموقع حتى يمكن تسجيل الحضور.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'إذن الموقع مرفوض نهائياً. افتح إعدادات التطبيق وفعّل صلاحية الموقع.',
      );
    }

    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        throw Exception(
          'الموقع التقريبي مفعّل. افتح إعدادات التطبيق وفعّل الموقع الدقيق (Precise location) حتى يمكن التحقق من نطاق الفرع.',
        );
      }
    } on Exception catch (error) {
      if (error.toString().contains('الموقع التقريبي')) rethrow;
      // Some Android vendors do not expose the accuracy switch through the
      // platform API. The measured GPS accuracy is still validated below.
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

    final location = LocationModel.fromFirestore(locationDoc);

    // 3. Get device GPS position (high accuracy)
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
    if (distanceMeters > location.geofenceRadiusMeters) {
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
      configuredRadius: location.geofenceRadiusMeters,
      allowedRadius: effectiveRadius,
      accuracyToleranceMeters: accuracyTolerance,
      accuracyMeters: position.accuracy,
      isMocked: isMocked,
      position: position,
    );
  }

  Future<Position> _getReliablePosition({required bool allowLastKnown}) async {
    final samples = <Position>[];
    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      if (_isFresh(first)) samples.add(first);
      if (first.accuracy <= 20) return first;

      try {
        final second = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
        if (_isFresh(second)) samples.add(second);
      } catch (_) {}

      if (samples.isNotEmpty) {
        samples.sort((a, b) => a.accuracy.compareTo(b.accuracy));
        return samples.first;
      }
    } catch (_) {
      if (allowLastKnown) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _isFresh(lastKnown, maxAgeMinutes: 2)) {
          return lastKnown;
        }
      }
    }

    try {
      final fallback = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      if (_isFresh(fallback)) return fallback;
    } catch (_) {}
    throw Exception(
      'تعذر الحصول على موقع حديث ودقيق. فعّل الموقع الدقيق والإنترنت، وانتقل قرب نافذة أو مكان مفتوح ثم أعد المحاولة.',
    );
  }

  Future<Position> _retryOutsidePosition(
    LocationModel location,
    Position initial,
  ) async {
    final candidates = <Position>[initial];
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final candidate = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
        if (_isFresh(candidate)) candidates.add(candidate);
      } catch (_) {}
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
}
