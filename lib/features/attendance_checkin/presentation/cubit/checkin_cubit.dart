import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/operation_result.dart';
import '../../../../core/errors/user_safe_failure_message.dart';
import '../../domain/entities/check_in_action.dart';
import '../../domain/entities/check_in_presentation_state.dart';
import '../../domain/repositories/attendance_check_in_repository.dart';

class CheckInCubit extends Cubit<CheckInPresentationState> {
  CheckInCubit(this._repository) : super(const CheckInPresentationState());

  final AttendanceCheckInRepository _repository;

  Future<void> submit(CheckInAction action) async {
    if (state.status == CheckInViewStatus.submitting ||
        state.status == CheckInViewStatus.requiresStatusCheck) {
      return;
    }
    emit(const CheckInPresentationState(status: CheckInViewStatus.submitting));
    final result = await _repository.submit(action);
    if (result case OperationSuccess(value: final receipt)) {
      emit(
        CheckInPresentationState(
          status: CheckInViewStatus.saved,
          receipt: receipt,
        ),
      );
      return;
    }
    final failure = result.failureOrNull!;
    final pending = await _repository.pendingFor(action.employeeScopeId);
    emit(
      CheckInPresentationState(
        status: failure.requiresStatusCheck
            ? CheckInViewStatus.requiresStatusCheck
            : pending != null
            ? CheckInViewStatus.pendingSync
            : CheckInViewStatus.failed,
        pending: pending,
        failure: failure,
      ),
    );
  }

  Future<void> synchronizePending(String employeeScopeId) async {
    final result = await _repository.synchronizePending(employeeScopeId);
    if (result == null) return;
    if (result case OperationSuccess(value: final receipt)) {
      emit(
        CheckInPresentationState(
          status: CheckInViewStatus.saved,
          receipt: receipt,
        ),
      );
      return;
    }
    final failure = result.failureOrNull!;
    final pending = await _repository.pendingFor(employeeScopeId);
    emit(
      CheckInPresentationState(
        status: failure.requiresStatusCheck
            ? CheckInViewStatus.requiresStatusCheck
            : pending != null
            ? CheckInViewStatus.pendingSync
            : CheckInViewStatus.failed,
        pending: pending,
        failure: failure,
      ),
    );
  }

  UserSafeFailureMessage? safeFailureMessage() {
    final failure = state.failure;
    return failure == null ? null : UserSafeFailureMessage.fromFailure(failure);
  }
}
