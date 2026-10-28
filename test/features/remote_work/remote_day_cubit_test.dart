import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/remote_work/domain/entities/remote_work_models.dart';
import 'package:zawolf_hr/features/remote_work/domain/repositories/remote_work_repository.dart';
import 'package:zawolf_hr/features/remote_work/presentation/cubit/remote_day_cubit.dart';

class FakeRemoteWorkRepository implements RemoteWorkRepository {
  RemoteEligibility? eligibilityResponse;
  RemoteReceipt? attendanceReceiptResponse;
  RemoteWorkDomainException? domainError;

  @override
  Future<RemoteEligibility> evaluateEligibility({
    required String employeeId,
    required DateTime date,
  }) async {
    if (domainError != null) throw domainError!;
    return eligibilityResponse ??
        const RemoteEligibility(
          eligible: true,
          reason: 'approved_authorization',
          date: '2026-11-02',
          weekStart: '2026-10-31',
        );
  }

  @override
  Future<RemoteReceipt> submitAttendanceCommand(RemoteCommand command) async {
    if (domainError != null) throw domainError!;
    return attendanceReceiptResponse ??
        RemoteReceipt(
          operationId: command.operationId,
          status: 'recorded',
          attendanceId: 'u1_2026-11-02',
          sessionId: 'sess_1',
          mode: 'remote_web',
          version: 1,
          serverTime: DateTime(2026, 11, 2, 9, 0),
        );
  }

  @override
  Future<RemoteReceipt> submitSessionCommand(RemoteCommand command) async {
    if (domainError != null) throw domainError!;
    return RemoteReceipt(
      operationId: command.operationId,
      status: 'recorded',
      sessionId: command.sessionId,
      version: 2,
      serverTime: DateTime(2026, 11, 2, 9, 30),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listRemoteDays({
    String? userId,
    int limit = 50,
    String? cursor,
  }) async =>
      [];

  @override
  Future<RemoteReceipt> submitScheduleCommand(RemoteCommand command) async =>
      RemoteReceipt(
        operationId: command.operationId,
        status: 'recorded',
        version: 1,
        serverTime: DateTime.now(),
      );

  @override
  Future<RemoteReceipt> submitIncidentCommand(RemoteCommand command) async =>
      RemoteReceipt(
        operationId: command.operationId,
        status: 'recorded',
        version: 1,
        serverTime: DateTime.now(),
      );
}

void main() {
  group('RemoteDayCubit', () {
    late FakeRemoteWorkRepository repository;
    late RemoteDayCubit cubit;

    setUp(() {
      repository = FakeRemoteWorkRepository();
      cubit = RemoteDayCubit(repository: repository);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has initial status', () {
      expect(cubit.state.status, RemoteDayStatus.initial);
    });

    test('loadDay emits eligible when employee is qualified for date', () async {
      await cubit.loadDay(
        employeeId: 'u1',
        date: DateTime(2026, 11, 2),
      );

      expect(cubit.state.status, RemoteDayStatus.eligible);
      expect(cubit.state.eligibility?.eligible, isTrue);
    });

    test('loadDay emits ineligible with Arabic message when not eligible', () async {
      repository.eligibilityResponse = const RemoteEligibility(
        eligible: false,
        reason: 'weekly_allowance_conflict',
        date: '2026-11-02',
        weekStart: '2026-10-31',
      );

      await cubit.loadDay(
        employeeId: 'u1',
        date: DateTime(2026, 11, 2),
      );

      expect(cubit.state.status, RemoteDayStatus.ineligible);
      expect(cubit.state.errorMessage, contains('استنفاد'));
    });

    test('performCheckIn emits checkedIn and captures attendance and session IDs', () async {
      const proof = RemoteProof(
        challengeId: 'ch_1',
        credentialId: 'cred_1',
        assertion: {'signature': 'sig'},
      );

      await cubit.performCheckIn(
        employeeId: 'u1',
        date: DateTime(2026, 11, 2),
        proof: proof,
      );

      expect(cubit.state.status, RemoteDayStatus.checkedIn);
      expect(cubit.state.attendanceId, 'u1_2026-11-02');
      expect(cubit.state.sessionId, 'sess_1');
    });

    test('performCheckIn emits modeLocked when day mode is locked to office', () async {
      repository.domainError = const RemoteWorkDomainException(
        'mode_locked',
        'لا يمكن التبديل بين الدوام المكتبي والعمل عن بعد في نفس اليوم.',
      );

      const proof = RemoteProof(
        challengeId: 'ch_1',
        credentialId: 'cred_1',
        assertion: {'signature': 'sig'},
      );

      await cubit.performCheckIn(
        employeeId: 'u1',
        date: DateTime(2026, 11, 2),
        proof: proof,
      );

      expect(cubit.state.status, RemoteDayStatus.modeLocked);
      expect(cubit.state.errorMessage, contains('التبديل'));
    });

    test('performCheckOut emits checkedOut and updates summary', () async {
      const proof = RemoteProof(
        challengeId: 'ch_2',
        credentialId: 'cred_1',
        assertion: {'signature': 'sig_out'},
      );

      await cubit.performCheckOut(
        employeeId: 'u1',
        date: DateTime(2026, 11, 2),
        proof: proof,
        summary: 'Completed remote sprint tasks.',
      );

      expect(cubit.state.status, RemoteDayStatus.checkedOut);
      expect(cubit.state.summary, 'Completed remote sprint tasks.');
    });
  });
}
