import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_operation.dart';
import '../../domain/repositories/company_workspace_repository.dart';

sealed class WorkspaceOperationsState {
  const WorkspaceOperationsState();
}

final class WorkspaceOperationsIdle extends WorkspaceOperationsState {
  const WorkspaceOperationsIdle();
}

final class WorkspaceOperationsSubmitting extends WorkspaceOperationsState {
  const WorkspaceOperationsSubmitting();
}

final class WorkspaceOperationsSaved extends WorkspaceOperationsState {
  const WorkspaceOperationsSaved(this.message);
  final String message;
}

final class WorkspaceOperationsPending extends WorkspaceOperationsState {
  const WorkspaceOperationsPending();
}

final class WorkspaceOperationsRejected extends WorkspaceOperationsState {
  const WorkspaceOperationsRejected(this.message);
  final String message;
}

/// Owns only user-visible mutation status. Durable persistence and retries are
/// delegated to the repository/outbox.
final class WorkspaceOperationsCubit extends Cubit<WorkspaceOperationsState> {
  WorkspaceOperationsCubit({
    required CompanyWorkspaceRepository repository,
    required String actorId,
  }) : _repository = repository,
       _actorId = actorId,
       super(const WorkspaceOperationsIdle());

  final CompanyWorkspaceRepository _repository;
  final String _actorId;
  final Random _random = Random.secure();

  Future<void> submit({
    required String resourceId,
    required WorkspaceOperationKind kind,
    Map<String, Object?> payload = const <String, Object?>{},
    String? expectedVersion,
  }) async {
    emit(const WorkspaceOperationsSubmitting());
    final operation = WorkspaceOperation(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(36)}',
      actorId: _actorId,
      resourceId: resourceId,
      kind: kind,
      payload: payload,
      expectedVersion: expectedVersion,
      createdAt: DateTime.now().toUtc(),
    );
    final result = await _repository.submit(operation);
    switch (result.state) {
      case WorkspaceOperationState.acknowledged:
        emit(WorkspaceOperationsSaved(result.safeMessage ?? 'تم حفظ التغيير.'));
      case WorkspaceOperationState.pending:
        emit(const WorkspaceOperationsPending());
      case WorkspaceOperationState.rejected:
      case WorkspaceOperationState.conflict:
        emit(
          WorkspaceOperationsRejected(
            result.safeMessage ?? 'تعذر حفظ التغيير. راجع الحالة.',
          ),
        );
    }
  }
}
