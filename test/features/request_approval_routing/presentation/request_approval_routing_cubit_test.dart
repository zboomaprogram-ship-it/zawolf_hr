import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_approval_routing/request_approval_routing.dart';

class FakeRequestApprovalRoutingRepository implements RequestApprovalRoutingRepository {
  bool shouldFail = false;
  Map<String, dynamic> lastCreated = {};
  Map<String, dynamic> lastDecision = {};

  @override
  Future<Map<String, dynamic>> createFieldMission({
    required List<String> employeeUids,
    required List<Map<String, String>> approvers,
    required String missionDate,
    required String startTime,
    required String endTime,
    required String reason,
    String siteName = '',
    String locationId = '',
    bool requiresReturnToOffice = false,
    bool requiresCheckout = false,
  }) async {
    if (shouldFail) throw StateError('فشل الاتصال بالبوابة');
    lastCreated = {
      'employeeUids': employeeUids,
      'approvers': approvers,
      'missionDate': missionDate,
    };
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> recordStageDecision({
    required String requestId,
    required String requestType,
    required String stageId,
    required ApprovalStageState decision,
    String? comment,
  }) async {
    if (shouldFail) throw StateError('فشل تسجيل القرار');
    lastDecision = {
      'requestId': requestId,
      'decision': decision,
      'comment': comment,
    };
    return {'ok': true};
  }
}

void main() {
  group('RequestApprovalRoutingCubit Tests', () {
    late FakeRequestApprovalRoutingRepository repository;
    late RequestApprovalRoutingCubit cubit;

    setUp(() {
      repository = FakeRequestApprovalRoutingRepository();
      cubit = RequestApprovalRoutingCubit(repository: repository);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state has idle status and empty approvers', () {
      expect(cubit.state.status, ApprovalRoutingStatus.idle);
      expect(cubit.state.selectedApprovers, isEmpty);
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('updateApprovers updates the selected approvers list', () {
      final approvers = [
        {'id': 'mgr-1', 'name': 'Ahmed', 'role': 'manager'}
      ];
      cubit.updateApprovers(approvers);
      expect(cubit.state.selectedApprovers, approvers);
    });

    test('submitFieldMission fails validation when no approvers are selected', () async {
      final success = await cubit.submitFieldMission(
        employeeUids: ['emp-1'],
        missionDate: '2026-09-17',
        startTime: '09:00',
        endTime: '14:00',
        reason: 'Client site audit',
      );

      expect(success, isFalse);
      expect(cubit.state.status, ApprovalRoutingStatus.failure);
      expect(cubit.state.errorMessage, contains('معتمد واحد'));
    });

    test('submitFieldMission submits cleanly through repository', () async {
      cubit.updateApprovers([
        {'id': 'mgr-1', 'name': 'Ahmed', 'role': 'manager'}
      ]);

      final success = await cubit.submitFieldMission(
        employeeUids: ['emp-1'],
        missionDate: '2026-09-17',
        startTime: '09:00',
        endTime: '14:00',
        reason: 'Client site audit',
      );

      expect(success, isTrue);
      expect(cubit.state.status, ApprovalRoutingStatus.success);
      expect(cubit.state.successMessage, contains('تم إنشاء مسار المأمورية'));
      expect(repository.lastCreated['missionDate'], '2026-09-17');
    });

    test('recordDecision records approval and emits success', () async {
      final success = await cubit.recordDecision(
        requestId: 'req-123',
        requestType: 'field_mission',
        stageId: 'stage-1',
        decision: ApprovalStageState.approved,
        comment: 'معتمد بعد المراجعة',
      );

      expect(success, isTrue);
      expect(cubit.state.status, ApprovalRoutingStatus.success);
      expect(cubit.state.successMessage, contains('تم اعتماد المرحلة'));
      expect(repository.lastDecision['requestId'], 'req-123');
    });

    test('handles repository errors safely with presentation message', () async {
      repository.shouldFail = true;

      final success = await cubit.recordDecision(
        requestId: 'req-123',
        requestType: 'field_mission',
        stageId: 'stage-1',
        decision: ApprovalStageState.rejected,
      );

      expect(success, isFalse);
      expect(cubit.state.status, ApprovalRoutingStatus.failure);
      expect(cubit.state.errorMessage, 'فشل تسجيل القرار');
    });
  });
}
