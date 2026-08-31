import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/deduction_explanation.dart';
import '../../domain/repositories/employee_operations_repository.dart';

enum DeductionDetailsStatus { initial, loading, ready, empty, failure }

final class DeductionDetailsState {
  const DeductionDetailsState({
    this.status = DeductionDetailsStatus.initial,
    this.items = const [],
  });

  final DeductionDetailsStatus status;
  final List<DeductionExplanation> items;
}

final class DeductionDetailsCubit extends Cubit<DeductionDetailsState> {
  DeductionDetailsCubit(this._repository)
    : super(const DeductionDetailsState());

  final EmployeeOperationsRepository _repository;
  StreamSubscription<List<DeductionExplanation>>? _subscription;

  void watch({
    required String employeeUserId,
    required String effectiveCycleKey,
  }) {
    _subscription?.cancel();
    emit(const DeductionDetailsState(status: DeductionDetailsStatus.loading));
    _subscription = _repository
        .watchDeductionExplanations(
          employeeUserId: employeeUserId,
          effectiveCycleKey: effectiveCycleKey,
        )
        .listen(
          (items) => emit(
            DeductionDetailsState(
              status: items.isEmpty
                  ? DeductionDetailsStatus.empty
                  : DeductionDetailsStatus.ready,
              items: items,
            ),
          ),
          onError: (_, __) => emit(
            const DeductionDetailsState(status: DeductionDetailsStatus.failure),
          ),
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
