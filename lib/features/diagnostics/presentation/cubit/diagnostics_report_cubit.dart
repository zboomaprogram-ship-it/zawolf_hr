import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/diagnostic_report.dart';
import '../../domain/repositories/diagnostics_repository.dart';

final class DiagnosticsReportState {
  const DiagnosticsReportState({
    this.loading = false,
    this.reports = const [],
    this.safeErrorCode,
  });
  final bool loading;
  final List<DiagnosticReport> reports;
  final String? safeErrorCode;
}

final class DiagnosticsReportCubit extends Cubit<DiagnosticsReportState> {
  DiagnosticsReportCubit(this._repository)
    : super(const DiagnosticsReportState());

  final DiagnosticsRepository _repository;

  Future<void> load([
    DiagnosticReportQuery query = const DiagnosticReportQuery(),
  ]) async {
    emit(DiagnosticsReportState(loading: true, reports: state.reports));
    try {
      final reports = await _repository.loadReports(query);
      emit(DiagnosticsReportState(reports: reports));
    } catch (_) {
      emit(
        DiagnosticsReportState(
          reports: state.reports,
          safeErrorCode: 'temporarily_unavailable',
        ),
      );
    }
  }
}
