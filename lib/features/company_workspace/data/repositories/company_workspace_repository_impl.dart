import '../../../../core/sync/workspace_operation_outbox.dart';
import '../../domain/entities/workspace_access_grant.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_operation.dart';
import '../../domain/repositories/company_workspace_repository.dart';
import '../datasources/company_workspace_remote_data_source.dart';
import '../models/workspace_operation_dto.dart';

/// Coordinates a write with the durable outbox. A pending write is persisted
/// before it is sent; retries reuse the exact same operation ID.
final class CompanyWorkspaceRepositoryImpl
    implements CompanyWorkspaceRepository {
  CompanyWorkspaceRepositoryImpl({
    required CompanyWorkspaceRemoteDataSource remote,
    required WorkspaceOperationOutbox outbox,
    required Future<List<WorkspaceAccessGrant>> Function(String resourceId)
    grantsLoader,
    required Future<bool> Function({
      required String resourceId,
      required WorkspaceCapability capability,
    })
    accessChecker,
  }) : _remote = remote,
       _outbox = outbox,
       _grantsLoader = grantsLoader,
       _accessChecker = accessChecker;

  final CompanyWorkspaceRemoteDataSource _remote;
  final WorkspaceOperationOutbox _outbox;
  final Future<List<WorkspaceAccessGrant>> Function(String resourceId)
  _grantsLoader;
  final Future<bool> Function({
    required String resourceId,
    required WorkspaceCapability capability,
  })
  _accessChecker;

  @override
  Future<bool> canAccess({
    required String resourceId,
    required WorkspaceCapability capability,
  }) => _accessChecker(resourceId: resourceId, capability: capability);

  @override
  Future<List<WorkspaceAccessGrant>> grantsFor(String resourceId) =>
      _grantsLoader(resourceId);

  @override
  Future<WorkspaceOperation> submit(WorkspaceOperation operation) async {
    await _outbox.put(operation);
    try {
      final receipt = await _remote.submitOperation(
        WorkspaceOperationDto.fromDomain(operation),
      );
      final result = switch (receipt.state) {
        WorkspaceOperationState.pending => operation,
        WorkspaceOperationState.acknowledged => operation.acknowledge(
          safeMessage: receipt.safeMessage,
        ),
        WorkspaceOperationState.rejected => operation.reject(
          receipt.safeMessage ?? 'تعذر حفظ العملية. تحقق من الحالة.',
        ),
        WorkspaceOperationState.conflict => operation.conflict(
          receipt.safeMessage ?? 'تم تعديل الملف. راجع الحالة قبل الحفظ.',
        ),
      };
      if (result.state != WorkspaceOperationState.pending) {
        await _outbox.remove(operation.id, operation.actorId);
      }
      return result;
    } on WorkspaceRemoteFailure {
      // Unknown outcomes remain durable and are reconciled by a later replay.
      return operation;
    }
  }

  Future<List<WorkspaceOperation>> replayPending(
    String actorId, {
    int limit = 25,
  }) async {
    final pending = await _outbox.pendingForActor(actorId);
    final resolved = <WorkspaceOperation>[];
    final boundedLimit = limit.clamp(1, 100);
    for (final operation in pending.take(boundedLimit)) {
      resolved.add(await submit(operation));
    }
    return resolved;
  }
}
