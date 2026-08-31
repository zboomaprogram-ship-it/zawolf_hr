import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_report.dart';
import '../../domain/repositories/workspace_audit_repository.dart';

sealed class WorkspaceAuditState {
  const WorkspaceAuditState();
}

final class WorkspaceAuditIdle extends WorkspaceAuditState {
  const WorkspaceAuditIdle();
}

final class WorkspaceAuditLoading extends WorkspaceAuditState {
  const WorkspaceAuditLoading();
}

final class WorkspaceAuditReady extends WorkspaceAuditState {
  const WorkspaceAuditReady(this.events);
  final List<WorkspaceAuditEvent> events;
}

final class WorkspaceAuditFailure extends WorkspaceAuditState {
  const WorkspaceAuditFailure(this.message);
  final String message;
}

final class WorkspaceAuditCubit extends Cubit<WorkspaceAuditState> {
  WorkspaceAuditCubit(this._repository) : super(const WorkspaceAuditIdle());
  final WorkspaceAuditRepository _repository;

  Future<void> load({
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    emit(const WorkspaceAuditLoading());
    try {
      emit(
        WorkspaceAuditReady(
          await _repository.listEvents(startsOn: startsOn, endsOn: endsOn),
        ),
      );
    } on Object {
      emit(
        const WorkspaceAuditFailure(
          'تعذر تحميل سجل النشاط حالياً. أعد المحاولة لاحقاً.',
        ),
      );
    }
  }
}
