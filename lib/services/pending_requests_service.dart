import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';

class PendingRequestsService {
  PendingRequestsService._internal();
  static final PendingRequestsService instance =
      PendingRequestsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  StreamSubscription? _leavesSub;
  StreamSubscription? _permissionsSub;
  StreamSubscription? _advancesSub;

  int _leavesCount = 0;
  int _permissionsCount = 0;
  int _advancesCount = 0;

  void startListening(UserModel reviewer) {
    stopListening();

    _leavesCount = 0;
    _permissionsCount = 0;
    _advancesCount = 0;
    pendingCount.value = 0;

    // CEO-100 can be assigned as a direct manager while retaining an HR role.
    // Treat that assignment as a manager-review surface for the notification
    // badge; otherwise pending_manager requests are silently omitted.
    final isCompanyCeo = reviewer.employeeId.trim().toUpperCase() == 'CEO-100';
    final reviewsManagerStage =
        isCompanyCeo ||
        reviewer.role == EmployeeRole.manager ||
        reviewer.role == EmployeeRole.teamLeader ||
        reviewer.role == EmployeeRole.superAdmin;

    String targetStatus = 'pending_hr';
    if (reviewsManagerStage) {
      targetStatus = 'pending_manager';
    }

    // 1. Leaves
    Query<Map<String, dynamic>> leavesQuery = _db.collection('leaves');
    if (reviewsManagerStage) {
      leavesQuery = leavesQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: 'pending_manager');
    } else if (EmployeeRole.isHrStaff(reviewer.role)) {
      leavesQuery = leavesQuery.where('status', isEqualTo: 'pending_hr');
    }

    _leavesSub = leavesQuery.snapshots().listen(
      (snap) {
        _leavesCount = snap.docs.length;
        _updateCount();
      },
      onError: (_) {
        _leavesCount = 0;
        _updateCount();
      },
    );

    // 2. Permissions
    Query<Map<String, dynamic>> permissionsQuery = _db.collection(
      'permissions',
    );
    if (reviewsManagerStage) {
      permissionsQuery = permissionsQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: 'pending_manager');
    } else if (EmployeeRole.isHrStaff(reviewer.role)) {
      permissionsQuery = permissionsQuery.where(
        'status',
        isEqualTo: 'pending_hr',
      );
    }

    _permissionsSub = permissionsQuery.snapshots().listen(
      (snap) {
        _permissionsCount = snap.docs.length;
        _updateCount();
      },
      onError: (_) {
        _permissionsCount = 0;
        _updateCount();
      },
    );

    // 3. Advances
    Query<Map<String, dynamic>> advancesQuery = _db.collection('advances');
    if (reviewsManagerStage) {
      advancesQuery = advancesQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: targetStatus);
    } else if (reviewer.role == EmployeeRole.hrAdmin) {
      advancesQuery = advancesQuery.where('status', isEqualTo: targetStatus);
    } else if (reviewer.role == EmployeeRole.hrManager) {
      advancesQuery = advancesQuery.where(
        'status',
        whereIn: ['pending_hr', 'pending_manager'],
      );
    } else if (reviewer.role == EmployeeRole.superAdmin) {
      advancesQuery = advancesQuery.where(
        'status',
        whereIn: ['pending_hr', 'pending_manager'],
      );
    }

    _advancesSub = advancesQuery.snapshots().listen(
      (snap) {
        _advancesCount = snap.docs.length;
        _updateCount();
      },
      onError: (_) {
        _advancesCount = 0;
        _updateCount();
      },
    );
  }

  void _updateCount() {
    pendingCount.value = _leavesCount + _permissionsCount + _advancesCount;
  }

  void stopListening() {
    _leavesSub?.cancel();
    _permissionsSub?.cancel();
    _advancesSub?.cancel();
    _leavesSub = null;
    _permissionsSub = null;
    _advancesSub = null;
    pendingCount.value = 0;
  }
}
