import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/user_model.dart';
import '../../../services/geofence_service.dart';
import '../domain/entities/check_in_location.dart';
import '../domain/repositories/geofence_verification_repository.dart';

/// Data-layer implementation of [GeofenceVerificationRepository].
/// Bridges the legacy [GeofenceService] and Firestore persistence to provide
/// a clean, framework-independent [CheckInLocation] to domain contracts.
class GeofenceVerificationRepositoryImpl implements GeofenceVerificationRepository {
  GeofenceVerificationRepositoryImpl({
    GeofenceService? geofenceService,
    FirebaseFirestore? firestore,
  })  : _geofenceService = geofenceService ?? GeofenceService(),
        _db = firestore ?? FirebaseFirestore.instance;

  final GeofenceService _geofenceService;
  final FirebaseFirestore _db;

  @override
  Future<CheckInLocation> verifyLocation({
    required String employeeUid,
    required bool allowLastKnown,
  }) async {
    final userDoc = await _db.collection('users').doc(employeeUid).get();
    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('بيانات الموظف غير موجودة.');
    }
    final employee = UserModel.fromFirestore(userDoc);
    final result = await _geofenceService.validateCheckIn(
      employee,
      strictLocationOnly: !allowLastKnown,
    );

    return CheckInLocation(
      latitude: result.position.latitude,
      longitude: result.position.longitude,
      accuracyMeters: result.accuracyMeters,
      isWithinZone: result.isWithinZone,
      distanceMeters: result.distanceMeters,
      allowedRadiusMeters: result.allowedRadius,
      locationId: result.locationId ?? '',
      locationName: result.locationName,
      isMocked: result.isMocked,
    );
  }
}
