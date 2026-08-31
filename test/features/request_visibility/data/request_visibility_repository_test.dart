import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_visibility/data/request_visibility_repository.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_view_query.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_visibility_record.dart';
import 'package:zawolf_hr/features/request_visibility/domain/repositories/request_visibility_repository.dart';
import '../../../fixtures/request_visibility_fixtures.dart';

void main() {
  final query = RequestViewQuery(
    actorScope: const RequestActorScope(actorId: 'hr', role: 'hr'),
    tab: RequestViewTab.deductions,
    fromDate: DateTime.utc(2026),
    toDate: DateTime.utc(2026, 12, 31),
  );

  test(
    'normalizes confirmed and historical deduction shapes without writes',
    () async {
      final repository = RequestVisibilityRepositoryImpl(
        _Source([
          confirmedLateArrivalDeduction,
          legacyConfirmedSalaryDeduction,
        ]),
      );

      final result = await repository.load(query);
      expect(result, isA<RequestViewLoaded>());
      final records = (result as RequestViewLoaded).records;
      expect(records, hasLength(2));
      expect(records.first.sourceType, RequestSourceType.lateArrivalDeduction);
      expect(records.last.lifecycleState, RequestLifecycleState.confirmed);
    },
  );

  test(
    'returns a safe retry state without leaking provider diagnostics',
    () async {
      final repository = RequestVisibilityRepositoryImpl(_ThrowingSource());
      final result = await repository.load(query);
      expect(result, isA<RequestViewRetryableFailure>());
      expect(
        (result as RequestViewRetryableFailure).safeMessage,
        isNot(contains('cloud_firestore')),
      );
    },
  );

  test(
    'normalizes Firestore timestamp dates without losing historic records',
    () {
      final record = RequestVisibilityNormalizer.fromMap({
        'id': 'legacy-deduction',
        'userId': 'employee-1',
        'attendanceDate': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
        'requestType': 'late_deduction',
        'status': 'confirmed',
      });

      expect(record, isNotNull);
      expect(record!.occurredAt, DateTime.utc(2026, 8, 12));
      expect(record.sourceType, RequestSourceType.lateArrivalDeduction);
    },
  );

  test(
    'uses business date fallbacks and deterministic merged pagination',
    () async {
      final records = <Map<String, dynamic>>[
        {
          'id': 'newer',
          'userId': 'employee-1',
          'requestType': 'administrative',
          'status': 'approved',
          'submittedAt': '2026-08-20T10:00:00.000Z',
        },
        {
          'id': 'older',
          'userId': 'employee-1',
          'requestType': 'leave',
          'status': 'approved',
          'startDate': '2026-08-19',
        },
      ];
      final repository = RequestVisibilityRepositoryImpl(_Source(records));
      final first = await repository.load(
        RequestViewQuery(
          actorScope: const RequestActorScope(actorId: 'hr', role: 'hr'),
          tab: RequestViewTab.history,
          fromDate: DateTime.utc(2026),
          toDate: DateTime.utc(2026, 12, 31),
          pageSize: 1,
        ),
      );
      expect(first, isA<RequestViewLoaded>());
      final firstPage = first as RequestViewLoaded;
      expect(firstPage.records.single.stableId, 'newer');
      expect(firstPage.nextCursor, isNotNull);

      final second = await repository.load(
        RequestViewQuery(
          actorScope: const RequestActorScope(actorId: 'hr', role: 'hr'),
          tab: RequestViewTab.history,
          fromDate: DateTime.utc(2026),
          toDate: DateTime.utc(2026, 12, 31),
          pageSize: 1,
          pageCursor: firstPage.nextCursor,
        ),
      );
      expect((second as RequestViewLoaded).records.single.stableId, 'older');
    },
  );

  test('maps attendance salary approval status without legacy status', () {
    final record = RequestVisibilityNormalizer.fromMap({
      'id': 'attendance-deduction',
      'userId': 'employee-1',
      'sourceCollection': 'attendance',
      'requestType': 'late_arrival_deduction',
      'salaryDeductionApprovalStatus': 'pending_hr',
      'dateKey': '2026-08-21',
    });

    expect(record, isNotNull);
    expect(record!.lifecycleState, RequestLifecycleState.pending);
    expect(record.approvalStage, RequestApprovalStage.hr);
  });

  test('keeps legacy requester ids and updated timestamps visible', () {
    final record = RequestVisibilityNormalizer.fromMap({
      'id': 'legacy-request',
      'requestedById': 'employee-legacy',
      'requestType': 'administrative',
      'status': 'pending',
      'updatedAt': '2026-08-24T09:30:00.000Z',
    });

    expect(record, isNotNull);
    expect(record!.employeeId, 'employee-legacy');
    expect(record.occurredAt, DateTime.utc(2026, 8, 24, 9, 30));
  });

  test('recognizes complaint resignation and account deletion sources', () {
    final complaint = RequestVisibilityNormalizer.fromMap({
      'id': 'complaint-1',
      'userId': 'employee-1',
      'requestType': 'complaint',
      'status': 'pending_hr',
      'createdAt': '2026-08-24T09:30:00.000Z',
    });
    final resignation = RequestVisibilityNormalizer.fromMap({
      'id': 'resignation-1',
      'userId': 'employee-1',
      'requestType': 'resignation',
      'status': 'approved',
      'createdAt': '2026-08-24T09:30:00.000Z',
    });
    final deletion = RequestVisibilityNormalizer.fromMap({
      'id': 'deletion-1',
      'userId': 'employee-1',
      'requestType': 'employee_deletion',
      'status': 'pending',
      'createdAt': '2026-08-24T09:30:00.000Z',
    });

    expect(complaint?.sourceType, RequestSourceType.complaint);
    expect(resignation?.sourceType, RequestSourceType.resignation);
    expect(deletion?.sourceType, RequestSourceType.employeeDeletion);
  });
}

final class _Source implements RequestVisibilityDataSource {
  const _Source(this.records);
  final List<Map<String, dynamic>> records;
  @override
  Future<List<Map<String, dynamic>>> loadBounded(
    RequestViewQuery query,
  ) async => records;
}

final class _ThrowingSource implements RequestVisibilityDataSource {
  @override
  Future<List<Map<String, dynamic>>> loadBounded(RequestViewQuery query) {
    throw Exception('cloud_firestore/permission-denied /internal/path');
  }
}
