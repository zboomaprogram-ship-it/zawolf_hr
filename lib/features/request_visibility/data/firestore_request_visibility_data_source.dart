import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/request_view_query.dart';
import 'request_visibility_repository.dart';

/// Bounded Firestore adapter for the read-only request visibility model.
/// It reads a fixed number of records per source and never rewrites legacy
/// documents simply to make history visible.
final class FirestoreRequestVisibilityDataSource
    implements RequestVisibilityDataSource {
  FirestoreRequestVisibilityDataSource({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<Map<String, dynamic>>> loadBounded(RequestViewQuery query) async {
    const collections = <String>[
      'leaves',
      'permissions',
      'advances',
      'attendanceCorrectionRequests',
      'administrativeRequests',
      'complaints',
      'resignations',
      'employeeDeletionRequests',
      'manual_deductions',
      'attendance',
    ];
    final matchingEmployeeIds = await _matchingEmployeeIds(query);
    final results = await Future.wait(
      collections.map(
        // Pagination is performed after merging heterogeneous sources. Keep
        // every individual query capped while leaving enough candidates for
        // deterministic cross-source pages.
        (collection) => _loadCollection(
          collection,
          query,
          300,
          matchingEmployeeIds: matchingEmployeeIds,
        ),
      ),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadCollection(
    String collection,
    RequestViewQuery query,
    int limit, {
    required List<String> matchingEmployeeIds,
  }) async {
    Query<Map<String, dynamic>> request = _db.collection(collection);
    // Some existing accounts still hold historical role spellings.  Treat
    // them exactly like the current HR role so a valid HR reviewer does not
    // accidentally fall back to the manager-only query below.
    final role = query.actorScope.role.trim().toLowerCase();
    // COO-1300 is an assigned workflow reviewer. It must not inherit the
    // unrestricted read model used by the legacy super-admin account role.
    final isRestrictedCoo =
        query.actorScope.employeeCode?.trim().toUpperCase() == 'COO-1300';
    final isExecutive =
        (query.actorScope.isExecutive && !isRestrictedCoo) ||
        query.actorScope.employeeCode?.trim().toUpperCase() == 'CEO-100' ||
        role == 'ceo' ||
        (role == 'coo' && !isRestrictedCoo);
    final isHrOrAdmin =
        (isExecutive && !isRestrictedCoo) ||
        const <String>{
              'hr',
              'hr_admin',
              'hr_manager',
              'super_admin',
              'admin',
            }.contains(role) &&
            !isRestrictedCoo;
    try {
      final employeeCode = _exactEmployeeCode(query.searchTerm);
      // Legacy requests have one `managerId`; current sequential approvals
      // preserve the full chain in `managerIds`. Query both compatible shapes
      // and de-duplicate by document id so a secondary approver never loses a
      // valid request and a document containing both fields appears once.
      final empCode = query.actorScope.employeeCode?.trim() ?? '';
      final snapshots =
          collection == 'attendance'
              ? (isHrOrAdmin
                  ? <Future<QuerySnapshot<Map<String, dynamic>>>>[
                    request
                        .where(
                          'salaryDeductionApprovalStatus',
                          whereIn: const [
                            'pending_hr',
                            'approved',
                            'reversed',
                            'rejected',
                          ],
                        )
                        .limit(limit)
                        .get(),
                  ]
                  : <Future<QuerySnapshot<Map<String, dynamic>>>>[])
              : isHrOrAdmin
              ? <Future<QuerySnapshot<Map<String, dynamic>>>>[
                request.limit(limit).get(),
              ]
              : <Future<QuerySnapshot<Map<String, dynamic>>>>[
                request
                    .where('managerId', isEqualTo: query.actorScope.actorId)
                    .limit(limit)
                    .get(),
                request
                    .where(
                      'managerIds',
                      arrayContains: query.actorScope.actorId,
                    )
                    .limit(limit)
                    .get(),
                request
                    .where(
                      'currentApproverId',
                      isEqualTo: query.actorScope.actorId,
                    )
                    .limit(limit)
                    .get(),
                if (empCode.isNotEmpty) ...[
                  request
                      .where('managerId', isEqualTo: empCode)
                      .limit(limit)
                      .get(),
                  request
                      .where('managerCodes', arrayContains: empCode)
                      .limit(limit)
                      .get(),
                  request
                      .where('currentApproverId', isEqualTo: empCode)
                      .limit(limit)
                      .get(),
                ],
              ];
      // Searching an exact employee code is a financial drill-down, not a
      // client-side filter over the first company-wide page. Keep the normal
      // page for general search, then merge this bounded employee query so
      // historical deductions such as MKT-600's are never hidden by records
      // belonging to other staff members.
      if (isHrOrAdmin && employeeCode != null) {
        snapshots.add(
          request.where('employeeId', isEqualTo: employeeCode).limit(500).get(),
        );
      }
      // Firestore cannot perform a contains search over display names. Resolve
      // the small, authorized employee directory once in [loadBounded], then
      // fetch this employee's records by immutable user ID. This preserves a
      // bounded read while making a name fragment such as "أشرف" return the
      // same complete financial history as the employee code.
      if (isHrOrAdmin && matchingEmployeeIds.isNotEmpty) {
        for (final ids in _chunks(matchingEmployeeIds, 10)) {
          snapshots.add(request.where('userId', whereIn: ids).limit(500).get());
        }
      }
      final docs =
          (await Future.wait(
            snapshots,
          )).expand((snapshot) => snapshot.docs).fold(
            <String, QueryDocumentSnapshot<Map<String, dynamic>>>{},
            (unique, doc) {
              unique[doc.id] = doc;
              return unique;
            },
          ).values;
      return docs
          .where(
            (doc) =>
                collection != 'attendance' ||
                const <String>{
                  'pending_hr',
                  'approved',
                  'reversed',
                  'rejected',
                }.contains(
                  '${doc.data()['salaryDeductionApprovalStatus'] ?? ''}',
                ),
          )
          .map((doc) {
            final data = <String, dynamic>{
              ...doc.data(),
              'id': doc.id,
              'sourceCollection': collection,
              'sourceReference': '$collection/${doc.id}',
            };
            data.putIfAbsent(
              'requestType',
              () => _typeForCollection(collection),
            );
            return data;
          })
          .toList(growable: false);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const RequestVisibilityAccessDenied();
      }
      rethrow;
    }
  }

  String _typeForCollection(String collection) => switch (collection) {
    'leaves' => 'leave',
    'permissions' => 'permission',
    'advances' => 'advance',
    'attendanceCorrectionRequests' => 'attendance_correction',
    'administrativeRequests' => 'administrative',
    'complaints' => 'complaint',
    'resignations' => 'resignation',
    'employeeDeletionRequests' => 'employee_deletion',
    'manual_deductions' => 'salary_deduction',
    'attendance' => 'late_arrival_deduction',
    _ => 'unknown',
  };

  String? _exactEmployeeCode(String raw) {
    final code = raw.trim().toUpperCase();
    // This intentionally accepts only a complete employee code. Names and
    // partial words continue through the regular bounded company view.
    return RegExp(r'^[A-Z&]{1,12}-\d{1,8}[A-Z]?$').hasMatch(code) ? code : null;
  }

  Future<List<String>> _matchingEmployeeIds(RequestViewQuery query) async {
    final needle = _normalized(query.searchTerm);
    if (needle.length < 2 || !_hasCompanyScope(query)) return const [];
    final users =
        await _db
            .collection('users')
            .where('isActive', isEqualTo: true)
            .limit(300)
            .get();
    return users.docs
        .where((doc) {
          final data = doc.data();
          return <Object?>[
            data['displayName'],
            data['name'],
            data['employeeId'],
            data['employeeCode'],
          ].any((value) => _normalized('$value').contains(needle));
        })
        .map((doc) => doc.id)
        // Firestore permits at most ten values in one `whereIn`; retaining
        // the first ten matching employees keeps a partial-name search within
        // one extra bounded query per source.
        .take(10)
        .toList(growable: false);
  }

  bool _hasCompanyScope(RequestViewQuery query) {
    final role = query.actorScope.role.trim().toLowerCase();
    final restrictedCoo =
        query.actorScope.employeeCode?.trim().toUpperCase() == 'COO-1300';
    if (restrictedCoo) return false;
    return query.actorScope.isExecutive ||
        query.actorScope.employeeCode?.trim().toUpperCase() == 'CEO-100' ||
        role == 'ceo' ||
        role == 'coo' ||
        const <String>{
          'hr',
          'hr_admin',
          'hr_manager',
          'super_admin',
          'admin',
        }.contains(role);
  }

  String _normalized(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Iterable<List<String>> _chunks(List<String> values, int size) sync* {
    for (var start = 0; start < values.length; start += size) {
      yield values.sublist(
        start,
        start + size > values.length ? values.length : start + size,
      );
    }
  }
}
