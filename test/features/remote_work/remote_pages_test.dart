import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/remote_work/domain/entities/remote_work_models.dart';
import 'package:zawolf_hr/features/remote_work/domain/repositories/remote_work_repository.dart';
import 'package:zawolf_hr/features/remote_work/presentation/pages/remote_attendance_page.dart';

class MockRemoteWorkRepository implements RemoteWorkRepository {
  MockRemoteWorkRepository({this.eligibility});

  RemoteEligibility? eligibility;

  @override
  Future<RemoteEligibility> evaluateEligibility({
    required String employeeId,
    required DateTime date,
  }) async {
    return eligibility ??
        const RemoteEligibility(
          eligible: true,
          reason: 'approved_authorization',
          date: '2026-11-02',
          weekStart: '2026-10-31',
        );
  }

  @override
  Future<RemoteReceipt> submitAttendanceCommand(RemoteCommand command) async {
    return RemoteReceipt(
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
  group('RemoteAttendancePage Widget Tests', () {
    testWidgets('renders eligible state with passkey check-in button', (tester) async {
      final repository = MockRemoteWorkRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: RemoteAttendancePage(
            repository: repository,
            employeeId: 'u1',
            targetDate: DateTime(2026, 11, 2),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدوام عن بُعد'), findsOneWidget);
      expect(find.text('أنت مؤهل لتسجيل الحضور عن بُعد اليوم'), findsOneWidget);
      expect(find.text('تسجيل الحضور بمفتاح المرور'), findsOneWidget);
    });

    testWidgets('renders ineligible state with Arabic explanation card', (tester) async {
      final repository = MockRemoteWorkRepository(
        eligibility: const RemoteEligibility(
          eligible: false,
          reason: 'weekly_allowance_conflict',
          date: '2026-11-02',
          weekStart: '2026-10-31',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RemoteAttendancePage(
            repository: repository,
            employeeId: 'u1',
            targetDate: DateTime(2026, 11, 2),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('غير متاح للعمل عن بُعد اليوم'), findsOneWidget);
      expect(find.textContaining('استنفاد'), findsOneWidget);
    });

    testWidgets('checking in switches to active session card with checkout and goals', (tester) async {
      final repository = MockRemoteWorkRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: RemoteAttendancePage(
            repository: repository,
            employeeId: 'u1',
            targetDate: DateTime(2026, 11, 2),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap check-in
      await tester.tap(find.text('تسجيل الحضور بمفتاح المرور'));
      await tester.pumpAndSettle();

      expect(find.text('جلسة العمل عن بُعد نشطة'), findsOneWidget);
      expect(find.text('تسجيل الانصراف عن بُعد'), findsOneWidget);
      expect(find.text('خطة أهداف اليوم (العمل عن بُعد)'), findsOneWidget);
    });
  });
}
