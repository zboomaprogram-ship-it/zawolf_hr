import '../entities/attendance_correction_draft.dart';
import '../entities/deduction_explanation.dart';

abstract interface class EmployeeOperationsRepository {
  Stream<List<DeductionExplanation>> watchDeductionExplanations({
    required String employeeUserId,
    required String effectiveCycleKey,
  });

  Future<CorrectionSubmissionResult> submitAttendanceCorrection({
    required String employeeUserId,
    required AttendanceCorrectionDraft draft,
  });
}

enum CorrectionSubmissionResult { submitted, alreadyPending, requiresStatusCheck }
