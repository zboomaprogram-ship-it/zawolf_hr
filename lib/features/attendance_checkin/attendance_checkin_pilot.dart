import 'data/attendance_checkin_repository_impl.dart';
import 'data/local/checkin_outbox_database.dart';
import 'data/remote/attendance_gateway_checkin_client.dart';
import 'presentation/cubit/checkin_cubit.dart';

/// Composition root for the default-off check-in reliability pilot.
///
/// The employee screen imports this public feature boundary only. Concrete
/// gateway and Drift dependencies stay outside the presentation layer.
final class AttendanceCheckInPilot {
  AttendanceCheckInPilot._(this._database, this.cubit);

  factory AttendanceCheckInPilot.create() {
    final database = CheckInOutboxDatabase();
    final repository = AttendanceCheckInRepositoryImpl(
      remote: AttendanceGatewayCheckInClient(),
      outbox: DriftCheckInOutbox(database),
    );
    return AttendanceCheckInPilot._(database, CheckInCubit(repository));
  }

  final CheckInOutboxDatabase _database;
  final CheckInCubit cubit;

  Future<void> close() async {
    await cubit.close();
    await _database.close();
  }
}
