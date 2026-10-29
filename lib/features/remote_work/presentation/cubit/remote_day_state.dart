import '../../domain/entities/remote_work_models.dart';

enum RemoteDayStatus {
  initial,
  loading,
  eligible,
  checkedIn,
  checkedOut,
  ineligible,
  modeLocked,
  error,
}

final class RemoteDayState {
  const RemoteDayState({
    this.status = RemoteDayStatus.initial,
    this.eligibility,
    this.receipt,
    this.errorMessage,
    this.goals = const [],
    this.summary,
    this.attendanceId,
    this.sessionId,
    this.checkpointUpdates = const {},
  });

  final RemoteDayStatus status;
  final RemoteEligibility? eligibility;
  final RemoteReceipt? receipt;
  final String? errorMessage;
  final List<String> goals;
  final String? summary;
  final String? attendanceId;
  final String? sessionId;
  final Map<String, String> checkpointUpdates;

  RemoteDayState copyWith({
    RemoteDayStatus? status,
    RemoteEligibility? eligibility,
    RemoteReceipt? receipt,
    String? errorMessage,
    List<String>? goals,
    String? summary,
    String? attendanceId,
    String? sessionId,
    Map<String, String>? checkpointUpdates,
  }) {
    return RemoteDayState(
      status: status ?? this.status,
      eligibility: eligibility ?? this.eligibility,
      receipt: receipt ?? this.receipt,
      errorMessage: errorMessage ?? this.errorMessage,
      goals: goals ?? this.goals,
      summary: summary ?? this.summary,
      attendanceId: attendanceId ?? this.attendanceId,
      sessionId: sessionId ?? this.sessionId,
      checkpointUpdates: checkpointUpdates ?? this.checkpointUpdates,
    );
  }
}
