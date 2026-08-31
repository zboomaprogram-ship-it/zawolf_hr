import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sales_indicator_filter.dart';
import '../../domain/entities/sales_indicator_snapshot.dart';
import '../../domain/repositories/sales_indicators_repository.dart';

final class SalesIndicatorsState {
  const SalesIndicatorsState({
    this.loading = false,
    this.snapshot,
    this.safeMessage,
    this.accessDenied = false,
  });
  final bool loading;
  final SalesIndicatorSnapshot? snapshot;
  final String? safeMessage;
  final bool accessDenied;
}

final class SalesIndicatorsCubit extends Cubit<SalesIndicatorsState> {
  SalesIndicatorsCubit(this._repository) : super(const SalesIndicatorsState());
  final SalesIndicatorsRepository _repository;
  SalesIndicatorFilter? _filter;

  Future<void> load(SalesIndicatorFilter filter) async {
    _filter = filter;
    emit(SalesIndicatorsState(loading: true, snapshot: state.snapshot));
    _emit(await _repository.load(filter));
  }

  Future<void> retry() async {
    final filter = _filter;
    if (filter != null) await load(filter);
  }

  Future<void> reconcile({
    required String providerRole,
    required String providerKey,
    required String employeeUserId,
  }) async {
    final filter = _filter;
    if (filter == null) return;
    emit(SalesIndicatorsState(loading: true, snapshot: state.snapshot));
    _emit(await _repository.reconcile(
      filter: filter,
      providerRole: providerRole,
      providerKey: providerKey,
      employeeUserId: employeeUserId,
    ));
  }

  void _emit(SalesIndicatorsResult result) {
    switch (result) {
      case SalesIndicatorsLoaded(:final snapshot):
        emit(SalesIndicatorsState(snapshot: snapshot));
      case SalesIndicatorsAccessDenied():
        emit(const SalesIndicatorsState(
          safeMessage: 'لا تملك صلاحية عرض مؤشرات المبيعات.',
          accessDenied: true,
        ));
      case SalesIndicatorsRetryableFailure(:final safeMessage):
        emit(SalesIndicatorsState(snapshot: state.snapshot, safeMessage: safeMessage));
    }
  }
}
