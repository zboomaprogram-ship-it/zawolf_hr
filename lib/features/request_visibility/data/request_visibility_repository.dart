import '../../../core/errors/safe_presentation_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/request_view_query.dart';
import '../domain/entities/request_visibility_record.dart';
import '../domain/repositories/request_visibility_repository.dart';
import '../../diagnostics/domain/entities/diagnostic_event.dart';
import '../../diagnostics/domain/repositories/diagnostics_repository.dart';

abstract interface class RequestVisibilityDataSource {
  Future<List<Map<String, dynamic>>> loadBounded(RequestViewQuery query);
}

/// Compatibility adapter for current and legacy request/deduction documents.
/// Firestore selection remains behind [RequestVisibilityDataSource], allowing
/// the UI to use a fixed bounded contract rather than creating listeners.
final class RequestVisibilityRepositoryImpl
    implements RequestVisibilityRepository {
  RequestVisibilityRepositoryImpl(
    this._source, {
    DiagnosticsRepository? diagnostics,
  }) : _diagnostics = diagnostics;

  final RequestVisibilityDataSource _source;
  final DiagnosticsRepository? _diagnostics;

  @override
  Future<RequestViewResult> load(RequestViewQuery query) async {
    try {
      final records =
          (await _source.loadBounded(query))
              .map(RequestVisibilityNormalizer.fromMap)
              .whereType<RequestVisibilityRecord>()
              .where(query.matches)
              .where((record) => _matchesSearch(record, query.searchTerm))
              .toList(growable: true)
            ..sort((a, b) {
              final byDate = b.occurredAt.compareTo(a.occurredAt);
              return byDate != 0 ? byDate : b.stableId.compareTo(a.stableId);
            });
      final cursorIndex = query.pageCursor == null
          ? 0
          : records.indexWhere(
                  (record) => _cursor(record) == query.pageCursor,
                ) +
                1;
      final start = cursorIndex <= 0 ? 0 : cursorIndex;
      final page = records
          .skip(start)
          .take(query.pageSize)
          .toList(growable: false);
      if (page.isEmpty) return const RequestViewEmpty();
      final hasMore = start + page.length < records.length;
      return RequestViewLoaded(
        page,
        nextCursor: hasMore ? _cursor(page.last) : null,
      );
    } on RequestVisibilityAccessDenied catch (error) {
      await _report('access_denied');
      return RequestViewAccessDenied(error.safeMessage);
    } catch (error) {
      await _report('temporarily_unavailable');
      return RequestViewRetryableFailure(
        safeArabicBusinessMessage(error) ??
            'تعذر تحميل الطلبات مؤقتاً. أعد المحاولة بعد لحظات.',
      );
    }
  }

  Future<void> _report(String safeCode) async {
    await _diagnostics?.report(
      DiagnosticEvent.create(
        feature: 'request_visibility',
        safeCode: safeCode,
        release: const String.fromEnvironment(
          'APP_RELEASE',
          defaultValue: 'unknown',
        ),
        occurredAt: DateTime.now(),
        metadata: const {'operation': 'load', 'surface': 'requests'},
      ),
    );
  }

  bool _matchesSearch(RequestVisibilityRecord record, String value) {
    final needle = value.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return <String?>[
      record.employeeName,
      record.employeeCode,
      record.reason,
      record.stableId,
    ].whereType<String>().any((value) => value.toLowerCase().contains(needle));
  }

  String _cursor(RequestVisibilityRecord record) =>
      '${record.occurredAt.toIso8601String()}|${record.stableId}';
}

final class RequestVisibilityAccessDenied implements Exception {
  const RequestVisibilityAccessDenied([
    this.safeMessage = 'لا تتوفر لك صلاحية عرض هذه الطلبات.',
  ]);
  final String safeMessage;
}

