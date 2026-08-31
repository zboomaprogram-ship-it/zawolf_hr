import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/operational_visibility_setting.dart';
import '../../domain/repositories/operational_visibility_repository.dart';

final class OperationalVisibilityState {
  const OperationalVisibilityState({
    this.hiddenEmployeeIds = const {},
    this.savingEmployeeId,
    this.safeErrorCode,
  });

  final Set<String> hiddenEmployeeIds;
  final String? savingEmployeeId;
  final String? safeErrorCode;
}

final class OperationalVisibilityCubit
    extends Cubit<OperationalVisibilityState> {
  OperationalVisibilityCubit(this._repository)
    : super(const OperationalVisibilityState()) {
    _subscription = _repository.watchHiddenEmployeeIds().listen(
      (ids) => emit(OperationalVisibilityState(hiddenEmployeeIds: ids)),
      onError: (_) => emit(
        OperationalVisibilityState(
          hiddenEmployeeIds: state.hiddenEmployeeIds,
          safeErrorCode: 'temporarily_unavailable',
        ),
      ),
    );
  }

  final OperationalVisibilityRepository _repository;
  StreamSubscription<Set<String>>? _subscription;

  Future<OperationalVisibilitySetting?> setHidden({
    required String employeeUserId,
    required bool hidden,
    required String reasonAr,
  }) async {
    emit(
      OperationalVisibilityState(
        hiddenEmployeeIds: state.hiddenEmployeeIds,
        savingEmployeeId: employeeUserId,
      ),
    );
    try {
      return await _repository.setHidden(
        employeeUserId: employeeUserId,
        hidden: hidden,
        reasonAr: reasonAr,
        operationId:
            'visibility:$employeeUserId:${DateTime.now().microsecondsSinceEpoch}',
      );
    } catch (_) {
      emit(
        OperationalVisibilityState(
          hiddenEmployeeIds: state.hiddenEmployeeIds,
          safeErrorCode: 'temporarily_unavailable',
        ),
      );
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
