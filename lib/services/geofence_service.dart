import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';

class GeofenceResult {
  final bool isWithinZone;
  final double distanceMeters;
  final String locationName;
  final double allowedRadius;
  final double accuracyMeters;
  final bool isMocked;
  final Position position;

  GeofenceResult({
    required this.isWithinZone,
    required this.distanceMeters,
    required this.locationName,
    required this.allowedRadius,
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
    final position = await _getReliablePosition(
      allowLastKnown: !strictLocationOnly,
    );

    // 4. Calculate distance in meters using Haversine formula
    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );

    // 5. Check if spoofing app is used
    final isMocked = position.isMocked;

    // 6. Check if user is inside the geofence radius.
    // Location-only attendance uses the configured radius exactly. Biometric
    // mode retains a small tolerance for normal indoor GPS drift.
    final accuracyTolerance = strictLocationOnly
        ? 0.0
        : position.accuracy.clamp(0, 35).toDouble();
    final effectiveRadius = location.geofenceRadiusMeters + accuracyTolerance;
    final isWithin = distanceMeters <= effectiveRadius;

    return GeofenceResult(
      isWithinZone: isWithin,
      distanceMeters: distanceMeters,
      locationName: location.name,
      allowedRadius: effectiveRadius,
      accuracyMeters: position.accuracy,
      isMocked: isMocked,
      position: position,
    );
  }

  Future<Position> _getReliablePosition({required bool allowLastKnown}) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (_) {
      if (allowLastKnown) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null &&
            DateTime.now().difference(lastKnown.timestamp).inMinutes <= 2) {
          return lastKnown;
        }
      }
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        throw Exception(
          'تعذر تحديد موقعك خلال الوقت المحدد. فعّل GPS، افتح الإنترنت، وانتقل لمكان مفتوح ثم أعد المحاولة.',
        );
      }
    }
  }
}
