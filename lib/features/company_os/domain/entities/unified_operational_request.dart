import 'company_os_attachment_reference.dart';

enum OperationalRequestStatus { pending, approved, rejected, paid, closed }

enum ApprovalStageType { manager, specialist, finance, owner, payment, closure }

final class ApprovalStage {
  const ApprovalStage({
    required this.type,
    required this.required,
    this.assigneeUid,
    this.status = 'pending',
  });
  final ApprovalStageType type;
  final bool required;
  final String? assigneeUid;
  final String status;
}

final class ApprovalPlan {
  const ApprovalPlan({
    required this.requestId,
    required this.policyVersion,
    required this.stages,
    required this.createdAt,
  });
  final String requestId;
  final int policyVersion;
  final List<ApprovalStage> stages;
  final DateTime createdAt;

  bool get requiresFinance => stages.any(
    (stage) => stage.required && stage.type == ApprovalStageType.finance,
  );
  bool get requiresOwner => stages.any(
    (stage) => stage.required && stage.type == ApprovalStageType.owner,
  );
}

final class UnifiedOperationalRequest {
  const UnifiedOperationalRequest({
    required this.id,
    required this.requesterUid,
    required this.requestType,
    required this.costBearing,
    required this.businessReason,
    required this.executionDate,
    required this.status,
    required this.approvalPolicyVersion,
    required this.version,
    this.approvalPlan,
    this.amount,
    this.currency,
    this.attachments = const [],
  });
  final String id;
  final String requesterUid;
  final String requestType;
  final bool costBearing;
  final num? amount;
  final String? currency;
  final List<CompanyOsAttachmentReference> attachments;
  final String businessReason;
  final DateTime executionDate;
  final OperationalRequestStatus status;
  final int approvalPolicyVersion;
  final int version;
  final ApprovalPlan? approvalPlan;
}

final class ManagedOwnerPolicy {
  const ManagedOwnerPolicy({
    required this.version,
    required this.ownerUid,
    required this.activeFrom,
    this.replacedAt,
  });
  final int version;
  final String ownerUid;
  final DateTime activeFrom;
  final DateTime? replacedAt;
}
