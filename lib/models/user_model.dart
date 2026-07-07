import 'package:cloud_firestore/cloud_firestore.dart';

class WorkSchedule {
  final String? startTime;
  final String? endTime;
  final List<int>? workDays;

  WorkSchedule({this.startTime, this.endTime, this.workDays});

  factory WorkSchedule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return WorkSchedule();
    return WorkSchedule(
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
      workDays: (map['workDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (workDays != null) 'workDays': workDays,
    };
  }
}

class LeaveBalance {
  final int annual;
  final int sick;
  final int casual;
  final int daysOff;

  LeaveBalance({
    required this.annual,
    required this.sick,
    required this.casual,
    required this.daysOff,
  });

  factory LeaveBalance.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return LeaveBalance(annual: 21, sick: 14, casual: 7, daysOff: 21);
    }
    return LeaveBalance(
      annual: map['annual'] as int? ?? 21,
      sick: map['sick'] as int? ?? 14,
      casual: map['casual'] as int? ?? 7,
      daysOff: map['daysOff'] as int? ?? 21,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'annual': annual,
      'sick': sick,
      'casual': casual,
      'daysOff': daysOff,
    };
  }
}

class PermissionBalance {
  final int usedThisMonth;
  final double usedHoursThisMonth;
  final String lastResetMonth;

  PermissionBalance({
    required this.usedThisMonth,
    required this.usedHoursThisMonth,
    required this.lastResetMonth,
  });

