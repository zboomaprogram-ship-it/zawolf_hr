import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/unified_operational_request.dart';

void main() {
  test('cost approval plan explicitly requires Finance and owner', () {
    final plan = ApprovalPlan(
      requestId: 'r1',
      policyVersion: 2,
      createdAt: DateTime(2026),
      stages: const [
        ApprovalStage(type: ApprovalStageType.manager, required: true),
        ApprovalStage(type: ApprovalStageType.finance, required: true),
        ApprovalStage(
          type: ApprovalStageType.owner,
          required: true,
          assigneeUid: 'owner-1',
        ),
      ],
    );
    expect(plan.requiresFinance, isTrue);
    expect(plan.requiresOwner, isTrue);
  });

  test('request execution date remains independent from approval date', () {
    final request = UnifiedOperationalRequest(
      id: 'r1',
      requesterUid: 'u1',
      requestType: 'payment',
      costBearing: true,
      businessReason: 'سبب',
      executionDate: DateTime(2026, 7, 22),
      status: OperationalRequestStatus.approved,
      approvalPolicyVersion: 1,
      version: 3,
    );
    expect(request.executionDate, DateTime(2026, 7, 22));
  });

  test('specialist stays before Finance and policy version is retained', () {
    final plan = ApprovalPlan(
      requestId: 'r2',
      policyVersion: 7,
      createdAt: DateTime(2026),
      stages: const [
        ApprovalStage(type: ApprovalStageType.manager, required: true),
        ApprovalStage(type: ApprovalStageType.specialist, required: true),
        ApprovalStage(type: ApprovalStageType.finance, required: true),
        ApprovalStage(type: ApprovalStageType.owner, required: true),
      ],
    );
    expect(plan.policyVersion, 7);
    expect(
      plan.stages.indexWhere(
        (stage) => stage.type == ApprovalStageType.specialist,
      ),
      lessThan(
        plan.stages.indexWhere(
          (stage) => stage.type == ApprovalStageType.finance,
        ),
      ),
    );
  });
}
