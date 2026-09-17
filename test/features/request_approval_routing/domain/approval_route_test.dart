import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_approval_routing/request_approval_routing.dart';

void main() {
  group('ApprovalRoute Domain Entities', () {
    test('ApprovalStage maps states and serializes correctly', () {
      const stage = ApprovalStage(
        stageId: 'stage-1',
        order: 1,
        approverId: 'approver-123',
        approverName: 'Manager Name',
        approverRole: 'manager',
        labelAr: 'مدير القسم',
      );

      expect(stage.state, ApprovalStageState.pending);
      expect(stage.state.serialized, 'pending');

      final approved = stage.copyWith(state: ApprovalStageState.approved);
      expect(approved.state, ApprovalStageState.approved);
      expect(approved.state.serialized, 'approved');
      expect(approved.approverName, 'Manager Name');
    });

    test('ApprovalRoute manages stage progression and completion', () {
      const stage1 = ApprovalStage(
        stageId: 'stage-1',
        order: 1,
        approverId: 'approver-1',
        approverName: 'HR',
        approverRole: 'hr',
        labelAr: 'الموارد البشرية',
        state: ApprovalStageState.approved,
      );
      const stage2 = ApprovalStage(
        stageId: 'stage-2',
        order: 2,
        approverId: 'approver-2',
        approverName: 'CEO',
        approverRole: 'ceo',
        labelAr: 'المدير التنفيذي',
        state: ApprovalStageState.pending,
      );

      final route = ApprovalRoute(
        requestId: 'req-999',
        requestType: 'advance',
        stages: const [stage1, stage2],
        currentApprovalIndex: 1,
      );

      expect(route.currentStage?.stageId, 'stage-2');
      expect(route.isCompleted, isFalse);
      expect(route.isRejected, isFalse);

      final completedRoute = ApprovalRoute(
        requestId: 'req-999',
        requestType: 'advance',
        stages: const [stage1, stage2],
        currentApprovalIndex: 2,
      );
      expect(completedRoute.currentStage, isNull);
      expect(completedRoute.isCompleted, isTrue);
    });
  });
}
