/// Immutable, idempotent check-in evidence captured before a service call.
///
/// The action ID uses the existing canonical attendance-document identity and
/// is never regenerated during retry or later synchronization.
class CheckInAction {
  const CheckInAction({
    required this.actionId,
    required this.employeeScopeId,
    required this.dateKey,
    required this.capturedAt,
    required this.payload,
  });

  final String actionId;
  final String employeeScopeId;
  final String dateKey;
  final DateTime capturedAt;

  /// Transport-ready evidence. Infrastructure owns its serialization.
  final Map<String, Object?> payload;

  CheckInAction copyWith({Map<String, Object?>? payload}) => CheckInAction(
    actionId: actionId,
    employeeScopeId: employeeScopeId,
    dateKey: dateKey,
    capturedAt: capturedAt,
    payload: payload ?? this.payload,
  );
}
