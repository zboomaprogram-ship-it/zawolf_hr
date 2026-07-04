import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import 'audit_log_service.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a new branch location
  Future<void> addLocation(LocationModel location, {String? actorId}) async {
    final docRef = _db.collection('locations').doc();
    final newLocation = location.copyWith(
      locationId: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(newLocation.toFirestore());
    await AuditLogService.instance.record(
      actorId: actorId ?? '',
      action: 'location_created',
      targetCollection: 'locations',
      targetId: docRef.id,
      metadata: {
        'name': newLocation.name,
        'radius': newLocation.geofenceRadiusMeters,
      },
    );
  }

  // Update geofence radius for a branch
  Future<void> updateGeofenceRadius(
    String locationId,
    double meters, {
    String? actorId,
  }) async {
    await _db.collection('locations').doc(locationId).update({
      'geofenceRadiusMeters': meters,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: actorId ?? '',
      action: 'location_geofence_updated',
      targetCollection: 'locations',
      targetId: locationId,
      metadata: {'radius': meters},
    );
  }

  // Edit location details
  Future<void> updateLocation(LocationModel location, {String? actorId}) async {
    await _db.collection('locations').doc(location.locationId).update({
      'name': location.name,
      'address': location.address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'geofenceRadiusMeters': location.geofenceRadiusMeters,
      'isActive': location.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: actorId ?? '',
      action: location.isActive ? 'location_updated' : 'location_deactivated',
      targetCollection: 'locations',
      targetId: location.locationId,
      metadata: {
        'name': location.name,
        'radius': location.geofenceRadiusMeters,
      },
    );
  }

  // Watch/Stream all active locations
  Stream<List<LocationModel>> watchActiveLocations() {
    return _db
        .collection('locations')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LocationModel.fromFirestore(doc))
              .toList();
        });
  }

  // Fetch a single branch location details
  Future<LocationModel?> getLocationById(String locationId) async {
    final doc = await _db.collection('locations').doc(locationId).get();
    if (doc.exists) {
      return LocationModel.fromFirestore(doc);
    }
    return null;
  }
}
