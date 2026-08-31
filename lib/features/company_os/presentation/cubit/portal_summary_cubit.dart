import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee_portal_summary.dart';
import '../../domain/repositories/employee_portal_repository.dart';

sealed class PortalSummaryState {
  const PortalSummaryState();
}

final class PortalSummaryLoading extends PortalSummaryState {
  const PortalSummaryLoading();
}

final class PortalSummaryReady extends PortalSummaryState {
  const PortalSummaryReady(this.summary);
  final EmployeePortalSummary summary;
}

final class PortalSummaryEmpty extends PortalSummaryState {
  const PortalSummaryEmpty();
}

final class PortalSummaryFailure extends PortalSummaryState {
  const PortalSummaryFailure(this.message);
  final String message;
}

final class PortalSummaryCubit extends Cubit<PortalSummaryState> {
  PortalSummaryCubit(this._repository) : super(const PortalSummaryLoading());
  final EmployeePortalRepository _repository;

  Future<void> load() async {
    emit(const PortalSummaryLoading());
    try {
      final summary = await _repository.summary();
      if (summary.openTicketCount == 0 &&
          summary.assignedAssetCount == 0 &&
          summary.pendingRequestCount == 0) {
        emit(const PortalSummaryEmpty());
      } else {
        emit(PortalSummaryReady(summary));
      }
    } catch (_) {
      emit(const PortalSummaryFailure('تعذر تحميل ملخص العمل. أعد المحاولة.'));
    }
  }
}
