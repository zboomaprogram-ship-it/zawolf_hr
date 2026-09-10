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
    final results = await Future.wait(
      collections.map(
        // Pagination is performed after merging heterogeneous sources. Keep
        // every individual query capped while leaving enough candidates for
        // deterministic cross-source pages.
        (collection) => _loadCollection(collection, query, 300),
      ),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadCollection(
    String collection,
    RequestViewQuery query,
    int limit,
  ) async {
    Query<Map<String, dynamic>> request = _db.collection(collection);
    // Some existing accounts still hold historical role spellings.  Treat
    // them exactly like the current HR role so a valid HR reviewer does not
    // accidentally fall back to the manager-only query below.
    final role = query.actorScope.role.trim().toLowerCase();
    final isExecutive =
        query.actorScope.isExecutive ||
        query.actorScope.employeeCode?.trim().toUpperCase() == 'CEO-100' ||
        role == 'ceo' ||
        role == 'coo';
    final isHrOrAdmin =
        isExecutive ||
        const <String>{
          'hr',
          'hr_admin',
          'hr_manager',
          'super_admin',
          'admin',
        }.contains(role);
    try {
      // Legacy requests have one `managerId`; current sequential approvals
      // preserve the full chain in `managerIds`. Query both compatible shapes
      // and de-duplicate by document id so a secondary approver never loses a
      // valid request and a document containing both fields appears once.
      final empCode = query.actorScope.employeeCode?.trim() ?? '';
      final snapshots = collection == 'attendance'
          ? (isHrOrAdmin
                ? <Future<QuerySnapshot<Map<String, dynamic>>>>[
                    request
                        .where(
                          'salaryDeductionApprovalStatus',
                          whereIn: const ['pending_hr', 'approved', 'reversed'],
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
                  .where('managerIds', arrayContains: query.actorScope.actorId)
                  .limit(limit)
                  .get(),
              request
                  .where('currentApproverId', isEqualTo: query.actorScope.actorId)
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
      final docs = (await Future.wait(snapshots))
          .expand((snapshot) => snapshot.docs)
          .fold(<String, QueryDocumentSnapshot<Map<String, dynamic>>>{}, (
            unique,
            doc,
          ) {
            unique[doc.id] = doc;
            return unique;
          })
          .values;
      return docs
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
}
