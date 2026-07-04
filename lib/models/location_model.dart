import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String locationId;
  final String companyId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final bool isActive;
  final int employeeCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocationModel({
    required this.locationId,
    this.companyId = 'zawolf',
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 50.0,
    this.isActive = true,
    this.employeeCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      locationId: doc.id,
      companyId: data['companyId'] as String? ?? 'zawolf',
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      geofenceRadiusMeters:
          (data['geofenceRadiusMeters'] as num?)?.toDouble() ?? 50.0,
      isActive: data['isActive'] as bool? ?? true,
      employeeCount: data['employeeCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geofenceRadiusMeters': geofenceRadiusMeters,
      'isActive': isActive,
      'employeeCount': employeeCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LocationModel copyWith({
    String? locationId,
    String? companyId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? geofenceRadiusMeters,
    bool? isActive,
    int? employeeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      isActive: isActive ?? this.isActive,
      employeeCount: employeeCount ?? this.employeeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