  factory PermissionBalance.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return PermissionBalance(
        usedThisMonth: 0,
        usedHoursThisMonth: 0.0,
        lastResetMonth: '',
      );
    }
    return PermissionBalance(
      usedThisMonth: map['usedThisMonth'] as int? ?? 0,
      usedHoursThisMonth:
          (map['usedHoursThisMonth'] as num?)?.toDouble() ?? 0.0,
      lastResetMonth: map['lastResetMonth'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usedThisMonth': usedThisMonth,
      'usedHoursThisMonth': usedHoursThisMonth,
      'lastResetMonth': lastResetMonth,
    };
  }
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String role; // 'employee' | 'manager' | 'hr_admin'
  final String employeeId;
  final String department;
  final String position;
  final String locationId;
  final String locationName;
  final double baseMonthlySalary;
  final String salaryCurrency;
  final String? managerId;
  final String? managerName;
  final List<String> managerIds;
  final List<String> managerNames;
  final List<String> managerCodes;
  final bool isActive;
  final DateTime? joinDate;
  final WorkSchedule workSchedule;
  final LeaveBalance leaveBalance;
  final PermissionBalance permissionBalance;
  final List<String> notificationTokens;
  final int unreadNotifications;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? passwordChangedAt;
  final String? registeredAttendanceDeviceId;
  final String? registeredAttendanceDeviceLabel;
  final DateTime? registeredAttendanceDeviceAt;
  final String? initialPassword; // Local visual support on account creation

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.role,
    required this.employeeId,
    required this.department,
    required this.position,
    required this.locationId,
    required this.locationName,
    this.baseMonthlySalary = 0,
    this.salaryCurrency = 'EGP',
    this.managerId,
    this.managerName,
    this.managerIds = const [],
    this.managerNames = const [],
    this.managerCodes = const [],
    this.isActive = true,
    this.joinDate,
    required this.workSchedule,
    required this.leaveBalance,
    required this.permissionBalance,
    this.notificationTokens = const [],
    this.unreadNotifications = 0,
    this.createdAt,
    this.updatedAt,
    this.passwordChangedAt,
    this.registeredAttendanceDeviceId,
    this.registeredAttendanceDeviceLabel,
    this.registeredAttendanceDeviceAt,
    this.initialPassword,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      role: data['role'] as String? ?? 'employee',
      employeeId: data['employeeId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      position: data['position'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      baseMonthlySalary: (data['baseMonthlySalary'] as num?)?.toDouble() ?? 0,
      salaryCurrency: data['salaryCurrency'] as String? ?? 'EGP',
      managerId: data['managerId'] as String?,
      managerName: data['managerName'] as String?,
      managerIds:
          (data['managerIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ((data['managerId'] as String?) == null
              ? const []
              : [data['managerId'] as String]),
      managerNames:
          (data['managerNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ((data['managerName'] as String?) == null
              ? const []
              : [data['managerName'] as String]),
      managerCodes:
          (data['managerCodes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: data['isActive'] as bool? ?? true,
      joinDate: (data['joinDate'] as Timestamp?)?.toDate(),
      workSchedule: WorkSchedule.fromMap(
        data['workSchedule'] as Map<String, dynamic>?,
      ),
      leaveBalance: LeaveBalance.fromMap(
        data['leaveBalance'] as Map<String, dynamic>?,
      ),
      permissionBalance: PermissionBalance.fromMap(
        data['permissionBalance'] as Map<String, dynamic>?,
      ),
      notificationTokens:
          (data['notificationTokens'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      unreadNotifications: data['unreadNotifications'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      passwordChangedAt: (data['passwordChangedAt'] as Timestamp?)?.toDate(),
      registeredAttendanceDeviceId:
          data['registeredAttendanceDeviceId'] as String?,
      registeredAttendanceDeviceLabel:
          data['registeredAttendanceDeviceLabel'] as String?,
      registeredAttendanceDeviceAt:
          (data['registeredAttendanceDeviceAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      'role': role,
      'employeeId': employeeId,
      'department': department,
      'position': position,
      'locationId': locationId,
      'locationName': locationName,
      'baseMonthlySalary': baseMonthlySalary,
      'salaryCurrency': salaryCurrency,
      if (managerId != null) 'managerId': managerId,
      if (managerName != null) 'managerName': managerName,
      if (managerIds.isNotEmpty) 'managerIds': managerIds,
      if (managerNames.isNotEmpty) 'managerNames': managerNames,
      if (managerCodes.isNotEmpty) 'managerCodes': managerCodes,
      'isActive': isActive,
      if (joinDate != null) 'joinDate': Timestamp.fromDate(joinDate!),
      'workSchedule': workSchedule.toMap(),
      'leaveBalance': leaveBalance.toMap(),
      'permissionBalance': permissionBalance.toMap(),
      'notificationTokens': notificationTokens,
      'unreadNotifications': unreadNotifications,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (passwordChangedAt != null)
        'passwordChangedAt': Timestamp.fromDate(passwordChangedAt!),
      if (registeredAttendanceDeviceId != null)
        'registeredAttendanceDeviceId': registeredAttendanceDeviceId,
      if (registeredAttendanceDeviceLabel != null)
        'registeredAttendanceDeviceLabel': registeredAttendanceDeviceLabel,
      if (registeredAttendanceDeviceAt != null)
        'registeredAttendanceDeviceAt': Timestamp.fromDate(
          registeredAttendanceDeviceAt!,
        ),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? role,
    String? employeeId,
    String? department,
    String? position,
    String? locationId,
    String? locationName,
    double? baseMonthlySalary,
    String? salaryCurrency,
    String? managerId,
    String? managerName,
    List<String>? managerIds,
    List<String>? managerNames,
    List<String>? managerCodes,
    bool? isActive,
    DateTime? joinDate,
    WorkSchedule? workSchedule,
    LeaveBalance? leaveBalance,
    PermissionBalance? permissionBalance,
    List<String>? notificationTokens,
    int? unreadNotifications,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? passwordChangedAt,
    String? registeredAttendanceDeviceId,
    String? registeredAttendanceDeviceLabel,
    DateTime? registeredAttendanceDeviceAt,
    String? initialPassword,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      position: position ?? this.position,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      baseMonthlySalary: baseMonthlySalary ?? this.baseMonthlySalary,
      salaryCurrency: salaryCurrency ?? this.salaryCurrency,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      managerIds: managerIds ?? this.managerIds,
      managerNames: managerNames ?? this.managerNames,
      managerCodes: managerCodes ?? this.managerCodes,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      workSchedule: workSchedule ?? this.workSchedule,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      permissionBalance: permissionBalance ?? this.permissionBalance,
      notificationTokens: notificationTokens ?? this.notificationTokens,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      registeredAttendanceDeviceId:
          registeredAttendanceDeviceId ?? this.registeredAttendanceDeviceId,
      registeredAttendanceDeviceLabel:
          registeredAttendanceDeviceLabel ??
          this.registeredAttendanceDeviceLabel,
      registeredAttendanceDeviceAt:
          registeredAttendanceDeviceAt ?? this.registeredAttendanceDeviceAt,
      initialPassword: initialPassword ?? this.initialPassword,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
