import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_report_period.dart';
import '../../domain/repositories/workspace_reports_repository.dart';

sealed class WorkspaceReportsState {
  const WorkspaceReportsState();
}

final class WorkspaceReportsIdle extends WorkspaceReportsState {
  const WorkspaceReportsIdle();
}

final class WorkspaceReportsGenerating extends WorkspaceReportsState {
  const WorkspaceReportsGenerating();
}

final class WorkspaceReportsReady extends WorkspaceReportsState {
  const WorkspaceReportsReady(this.resourceId, this.message);
  final String resourceId;
  final String message;
}

final class WorkspaceReportsFailure extends WorkspaceReportsState {
  const WorkspaceReportsFailure(this.message);
  final String message;
}

final class WorkspaceReportsCubit extends Cubit<WorkspaceReportsState> {
  WorkspaceReportsCubit(this._repository) : super(const WorkspaceReportsIdle());
  final WorkspaceReportsRepository _repository;

  Future<void> generateHr({
    required WorkspaceReportPeriod period,
    required String reportType,
  }) async {
    emit(const WorkspaceReportsGenerating());
    try {
      final resourceId = await _repository.requestHrOperationalReport(
        period: period,
        reportType: reportType,
      );
      emit(
        WorkspaceReportsReady(
          resourceId,
          'تم إنشاء التقرير وحفظه في ملفات الشركة.',
        ),
      );
    } on Object {
      emit(
        const WorkspaceReportsFailure(
          'تعذر إنشاء التقرير الآن. أعد المحاولة لاحقاً.',
        ),
      );
    }
  }

  Future<void> generateActivity({
    required WorkspaceReportPeriod period,
  }) async {
    emit(const WorkspaceReportsGenerating());
    try {
      final resourceId = await _repository.requestWorkspaceActivityReport(
        period: period,
        scopeId: 'company',
      );
      emit(
        WorkspaceReportsReady(
          resourceId,
          'تم إنشاء تقرير نشاط مساحة الملفات وحفظه في التقارير.',
        ),
      );
    } on Object {
      emit(
        const WorkspaceReportsFailure(
          'تعذر إنشاء تقرير النشاط الآن. أعد المحاولة لاحقاً.',
        ),
      );
    }
  }
}
