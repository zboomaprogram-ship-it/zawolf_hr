import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/attendance_correction_draft.dart';
import '../domain/entities/deduction_explanation.dart';
import '../domain/repositories/employee_operations_repository.dart';
import 'firestore_employee_operations_data_source.dart';

final class EmployeeOperationsRepositoryImpl
    implements EmployeeOperationsRepository {
  EmployeeOperationsRepositoryImpl({
    required FirestoreEmployeeOperationsDataSource source,
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
  }) : _source = source,
       _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri;

  final FirestoreEmployeeOperationsDataSource _source;
  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;

  @override
  Stream<List<DeductionExplanation>> watchDeductionExplanations({
    required String employeeUserId,
    required String effectiveCycleKey,
  }) => _source
      .watchCycle(
        employeeUserId: employeeUserId,
        effectiveCycleKey: effectiveCycleKey,
      )
      .map((snapshot) => _merge(snapshot, effectiveCycleKey));

  @override
  Future<CorrectionSubmissionResult> submitAttendanceCorrection({
    required String employeeUserId,
    required AttendanceCorrectionDraft draft,
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/attendance-corrections'),
      operationId: draft.operationId,
      body: {
        'attendanceId': draft.attendanceId,
        'requestedCheckIn': draft.requestedCheckIn.toUtc().toIso8601String(),
        'reason': draft.reason,
      },
    );
    return switch (response.safeCode) {
      'submitted' => CorrectionSubmissionResult.submitted,
      'already_pending' ||
      'already_submitted' => CorrectionSubmissionResult.alreadyPending,
      _ => CorrectionSubmissionResult.requiresStatusCheck,
    };
  }

  List<DeductionExplanation> _merge(
    EmployeeDeductionSourceSnapshot snapshot,
    String cycle,
  ) {
    final entries = <DeductionExplanation>[
      ...snapshot.attendance
          .where((item) => item.salaryDeductionFraction > 0)
          .map(
            (item) => DeductionExplanation(
              sourceKey: 'attendance:${item.attendanceId}',
              effectiveDate: _date(item.date),
              effectiveCycleKey: cycle,
              sourceLabelAr: 'الحضور والانصراف',
              reasonAr: item.salaryDeductionLabel,
              fraction: item.salaryDeductionFraction,
              status: _status(item.salaryDeductionApprovalStatus),
              amount: item.salaryDeductionAmount,
              currency: item.salaryCurrency,
              reviewedAt: item.salaryDeductionReviewedAt,
              originalCheckIn: item.checkInTime,
            ),
          ),
      ...snapshot.permissions
          .where(
            (item) => item.isDeductible && item.salaryDeductionFraction > 0,
          )
          .map(
            (item) => DeductionExplanation(
              sourceKey: 'permission:${item.permissionId}',
              effectiveDate: _date(item.requestDate),
              effectiveCycleKey: item.monthKey,
              sourceLabelAr: 'إذن استقطاعي',
              reasonAr: item.salaryDeductionLabel,
              fraction: item.salaryDeductionFraction,
              status: _status(item.salaryDeductionApprovalStatus),
              amount: item.salaryDeductionAmount,
              currency: item.salaryCurrency,
            ),
          ),
      ...snapshot.manualDeductions.map(
        (item) => DeductionExplanation(
          sourceKey: 'manual:${item.id}',
          effectiveDate: _date(item.dateKey),
          effectiveCycleKey: item.monthKey,
          sourceLabelAr: 'خصم إداري',
          reasonAr: item.reason,
          fraction: item.dayFraction,
          status: _status(item.status),
        ),
      ),
    ]..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return entries;
  }

  static DateTime _date(String value) =>
      DateTime.tryParse(value) ?? DateTime(1970);

  static DeductionReviewStatus _status(String value) => switch (value) {
    'approved' => DeductionReviewStatus.approved,
    'rejected' => DeductionReviewStatus.rejected,
    'cancelled' || 'removed' => DeductionReviewStatus.cancelled,
    _ => DeductionReviewStatus.pending,
  };
}
