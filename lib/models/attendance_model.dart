import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String locationId;
  final String locationName;
  final String? managerId;
  final String date; // YYYY-MM-DD
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final GeoPoint checkInLocation;
  final GeoPoint? checkOutLocation;
  final DateTime? localCheckInTime;
  final DateTime? localCheckOutTime;
  final bool isWithinGeofence;
  final bool isLate;
  final int lateMinutes;
  final double salaryDeductionFraction;
  final double salaryDeductionAmount;
  final String salaryCurrency;
  final String salaryDeductionCode;
  final String salaryDeductionLabel;
  final String salaryDeductionApprovalStatus;
  final String? salaryDeductionReviewedBy;
  final DateTime? salaryDeductionReviewedAt;
  final String? deviceId;
  final String? deviceLabel;
  final bool biometricVerified;
  final double? totalWorkHours;
  final String
  status; // 'present' | 'late' | 'absent' | 'half-day' | 'on-leave'

  AttendanceModel({
    required this.attendanceId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.locationId,
    required this.locationName,
    this.managerId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.checkInLocation,
    this.checkOutLocation,
    this.localCheckInTime,
    this.localCheckOutTime,
    this.isWithinGeofence = true,
    this.isLate = false,
    this.lateMinutes = 0,
    this.salaryDeductionFraction = 0,
    this.salaryDeductionAmount = 0,
    this.salaryCurrency = 'EGP',
    this.salaryDeductionCode = 'none',
    this.salaryDeductionLabel = 'لا يوجد خصم',
    this.salaryDeductionApprovalStatus = 'none',
    this.salaryDeductionReviewedBy,
    this.salaryDeductionReviewedAt,
    this.deviceId,
    this.deviceLabel,
    this.biometricVerified = false,
    this.totalWorkHours,
    required this.status,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      attendanceId: doc.id,
      userId: data['userId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      managerId: data['managerId'] as String?,
      date: data['date'] as String? ?? '',
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      checkInLocation:
          data['checkInLocation'] as GeoPoint? ?? const GeoPoint(0.0, 0.0),
      checkOutLocation: data['checkOutLocation'] as GeoPoint?,
      localCheckInTime: (data['localCheckInTime'] as Timestamp?)?.toDate(),
      localCheckOutTime: (data['localCheckOutTime'] as Timestamp?)?.toDate(),
      isWithinGeofence: data['isWithinGeofence'] as bool? ?? true,
      isLate: data['isLate'] as bool? ?? false,
      lateMinutes: data['lateMinutes'] as int? ?? 0,
      salaryDeductionFraction:
          (data['salaryDeductionFraction'] as num?)?.toDouble() ?? 0,
      salaryDeductionAmount:
          (data['salaryDeductionAmount'] as num?)?.toDouble() ?? 0,
      salaryCurrency: data['salaryCurrency'] as String? ?? 'EGP',
      salaryDeductionCode: data['salaryDeductionCode'] as String? ?? 'none',
      salaryDeductionLabel:
          data['salaryDeductionLabel'] as String? ?? 'لا يوجد خصم',
      salaryDeductionApprovalStatus:
          data['salaryDeductionApprovalStatus'] as String? ?? 'none',
      salaryDeductionReviewedBy: data['salaryDeductionReviewedBy'] as String?,
      salaryDeductionReviewedAt:
          (data['salaryDeductionReviewedAt'] as Timestamp?)?.toDate(),
      deviceId: data['deviceId'] as String?,
      deviceLabel: data['deviceLabel'] as String?,
      biometricVerified: data['biometricVerified'] as bool? ?? false,
      totalWorkHours: (data['totalWorkHours'] as num?)?.toDouble(),
      status: data['status'] as String? ?? 'present',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'locationId': locationId,
      'locationName': locationName,
      if (managerId != null) 'managerId': managerId,
      'date': date,
      'checkInTime': checkInTime != null
          ? Timestamp.fromDate(checkInTime!)
          : FieldValue.serverTimestamp(),
      if (checkOutTime != null)
        'checkOutTime': Timestamp.fromDate(checkOutTime!),
      'checkInLocation': checkInLocation,
      if (checkOutLocation != null) 'checkOutLocation': checkOutLocation,
      if (localCheckInTime != null)
        'localCheckInTime': Timestamp.fromDate(localCheckInTime!),
      if (localCheckOutTime != null)
        'localCheckOutTime': Timestamp.fromDate(localCheckOutTime!),
      'isWithinGeofence': isWithinGeofence,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'salaryDeductionFraction': salaryDeductionFraction,
      'salaryDeductionAmount': salaryDeductionAmount,
      'salaryCurrency': salaryCurrency,
      'salaryDeductionCode': salaryDeductionCode,
      'salaryDeductionLabel': salaryDeductionLabel,
      'salaryDeductionApprovalStatus': salaryDeductionApprovalStatus,
      if (salaryDeductionReviewedBy != null)
        'salaryDeductionReviewedBy': salaryDeductionReviewedBy,
      if (salaryDeductionReviewedAt != null)
        'salaryDeductionReviewedAt': Timestamp.fromDate(
          salaryDeductionReviewedAt!,
        ),
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
      'biometricVerified': biometricVerified,
      if (totalWorkHours != null) 'totalWorkHours': totalWorkHours,
      'status': status,
    };
  }
}
