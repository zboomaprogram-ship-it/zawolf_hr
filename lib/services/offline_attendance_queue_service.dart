import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_model.dart';
import 'attendance_security_service.dart';
import 'role_notification_service.dart';

enum OfflineAttendanceActionType { checkIn, checkOut }

class OfflineAttendanceAction {
  final String id;
  final OfflineAttendanceActionType type;
  final String attendanceId;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String locationId;
  final String locationName;
  final String? managerId;
  final String date;
  final DateTime eventTime;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double allowedRadius;
  final double accuracyMeters;
  final String deviceId;
  final String deviceLabel;
  final double? totalWorkHours;
  final bool isLate;
  final int lateMinutes;
  final double salaryDeductionFraction;
  final double salaryDeductionAmount;
  final String salaryCurrency;
  final String salaryDeductionCode;
  final String salaryDeductionLabel;
  final String salaryDeductionApprovalStatus;
  final String securityReviewStatus;
  final String locationRiskLevel;
  final List<String> locationRiskReasons;
  final String? locationRiskMessage;
  final String status;

  const OfflineAttendanceAction({
    required this.id,
    required this.type,
    required this.attendanceId,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.locationId,
    required this.locationName,
    this.managerId,
    required this.date,
    required this.eventTime,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.allowedRadius,
    required this.accuracyMeters,
    required this.deviceId,
    required this.deviceLabel,
    this.totalWorkHours,
    required this.isLate,
    required this.lateMinutes,
    required this.salaryDeductionFraction,
    required this.salaryDeductionAmount,
    required this.salaryCurrency,
    required this.salaryDeductionCode,
    required this.salaryDeductionLabel,
    required this.salaryDeductionApprovalStatus,
    this.securityReviewStatus = 'none',
    this.locationRiskLevel = 'low',
    this.locationRiskReasons = const [],
    this.locationRiskMessage,
    required this.status,
  });

