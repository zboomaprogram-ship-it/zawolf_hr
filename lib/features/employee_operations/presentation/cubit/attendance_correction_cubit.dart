import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/attendance_correction_draft.dart';
import '../../domain/repositories/employee_operations_repository.dart';

enum AttendanceCorrectionStatus {
  initial,
  submitting,
  submitted,
  pending,
  checkStatus,
}

final class AttendanceCorrectionState {
  const AttendanceCorrectionState({
    this.status = AttendanceCorrectionStatus.initial,
  });

  final AttendanceCorrectionStatus status;
}

final class AttendanceCorrectionCubit extends Cubit<AttendanceCorrectionState> {
  AttendanceCorrectionCubit(this._repository)
    : super(const AttendanceCorrectionState());

  final EmployeeOperationsRepository _repository;

  Future<void> submit({
    required String employeeUserId,
    required AttendanceCorrectionDraft draft,
  }) async {
    if (state.status == AttendanceCorrectionStatus.submitting) return;
    emit(
      const AttendanceCorrectionState(
        status: AttendanceCorrectionStatus.submitting,
      ),
    );
    try {
      final result = await _repository.submitAttendanceCorrection(
        employeeUserId: employeeUserId,
        draft: draft,
      );
      emit(
        AttendanceCorrectionState(
          status: switch (result) {
            CorrectionSubmissionResult.submitted =>
              AttendanceCorrectionStatus.submitted,
            CorrectionSubmissionResult.alreadyPending =>
              AttendanceCorrectionStatus.pending,
            CorrectionSubmissionResult.requiresStatusCheck =>
              AttendanceCorrectionStatus.checkStatus,
          },
        ),
      );
    } catch (_) {
      emit(
        const AttendanceCorrectionState(
          status: AttendanceCorrectionStatus.checkStatus,
        ),
      );
    }
  }
}
