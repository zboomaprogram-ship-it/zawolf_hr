import 'package:flutter/material.dart';

import '../../domain/entities/unified_operational_request.dart';

class ApprovalJourney extends StatelessWidget {
  const ApprovalJourney({super.key, required this.plan});
  final ApprovalPlan plan;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Semantics(
      label: 'مسار الموافقات',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: plan.stages
            .map((stage) {
              final approved = stage.status == 'approved';
              final rejected = stage.status == 'rejected';
              return Chip(
                avatar: Icon(
                  rejected
                      ? Icons.cancel_outlined
                      : approved
                      ? Icons.check_circle_outline
                      : Icons.schedule,
                  color: rejected
                      ? Colors.red
                      : approved
                      ? Colors.green
                      : Colors.amber,
                ),
                label: Text('${_label(stage.type)} · ${_status(stage.status)}'),
              );
            })
            .toList(growable: false),
      ),
    ),
  );

  String _label(ApprovalStageType type) => switch (type) {
    ApprovalStageType.manager => 'المدير المباشر',
    ApprovalStageType.specialist => 'المختص',
    ApprovalStageType.finance => 'المالية',
    ApprovalStageType.owner => 'مالك الشركة',
    ApprovalStageType.payment => 'تنفيذ الصرف',
    ApprovalStageType.closure => 'الإغلاق',
  };

  String _status(String value) => switch (value) {
    'approved' => 'موافق',
    'rejected' => 'مرفوض',
    _ => 'قيد الانتظار',
  };
}
