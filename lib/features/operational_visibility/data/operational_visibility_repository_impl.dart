import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/employee_timeline_entry.dart';
import '../domain/entities/employee_timeline_query.dart';
import '../domain/entities/operational_visibility_setting.dart';
import '../domain/repositories/operational_visibility_repository.dart';

final class OperationalVisibilityRepositoryImpl
    implements OperationalVisibilityRepository {
  OperationalVisibilityRepositoryImpl({
    required FirebaseFirestore firestore,
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
  }) : _firestore = firestore,
       _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri;

  final FirebaseFirestore _firestore;
  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;

  @override
  Stream<Set<String>> watchHiddenEmployeeIds() => _firestore
      .collection('operationalVisibility')
      .where('hiddenFromAttendance', isEqualTo: true)
      .limit(500)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  @override
  Future<OperationalVisibilitySetting> setHidden({
    required String employeeUserId,
    required bool hidden,
    required String reasonAr,
    required String operationId,
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/visibility/$employeeUserId'),
      operationId: operationId,
      body: {'hidden': hidden, 'reasonAr': reasonAr},
    );
    if (!response.ok) throw StateError(response.safeCode);
    return OperationalVisibilitySetting(
      employeeUserId: employeeUserId,
      hiddenFromAttendance: hidden,
      version: int.tryParse('${response.data['version']}') ?? 1,
      reasonAr: reasonAr,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<EmployeeTimelinePage> loadTimeline(EmployeeTimelineQuery query) async {
    final uri = _operationsBaseUri
        .resolve('/operations/employee-timeline')
        .replace(
          queryParameters: {
            'employeeUserId': query.employeeUserId,
            'from': query.from.toUtc().toIso8601String(),
            'to': query.to.toUtc().toIso8601String(),
            'limit': '${query.pageSize}',
            if (query.cursor != null) 'cursor': query.cursor!,
          },
        );
    final response = await _operationClient.get(uri);
    if (!response.ok) throw StateError(response.safeCode);
    final rows = (response.data['items'] as List?) ?? const [];
    final summary = response.data['summary'] as Map?;
    return EmployeeTimelinePage(
      items: rows
          .whereType<Map>()
          .map((row) {
            final data = Map<String, Object?>.from(row);
            return EmployeeTimelineEntry(
              stableId: '${data['id'] ?? ''}',
              kind: _kind('${data['kind'] ?? ''}'),
              effectiveAt:
                  DateTime.tryParse('${data['effectiveAt'] ?? ''}') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              status: '${data['status'] ?? ''}',
              source: '${data['source'] ?? ''}',
              summaryAr: data['summaryAr']?.toString(),
            );
          })
          .toList(growable: false),
      hasMore: response.data['hasMore'] == true,
      summary: EmployeeTimelineSummary(
        salaryDeductionDays:
            (summary?['salaryDeductionDays'] as num?)?.toDouble() ?? 0,
        leaveRequests: (summary?['leaveRequests'] as num?)?.toInt() ?? 0,
        permissionRequests:
            (summary?['permissionRequests'] as num?)?.toInt() ?? 0,
        otherRequests: (summary?['otherRequests'] as num?)?.toInt() ?? 0,
      ),
      nextCursor: response.data['nextCursor']?.toString(),
    );
  }

  static EmployeeTimelineKind _kind(String value) => switch (value) {
    'attendance' => EmployeeTimelineKind.attendance,
    'leave' => EmployeeTimelineKind.leave,
    'permission' => EmployeeTimelineKind.permission,
    'correction' => EmployeeTimelineKind.correction,
    'request' => EmployeeTimelineKind.request,
    'deduction' => EmployeeTimelineKind.deduction,
    _ => EmployeeTimelineKind.unknown,
  };
}
