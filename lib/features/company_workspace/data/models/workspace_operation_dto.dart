import '../../domain/entities/workspace_operation.dart';

/// Wire representation. It deliberately contains no Google IDs, access token,
/// or provider exception text.
final class WorkspaceOperationDto {
  const WorkspaceOperationDto({
    required this.operationId,
    required this.resourceId,
    required this.kind,
    required this.createdAt,
    this.expectedVersion,
    this.payload = const <String, Object?>{},
  });

  final String operationId;
  final String resourceId;
  final String kind;
  final DateTime createdAt;
  final String? expectedVersion;
  final Map<String, Object?> payload;

  factory WorkspaceOperationDto.fromDomain(WorkspaceOperation operation) =>
      WorkspaceOperationDto(
        operationId: operation.id,
        resourceId: operation.resourceId,
        kind: operation.kind.name,
        createdAt: operation.createdAt.toUtc(),
        expectedVersion: operation.expectedVersion,
        payload: operation.payload,
      );

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'resourceId': resourceId,
    'kind': kind,
    'createdAt': createdAt.toIso8601String(),
    if (expectedVersion != null) 'expectedVersion': expectedVersion,
    if (payload.isNotEmpty) 'payload': payload,
  };
}

final class WorkspaceOperationReceiptDto {
  const WorkspaceOperationReceiptDto({required this.state, this.safeMessage});

  final WorkspaceOperationState state;
  final String? safeMessage;

  factory WorkspaceOperationReceiptDto.fromJson(Map<String, Object?> json) {
    final state = json['state'];
    if (state is! String) {
      throw const FormatException('Missing operation state');
    }
    return WorkspaceOperationReceiptDto(
      state: WorkspaceOperationState.values.byName(state),
      safeMessage: json['safeMessage'] as String?,
    );
  }
}
