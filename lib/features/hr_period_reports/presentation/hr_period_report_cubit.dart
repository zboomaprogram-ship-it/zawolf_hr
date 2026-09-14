import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/user_model.dart';
import '../domain/hr_period_report.dart';
import '../domain/hr_period_report_repository.dart';

class HrPeriodReportState {
  const HrPeriodReportState({required this.period, this.report, this.employeeId, this.error, this.exportedResourceId, this.loading = false, this.refreshing = false, this.exporting = false});
  final HrReportPeriod period;
  final HrPeriodReport? report;
  final String? employeeId;
  final Object? error;
  final String? exportedResourceId;
  final bool loading;
  final bool refreshing;
  final bool exporting;
  HrPeriodReportState copyWith({HrReportPeriod? period, HrPeriodReport? report, String? employeeId, bool clearEmployee = false, Object? error, bool clearError = false, String? exportedResourceId, bool clearExport = false, bool? loading, bool? refreshing, bool? exporting}) => HrPeriodReportState(
    period: period ?? this.period, report: report ?? this.report,
    employeeId: clearEmployee ? null : (employeeId ?? this.employeeId),
    error: clearError ? null : (error ?? this.error),
    exportedResourceId: clearExport ? null : (exportedResourceId ?? this.exportedResourceId),
    loading: loading ?? this.loading, refreshing: refreshing ?? this.refreshing, exporting: exporting ?? this.exporting,
  );
}

final class HrPeriodReportCubit extends Cubit<HrPeriodReportState> {
  HrPeriodReportCubit({required HrPeriodReportRepository repository, required UserModel reviewer})
      : _repository = repository, _reviewer = reviewer, super(HrPeriodReportState(period: HrReportPeriod.sevenDays())) { refresh(); }
  final HrPeriodReportRepository _repository;
  final UserModel _reviewer;

  Future<void> selectPeriod(HrReportPeriod period) async { emit(state.copyWith(period: period, clearError: true)); await refresh(); }
  void selectEmployee(String? id) => emit(state.copyWith(employeeId: id, clearEmployee: id == null));
  Future<void> export() async {
    emit(state.copyWith(exporting: true, clearError: true, clearExport: true));
    try {
      final resourceId = await _repository.export(period: state.period, employeeId: state.employeeId);
      emit(state.copyWith(exportedResourceId: resourceId, exporting: false));
    } catch (error) { emit(state.copyWith(error: error, exporting: false)); }
  }
  Future<void> refresh() async {
    final cached = state.report != null;
    emit(state.copyWith(loading: !cached, refreshing: cached, clearError: true));
    try {
      final report = await _repository.load(reviewer: _reviewer, period: state.period);
      final valid = state.employeeId == null || report.employees.any((employee) => employee.id == state.employeeId);
      emit(state.copyWith(report: report, clearEmployee: !valid, loading: false, refreshing: false, clearError: true));
    } catch (error) { emit(state.copyWith(error: error, loading: false, refreshing: false)); }
  }
}
