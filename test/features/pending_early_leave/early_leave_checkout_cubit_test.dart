import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/pending_early_leave/domain/early_leave_checkout_eligibility.dart';
import 'package:zawolf_hr/features/pending_early_leave/domain/early_leave_checkout_repository.dart';
import 'package:zawolf_hr/features/pending_early_leave/presentation/early_leave_checkout_cubit.dart';
import 'package:zawolf_hr/features/pending_early_leave/presentation/early_leave_checkout_state.dart';
import 'package:zawolf_hr/models/user_model.dart';

class _FakeEarlyLeaveCheckoutRepository
    implements EarlyLeaveCheckoutRepository {
  final _controller = StreamController<EarlyLeaveCheckoutEligibility?>.broadcast();
  EarlyLeaveCheckoutEligibility? currentEligibility;

  void emitEligibility(EarlyLeaveCheckoutEligibility? eligibility) {
    currentEligibility = eligibility;
    _controller.add(eligibility);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<EarlyLeaveCheckoutEligibility?> watchForToday(
    UserModel employee, {
    DateTime? now,
  }) => _controller.stream;

  @override
  Future<EarlyLeaveCheckoutEligibility?> loadForToday(
    UserModel employee, {
    DateTime? now,
  }) async => currentEligibility;

  void dispose() {
    _controller.close();
  }
}

void main() {
  late _FakeEarlyLeaveCheckoutRepository repository;
  late EarlyLeaveCheckoutCubit cubit;

  final testUser = UserModel(
    uid: 'test-uid',
    email: 'emp@zawolf.ai',
    displayName: 'موظف الاختبار',
    role: 'employee',
    employeeId: 'E-01',
    department: 'Engineering',
    position: 'Developer',
    locationId: 'loc-1',
    locationName: 'HQ',
    workSchedule: WorkSchedule(
      startTime: '09:00',
      endTime: '17:00',
      workDays: const [1, 2, 3, 4, 5, 6],
    ),
    leaveBalance: LeaveBalance(annual: 15, sick: 14, casual: 7, daysOff: 15),
    permissionBalance: PermissionBalance(
      usedThisMonth: 0,
      usedHoursThisMonth: 0.0,
      lastResetMonth: '2026-09',
    ),
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = _FakeEarlyLeaveCheckoutRepository();
    cubit = EarlyLeaveCheckoutCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    repository.dispose();
  });

  test('initial state is idle with no eligibility', () {
    expect(cubit.state.status, EarlyLeaveCheckoutViewStatus.initial);
    expect(cubit.state.eligibility, isNull);
  });

  test('watch emits loading then ready when eligibility is available', () async {
    final normalEnd = DateTime(2026, 9, 16, 17);
    final eligibility = EarlyLeaveCheckoutEligibility(
      permissionId: 'perm-1',
      requestState: EarlyLeaveRequestState.pendingManager,
      requestedCheckoutAt: normalEnd.subtract(const Duration(hours: 2)),
      normalCheckoutAt: normalEnd,
      requestedMinutes: 120,
    );

    final expectedStates = <EarlyLeaveCheckoutViewStatus>[
      EarlyLeaveCheckoutViewStatus.loading,
      EarlyLeaveCheckoutViewStatus.ready,
    ];

    final actualStates = <EarlyLeaveCheckoutViewStatus>[];
    final sub = cubit.stream.listen((state) {
      actualStates.add(state.status);
    });

    await cubit.watch(testUser);
    repository.emitEligibility(eligibility);
    await pumpEventQueue();

    expect(actualStates, expectedStates);
    expect(cubit.state.eligibility?.permissionId, 'perm-1');

    await sub.cancel();
  });

  test('watch emits unavailable when eligibility stream yields null', () async {
    final actualStates = <EarlyLeaveCheckoutViewStatus>[];
    final sub = cubit.stream.listen((state) {
      actualStates.add(state.status);
    });

    await cubit.watch(testUser);
    repository.emitEligibility(null);
    await pumpEventQueue();

    expect(actualStates, [
      EarlyLeaveCheckoutViewStatus.loading,
      EarlyLeaveCheckoutViewStatus.unavailable,
    ]);
    expect(cubit.state.eligibility, isNull);

    await sub.cancel();
  });

  test('watch emits error state when repository stream errors', () async {
    await cubit.watch(testUser);
    repository.emitError(Exception('network failure'));
    await pumpEventQueue();

    expect(cubit.state.status, EarlyLeaveCheckoutViewStatus.error);
    expect(cubit.state.message, isNotNull);
  });
}