abstract final class RequestVisibilityNormalizer {
  static RequestVisibilityRecord? fromMap(Map<String, dynamic> value) {
    final stableId = _text(value['id']) ?? _text(value['requestId']);
    final employeeId =
        _text(value['employeeId']) ??
        _text(value['userId']) ??
        _text(value['employeeUid']) ??
        _text(value['userUid']) ??
        _text(value['requesterId']) ??
        _text(value['requestedById']);
    final occurredAt =
        _date(value['attendanceDate']) ??
        _date(value['requestDate']) ??
        _date(value['date']) ??
        _date(value['dateKey']) ??
        _date(value['businessEffectiveAt']) ??
        _date(value['effectiveAt']) ??
        _date(value['startDate']) ??
        _date(value['submittedAt']) ??
        _date(value['createdAt']) ??
        _date(value['timestamp']) ??
        _date(value['updatedAt']);
    if (stableId == null || employeeId == null || occurredAt == null) {
      return null;
    }
    return RequestVisibilityRecord(
      stableId: stableId,
      sourceType: _sourceType(value),
      employeeId: employeeId,
      approvalStage: _stage(value),
      lifecycleState: _state(value),
      occurredAt: occurredAt,
      sourceReference: _text(value['sourceReference']) ?? stableId,
      employeeName: _text(value['employeeName']),
      employeeCode: _text(value['employeeCode']),
      reason: _text(value['reason']) ?? _text(value['adminReason']),
    );
  }

  static RequestSourceType _sourceType(Map<String, dynamic> value) {
    final type =
        (_text(value['requestType']) ??
                _text(value['type']) ??
                _text(value['sourceCollection']) ??
                '')
            .toLowerCase();
    if (type.contains('late') && type.contains('deduction')) {
      return RequestSourceType.lateArrivalDeduction;
    }
    if (type.contains('deduction') || type.contains('salary')) {
      return RequestSourceType.salaryDeduction;
    }
    if (type.contains('permission')) {
      return RequestSourceType.permission;
    }
    if (type.contains('leave')) {
      return RequestSourceType.leave;
    }
    if (type.contains('correction')) {
      return RequestSourceType.attendanceCorrection;
    }
    if (type.contains('advance')) {
      return RequestSourceType.advance;
    }
    if (type.contains('administrative')) {
      return RequestSourceType.administrative;
    }
    if (type.contains('complaint')) {
      return RequestSourceType.complaint;
    }
    if (type.contains('resignation')) {
      return RequestSourceType.resignation;
    }
    if (type.contains('employee_deletion') || type.contains('deletion')) {
      return RequestSourceType.employeeDeletion;
    }
    return RequestSourceType.unknown;
  }

  static RequestLifecycleState _state(Map<String, dynamic> value) {
    if (value['isConfirmed'] == true) {
      return RequestLifecycleState.confirmed;
    }
    final state =
        (_text(value['status']) ??
                _text(value['salaryDeductionApprovalStatus']) ??
                '')
            .toLowerCase();
    if (state.contains('confirm')) {
      return RequestLifecycleState.confirmed;
    }
    if (state.contains('approv') || state.contains('accept')) {
      return RequestLifecycleState.approved;
    }
    if (state.contains('reject')) {
      return RequestLifecycleState.rejected;
    }
    if (state.contains('cancel')) {
      return RequestLifecycleState.cancelled;
    }
    if (state.contains('pending') || state.contains('review')) {
      return RequestLifecycleState.pending;
    }
    return RequestLifecycleState.unknown;
  }

  static RequestApprovalStage _stage(Map<String, dynamic> value) {
    final state =
        (_text(value['status']) ??
                _text(value['salaryDeductionApprovalStatus']) ??
                '')
            .toLowerCase();
    if (state.contains('manager')) {
      return RequestApprovalStage.manager;
    }
    if (state.contains('ceo')) {
      return RequestApprovalStage.ceo;
    }
    if (state.contains('hr')) {
      return RequestApprovalStage.hr;
    }
    if (_state(value) != RequestLifecycleState.pending) {
      return RequestApprovalStage.finalised;
    }
    return RequestApprovalStage.unknown;
  }

  static String? _text(Object? value) {
    final result = value is String ? value.trim() : '';
    return result.isEmpty ? null : result;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }
}
