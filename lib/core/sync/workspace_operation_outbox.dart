import '../../features/company_workspace/domain/entities/workspace_operation.dart';

abstract interface class WorkspaceOperationOutbox {
  Future<void> put(WorkspaceOperation operation);

  Future<List<WorkspaceOperation>> pendingForActor(String actorId);

  Future<void> remove(String operationId, String actorId);
}

/// A small, app-lifecycle safe replay policy. It deliberately has no Firebase
/// or UI dependency: the feature repository supplies the idempotent sender.
/// Replays are bounded so an unreliable connection cannot create a request
/// storm or starve normal user actions.
final class WorkspaceOutboxReplayPolicy {
  const WorkspaceOutboxReplayPolicy({
    this.maxOperationsPerRun = 25,
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 2),
  });

  final int maxOperationsPerRun;
  final Duration baseDelay;
  final Duration maxDelay;

  Duration delayForAttempt(int attempt) {
    final factor = 1 << attempt.clamp(0, 5);
    final delay = Duration(milliseconds: baseDelay.inMilliseconds * factor);
    return delay > maxDelay ? maxDelay : delay;
  }
}
