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
  StreamSubscription? _leavesRouteSub;
  StreamSubscription? _leavesCeoSub;
  StreamSubscription? _permissionsSub;
  StreamSubscription? _permissionsRouteSub;
  StreamSubscription? _permissionsCeoSub;
  StreamSubscription? _advancesSub;
  StreamSubscription? _advancesRouteSub;
  StreamSubscription? _advancesCeoSub;
  StreamSubscription? _administrativeSub;
  StreamSubscription? _administrativeRouteSub;
  StreamSubscription? _administrativeCeoSub;
  StreamSubscription? _resignationSub;
  StreamSubscription? _resignationRouteSub;

  final _leavesLegacyIds = <String>{};
  final _leavesRouteIds = <String>{};
  final _leavesCeoIds = <String>{};
  final _permissionsLegacyIds = <String>{};
  final _permissionsRouteIds = <String>{};
  final _permissionsCeoIds = <String>{};
  final _advancesLegacyIds = <String>{};
  final _advancesRouteIds = <String>{};
  final _advancesCeoIds = <String>{};
  final _administrativeLegacyIds = <String>{};
  final _administrativeRouteIds = <String>{};
  final _administrativeCeoIds = <String>{};
  final _resignationLegacyIds = <String>{};
  final _resignationRouteIds = <String>{};

  int get leavesCount =>
      _combinedCount(_leavesLegacyIds, _leavesRouteIds, _leavesCeoIds);
  int get permissionsCount => _combinedCount(
    _permissionsLegacyIds,
    _permissionsRouteIds,
    _permissionsCeoIds,
  );
  int get advancesCount =>
      _combinedCount(_advancesLegacyIds, _advancesRouteIds, _advancesCeoIds);
  int get administrativeCount => _combinedCount(
    _administrativeLegacyIds,
    _administrativeRouteIds,
    _administrativeCeoIds,
  );
  int get resignationCount =>
      _combinedCount(_resignationLegacyIds, _resignationRouteIds);

  String? get firstPendingCategory {
    // Use the largest outstanding queue. This avoids opening an arbitrary
    // first tab when several request types need attention at the same time.
    final counts = <String, int>{
      'leaves': leavesCount,
      'permissions': permissionsCount,
      'advances': advancesCount,
      'administrative': administrativeCount,
      'resignations': resignationCount,
    };
    final highest = counts.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );
    if (highest.value > 0) return highest.key;
    return null;
  }

  /// A stable request destination for dashboard shortcuts. The listener sets
  /// are deliberately de-duplicated because the same request can be visible
  /// through both a legacy status query and a routed-approval query.
  String? firstPendingRequestId(String category) {
    final ids =
        switch (category) {
            'leaves' => <String>{
              ..._leavesLegacyIds,
              ..._leavesRouteIds,
              ..._leavesCeoIds,
            },
            'permissions' => <String>{
              ..._permissionsLegacyIds,
              ..._permissionsRouteIds,
              ..._permissionsCeoIds,
            },
            'advances' => <String>{
              ..._advancesLegacyIds,
              ..._advancesRouteIds,
              ..._advancesCeoIds,
            },
            'administrative' => <String>{
              ..._administrativeLegacyIds,
              ..._administrativeRouteIds,
              ..._administrativeCeoIds,
            },
            'resignations' => <String>{
              ..._resignationLegacyIds,
              ..._resignationRouteIds,
            },
            _ => <String>{},
          }.toList()
          ..sort();
    return ids.isEmpty ? null : ids.first;
  }

  void startListening(UserModel reviewer) {
    stopListening();

    _clearIds();
    pendingCount.value = 0;

    // An HR account may also be CEO-100. Its default work queue must remain
    // the HR stage; CEO-specific requests are added separately below.
    final isCompanyCeo = reviewer.canReviewCeoStage;
    final isHrStaff = EmployeeRole.isHrStaff(reviewer.role);
    final reviewsManagerStage =
        !isHrStaff &&
        (isCompanyCeo ||
            reviewer.role == EmployeeRole.manager ||
            reviewer.role == EmployeeRole.teamLeader ||
            reviewer.role == EmployeeRole.superAdmin);

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
    } else if (isHrStaff) {
      leavesQuery = leavesQuery.where('status', isEqualTo: 'pending_hr');
    }

    _leavesSub = leavesQuery.snapshots().listen(
      (snap) {
        _replaceIds(_leavesLegacyIds, snap);
      },
      onError: (_) {
        _clearIdsAndUpdate(_leavesLegacyIds);
      },
    );
    if (isHrStaff || isCompanyCeo) {
      _leavesRouteSub = _watchCurrentApprover(
        collection: 'leaves',
        reviewerId: reviewer.uid,
        target: _leavesRouteIds,
      );
    }
    if (isCompanyCeo) {
      _leavesCeoSub = _watchCeoStage(
        collection: 'leaves',
        reviewerId: reviewer.uid,
        target: _leavesCeoIds,
      );
    }

    // 2. Permissions
    Query<Map<String, dynamic>> permissionsQuery = _db.collection(
      'permissions',
    );
    if (reviewsManagerStage) {
      permissionsQuery = permissionsQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: 'pending_manager');
    } else if (isHrStaff) {
      permissionsQuery = permissionsQuery.where(
        'status',
        isEqualTo: 'pending_hr',
      );
    }

    _permissionsSub = permissionsQuery.snapshots().listen(
      (snap) {
        _replaceIds(_permissionsLegacyIds, snap);
      },
      onError: (_) {
        _clearIdsAndUpdate(_permissionsLegacyIds);
      },
    );
    if (isHrStaff || isCompanyCeo) {
      _permissionsRouteSub = _watchCurrentApprover(
        collection: 'permissions',
        reviewerId: reviewer.uid,
        target: _permissionsRouteIds,
      );
    }
    if (isCompanyCeo) {
      _permissionsCeoSub = _watchCeoStage(
        collection: 'permissions',
        reviewerId: reviewer.uid,
        target: _permissionsCeoIds,
      );
    }

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
        _replaceIds(_advancesLegacyIds, snap);
      },
      onError: (_) {
        _clearIdsAndUpdate(_advancesLegacyIds);
      },
    );
    if (isHrStaff || isCompanyCeo) {
      _advancesRouteSub = _watchCurrentApprover(
        collection: 'advances',
        reviewerId: reviewer.uid,
        target: _advancesRouteIds,
      );
    }
    if (isCompanyCeo) {
      _advancesCeoSub = _watchCeoStage(
        collection: 'advances',
        reviewerId: reviewer.uid,
        target: _advancesCeoIds,
      );
    }

    // 4. Administrative requests
    Query<Map<String, dynamic>> adminQuery = _db.collection(
      'administrativeRequests',
    );
    if (reviewsManagerStage) {
      adminQuery = adminQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: 'pending_manager');
    } else if (isHrStaff) {
      adminQuery = adminQuery.where('status', isEqualTo: 'pending_hr');
    }

    _administrativeSub = adminQuery.snapshots().listen(
      (snap) {
        _replaceIds(_administrativeLegacyIds, snap);
      },
      onError: (_) {
        _clearIdsAndUpdate(_administrativeLegacyIds);
      },
    );
    if (isHrStaff || isCompanyCeo) {
      _administrativeRouteSub = _watchCurrentApprover(
        collection: 'administrativeRequests',
        reviewerId: reviewer.uid,
        target: _administrativeRouteIds,
      );
    }
    if (isCompanyCeo) {
      _administrativeCeoSub = _watchCeoStage(
        collection: 'administrativeRequests',
        reviewerId: reviewer.uid,
        target: _administrativeCeoIds,
      );
    }

    // 5. Resignations
    Query<Map<String, dynamic>> resignationQuery = _db.collection(
      'resignations',
    );
    if (reviewsManagerStage) {
      resignationQuery = resignationQuery
          .where('managerId', isEqualTo: reviewer.uid)
          .where('status', isEqualTo: 'pending_manager');
    } else if (isHrStaff) {
      resignationQuery = resignationQuery.where(
        'status',
        isEqualTo: 'pending_hr',
      );
    }

    _resignationSub = resignationQuery.snapshots().listen(
      (snap) {
        _replaceIds(_resignationLegacyIds, snap);
      },
      onError: (_) {
        _clearIdsAndUpdate(_resignationLegacyIds);
      },
    );
    if (isHrStaff || isCompanyCeo) {
      _resignationRouteSub = _watchCurrentApprover(
        collection: 'resignations',
        reviewerId: reviewer.uid,
        target: _resignationRouteIds,
      );
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _watchCurrentApprover({
    required String collection,
    required String reviewerId,
    required Set<String> target,
  }) => _db
      .collection(collection)
      .where('currentApproverId', isEqualTo: reviewerId)
      .snapshots()
      .listen(
        (snap) => _replaceIds(target, snap),
        onError: (_) => _clearIdsAndUpdate(target),
      );

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _watchCeoStage({
    required String collection,
    required String reviewerId,
    required Set<String> target,
  }) => _db
      .collection(collection)
      .where('status', isEqualTo: 'pending_ceo')
      .snapshots()
      .listen((snap) {
        target
          ..clear()
          ..addAll(
            snap.docs
                .where((doc) {
                  final ceoId = (doc.data()['ceoId'] ?? '').toString();
                  return ceoId.isEmpty ||
                      ceoId == reviewerId ||
                      ceoId == 'CEO-100';
                })
                .map((doc) => doc.id),
          );
        _updateCount();
      }, onError: (_) => _clearIdsAndUpdate(target));

  void _replaceIds(
    Set<String> target,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    target
      ..clear()
      ..addAll(snapshot.docs.map((doc) => doc.id));
    _updateCount();
  }

  void _clearIdsAndUpdate(Set<String> target) {
    target.clear();
    _updateCount();
  }

  int _combinedCount(
    Set<String> first,
    Set<String> second, [
    Set<String>? third,
  ]) => {...first, ...second, ...?third}.length;

  void _clearIds() {
    for (final ids in [
      _leavesLegacyIds,
      _leavesRouteIds,
      _leavesCeoIds,
      _permissionsLegacyIds,
      _permissionsRouteIds,
      _permissionsCeoIds,
      _advancesLegacyIds,
      _advancesRouteIds,
      _advancesCeoIds,
      _administrativeLegacyIds,
      _administrativeRouteIds,
      _administrativeCeoIds,
      _resignationLegacyIds,
      _resignationRouteIds,
    ]) {
      ids.clear();
    }
  }

  void _updateCount() {
    pendingCount.value =
        leavesCount +
        permissionsCount +
        advancesCount +
        administrativeCount +
        resignationCount;
  }

  void stopListening() {
    _leavesSub?.cancel();
    _leavesRouteSub?.cancel();
    _leavesCeoSub?.cancel();
    _permissionsSub?.cancel();
    _permissionsRouteSub?.cancel();
    _permissionsCeoSub?.cancel();
    _advancesSub?.cancel();
    _advancesRouteSub?.cancel();
    _advancesCeoSub?.cancel();
    _administrativeSub?.cancel();
    _administrativeRouteSub?.cancel();
    _administrativeCeoSub?.cancel();
    _resignationSub?.cancel();
    _resignationRouteSub?.cancel();
    _leavesSub = null;
    _leavesRouteSub = null;
    _leavesCeoSub = null;
    _permissionsSub = null;
    _permissionsRouteSub = null;
    _permissionsCeoSub = null;
    _advancesSub = null;
    _advancesRouteSub = null;
    _advancesCeoSub = null;
    _administrativeSub = null;
    _administrativeRouteSub = null;
    _administrativeCeoSub = null;
    _resignationSub = null;
    _resignationRouteSub = null;
    _clearIds();
    pendingCount.value = 0;
  }
}