  factory OfflineAttendanceAction.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceAction(
      id: json['id'] as String,
      type: json['type'] == 'checkOut'
          ? OfflineAttendanceActionType.checkOut
          : OfflineAttendanceActionType.checkIn,
      attendanceId: json['attendanceId'] as String,
      userId: json['userId'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String,
      locationId: json['locationId'] as String,
      locationName: json['locationName'] as String,
      managerId: json['managerId'] as String?,
      date: json['date'] as String,
      eventTime: DateTime.fromMillisecondsSinceEpoch(json['eventTime'] as int),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      allowedRadius: (json['allowedRadius'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      deviceId: json['deviceId'] as String,
      deviceLabel: json['deviceLabel'] as String,
      totalWorkHours: (json['totalWorkHours'] as num?)?.toDouble(),
      isLate: json['isLate'] as bool? ?? false,
      lateMinutes: json['lateMinutes'] as int? ?? 0,
      salaryDeductionFraction:
          (json['salaryDeductionFraction'] as num?)?.toDouble() ?? 0,
      salaryDeductionAmount:
          (json['salaryDeductionAmount'] as num?)?.toDouble() ?? 0,
      salaryCurrency: json['salaryCurrency'] as String? ?? 'EGP',
      salaryDeductionCode: json['salaryDeductionCode'] as String? ?? 'none',
      salaryDeductionLabel:
          json['salaryDeductionLabel'] as String? ?? 'لا يوجد خصم',
      salaryDeductionApprovalStatus:
          json['salaryDeductionApprovalStatus'] as String? ?? 'none',
      securityReviewStatus: json['securityReviewStatus'] as String? ?? 'none',
      locationRiskLevel: json['locationRiskLevel'] as String? ?? 'low',
      locationRiskReasons:
          (json['locationRiskReasons'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      locationRiskMessage: json['locationRiskMessage'] as String?,
      status: json['status'] as String? ?? 'present',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == OfflineAttendanceActionType.checkOut
          ? 'checkOut'
          : 'checkIn',
      'attendanceId': attendanceId,
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'locationId': locationId,
      'locationName': locationName,
      if (managerId != null) 'managerId': managerId,
      'date': date,
      'eventTime': eventTime.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'allowedRadius': allowedRadius,
      'accuracyMeters': accuracyMeters,
      'deviceId': deviceId,
      'deviceLabel': deviceLabel,
      if (totalWorkHours != null) 'totalWorkHours': totalWorkHours,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'salaryDeductionFraction': salaryDeductionFraction,
      'salaryDeductionAmount': salaryDeductionAmount,
      'salaryCurrency': salaryCurrency,
      'salaryDeductionCode': salaryDeductionCode,
      'salaryDeductionLabel': salaryDeductionLabel,
      'salaryDeductionApprovalStatus': salaryDeductionApprovalStatus,
      'securityReviewStatus': securityReviewStatus,
      'locationRiskLevel': locationRiskLevel,
      'locationRiskReasons': locationRiskReasons,
      if (locationRiskMessage != null)
        'locationRiskMessage': locationRiskMessage,
      'status': status,
    };
  }

  Map<String, dynamic> toCheckInFirestore() {
    return {
      'userId': userId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'locationId': locationId,
      'locationName': locationName,
      if (managerId != null) 'managerId': managerId,
      'date': date,
      'checkInTime': Timestamp.fromDate(eventTime),
      'checkInLocation': GeoPoint(latitude, longitude),
      'localCheckInTime': Timestamp.fromDate(eventTime),
      'isWithinGeofence': true,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'salaryDeductionFraction': salaryDeductionFraction,
      'salaryDeductionAmount': salaryDeductionAmount,
      'salaryCurrency': salaryCurrency,
      'salaryDeductionCode': salaryDeductionCode,
      'salaryDeductionLabel': salaryDeductionLabel,
      'salaryDeductionApprovalStatus': salaryDeductionApprovalStatus,
      'deviceId': deviceId,
      'deviceLabel': deviceLabel,
      'biometricVerified': true,
      'status': status,
      'offlineCaptured': true,
      'offlineCapturedAt': Timestamp.fromDate(eventTime),
      'offlineDistanceMeters': distanceMeters,
      'offlineAllowedRadiusMeters': allowedRadius,
      'offlineAccuracyMeters': accuracyMeters,
      'securityReviewStatus': securityReviewStatus,
      'locationRiskLevel': locationRiskLevel,
      'locationRiskReasons': locationRiskReasons,
      if (locationRiskMessage != null)
        'locationRiskMessage': locationRiskMessage,
      'locationAccuracyMeters': accuracyMeters,
      'locationDistanceMeters': distanceMeters,
      'locationAllowedRadiusMeters': allowedRadius,
      'locationMocked': false,
      'locationCapturedOffline': true,
    };
  }

  Map<String, dynamic> toCheckOutFirestore() {
    return {
      'checkOutTime': Timestamp.fromDate(eventTime),
      'checkOutLocation': GeoPoint(latitude, longitude),
      'localCheckOutTime': Timestamp.fromDate(eventTime),
      'totalWorkHours': totalWorkHours ?? 0,
      'checkOutDeviceId': deviceId,
      'checkOutDeviceLabel': deviceLabel,
      'checkOutBiometricVerified': true,
      'offlineCheckoutCaptured': true,
      'offlineCheckoutCapturedAt': Timestamp.fromDate(eventTime),
      'offlineCheckoutDistanceMeters': distanceMeters,
      'offlineCheckoutAllowedRadiusMeters': allowedRadius,
      'offlineCheckoutAccuracyMeters': accuracyMeters,
      'checkoutSecurityReviewStatus': securityReviewStatus,
      'checkoutLocationRiskLevel': locationRiskLevel,
      'checkoutLocationRiskReasons': locationRiskReasons,
      if (locationRiskMessage != null)
        'checkoutLocationRiskMessage': locationRiskMessage,
      'checkoutLocationAccuracyMeters': accuracyMeters,
      'checkoutLocationDistanceMeters': distanceMeters,
      'checkoutLocationAllowedRadiusMeters': allowedRadius,
      'checkoutLocationMocked': false,
      'checkoutLocationCapturedOffline': true,
      if (salaryDeductionFraction > 0) ...{
        'salaryDeductionFraction': salaryDeductionFraction,
        'salaryDeductionAmount': salaryDeductionAmount,
        'salaryCurrency': salaryCurrency,
        'salaryDeductionCode': salaryDeductionCode,
        'salaryDeductionLabel': salaryDeductionLabel,
        'salaryDeductionApprovalStatus': salaryDeductionApprovalStatus,
        'salaryDeductionDetectedAt': Timestamp.fromDate(eventTime),
      },
    };
  }

  AttendanceModel toLocalAttendanceModel({AttendanceModel? existing}) {
    if (type == OfflineAttendanceActionType.checkOut && existing != null) {
      return AttendanceModel(
        attendanceId: existing.attendanceId,
        userId: existing.userId,
        employeeId: existing.employeeId,
        employeeName: existing.employeeName,
        locationId: existing.locationId,
        locationName: existing.locationName,
        managerId: existing.managerId,
        date: existing.date,
        checkInTime: existing.checkInTime,
        checkOutTime: eventTime,
        checkInLocation: existing.checkInLocation,
        checkOutLocation: GeoPoint(latitude, longitude),
        localCheckInTime: existing.localCheckInTime,
        localCheckOutTime: eventTime,
        isWithinGeofence: existing.isWithinGeofence,
        isLate: existing.isLate,
        lateMinutes: existing.lateMinutes,
        salaryDeductionFraction: salaryDeductionFraction > 0
            ? salaryDeductionFraction
            : existing.salaryDeductionFraction,
        salaryDeductionAmount: salaryDeductionFraction > 0
            ? salaryDeductionAmount
            : existing.salaryDeductionAmount,
        salaryCurrency: salaryCurrency,
        salaryDeductionCode: salaryDeductionFraction > 0
            ? salaryDeductionCode
            : existing.salaryDeductionCode,
        salaryDeductionLabel: salaryDeductionFraction > 0
            ? salaryDeductionLabel
            : existing.salaryDeductionLabel,
        salaryDeductionApprovalStatus: salaryDeductionFraction > 0
            ? salaryDeductionApprovalStatus
            : existing.salaryDeductionApprovalStatus,
        deviceId: existing.deviceId,
        deviceLabel: existing.deviceLabel,
        biometricVerified: true,
        totalWorkHours: totalWorkHours,
        securityReviewStatus: securityReviewStatus,
        locationRiskLevel: locationRiskLevel,
        locationRiskReasons: locationRiskReasons,
        locationRiskMessage: locationRiskMessage,
        locationAccuracyMeters: accuracyMeters,
        locationDistanceMeters: distanceMeters,
        locationAllowedRadiusMeters: allowedRadius,
        locationCapturedOffline: true,
        status: existing.status,
      );
    }

    return AttendanceModel(
      attendanceId: attendanceId,
      userId: userId,
      employeeId: employeeId,
      employeeName: employeeName,
      locationId: locationId,
      locationName: locationName,
      managerId: managerId,
      date: date,
      checkInTime: eventTime,
      checkInLocation: GeoPoint(latitude, longitude),
      localCheckInTime: eventTime,
      isWithinGeofence: true,
      isLate: isLate,
      lateMinutes: lateMinutes,
      salaryDeductionFraction: salaryDeductionFraction,
      salaryDeductionAmount: salaryDeductionAmount,
      salaryCurrency: salaryCurrency,
      salaryDeductionCode: salaryDeductionCode,
      salaryDeductionLabel: salaryDeductionLabel,
      salaryDeductionApprovalStatus: salaryDeductionApprovalStatus,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      biometricVerified: true,
      securityReviewStatus: securityReviewStatus,
      locationRiskLevel: locationRiskLevel,
      locationRiskReasons: locationRiskReasons,
      locationRiskMessage: locationRiskMessage,
      locationAccuracyMeters: accuracyMeters,
      locationDistanceMeters: distanceMeters,
      locationAllowedRadiusMeters: allowedRadius,
      locationCapturedOffline: true,
      status: status,
    );
  }
}

class OfflineAttendanceQueueService {
  OfflineAttendanceQueueService._() {
    _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncPendingActions();
      }
    });
  }

  static final OfflineAttendanceQueueService instance =
      OfflineAttendanceQueueService._();

  static const _queueKey = 'offline_attendance_queue_v1';
  static const _deviceBindingPrefix = 'attendance_device_owner_';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<void> queue(OfflineAttendanceAction action) async {
    final actions = await pendingActions();
    final withoutSameAction = actions.where((item) => item.id != action.id);
    await _saveActions([...withoutSameAction, action]);
  }

  Future<List<OfflineAttendanceAction>> pendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => OfflineAttendanceAction.fromJson(item))
        .toList();
  }

  Future<List<AttendanceModel>> pendingLogsForMonth({
    required String userId,
    required String monthKey,
  }) async {
    final actions = await pendingActions();
    final relevant = actions.where(
      (action) =>
          action.userId == userId && action.date.startsWith('$monthKey-'),
    );
    final byAttendanceId = <String, AttendanceModel>{};
    for (final action in relevant) {
      final existing = byAttendanceId[action.attendanceId];
      byAttendanceId[action.attendanceId] = action.toLocalAttendanceModel(
        existing: existing,
      );
    }
    return byAttendanceId.values.toList();
  }

  Future<String?> localDeviceOwner(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceBindingPrefix + _deviceKey(deviceId));
  }

  Future<void> rememberLocalDeviceOwner({
    required String deviceId,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceBindingPrefix + _deviceKey(deviceId), userId);
  }

  Future<void> syncPendingActions() async {
    if (!await isOnline()) return;
    final actions = await pendingActions();
    if (actions.isEmpty) return;

    final remaining = <OfflineAttendanceAction>[];
    for (final action in actions) {
      try {
        await _syncAction(action);
      } catch (_) {
        remaining.add(action);
      }
    }
    await _saveActions(remaining);
  }

  Future<void> _syncAction(OfflineAttendanceAction action) async {
    await _ensureDeviceBinding(action);
    final ref = _db.collection('attendance').doc(action.attendanceId);
    if (action.type == OfflineAttendanceActionType.checkIn) {
      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set(action.toCheckInFirestore());
        await _notifySecurityReviewIfNeeded(action);
      }
      return;
    }

    final existing = await ref.get();
    if (!existing.exists) {
      throw StateError('Cannot sync checkout before check-in.');
    }
    await ref.update(action.toCheckOutFirestore());
    await _notifySecurityReviewIfNeeded(action);
  }

  Future<void> _notifySecurityReviewIfNeeded(
    OfflineAttendanceAction action,
  ) async {
    if (action.securityReviewStatus != 'pending_hr') return;
    await RoleNotificationService.instance.notifyRole(
      role: 'hr_admin',
      type: 'attendance_security_review',
      title: action.type == OfflineAttendanceActionType.checkOut
          ? 'انصراف يحتاج مراجعة أمنية'
          : 'حضور يحتاج مراجعة أمنية',
      body:
          '${action.employeeName}: ${action.locationRiskMessage ?? 'تم تسجيل حركة حضور بمؤشرات موقع غير معتادة.'}',
      data: {'attendanceId': action.attendanceId},
    );
  }

  Future<void> _ensureDeviceBinding(OfflineAttendanceAction action) async {
    final userRef = _db.collection('users').doc(action.userId);

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw StateError('User not found while syncing attendance.');
      }
      final userData = userSnap.data() ?? <String, dynamic>{};
      final registeredDeviceId =
          (userData['registeredAttendanceDeviceId'] as String?)?.trim() ?? '';
      if (registeredDeviceId.isNotEmpty) {
        if (registeredDeviceId != action.deviceId) {
          throw StateError('Attendance device belongs to another account.');
        }
        return;
      }

      throw StateError(
        'Attendance device must be registered online before offline attendance can sync.',
      );
    });
  }

  Future<void> _saveActions(List<OfflineAttendanceAction> actions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(actions.map((action) => action.toJson()).toList()),
    );
    _changes.add(null);
  }

  String _deviceKey(String deviceId) {
    return AttendanceSecurityService.deviceDocumentId(deviceId);
  }
}
