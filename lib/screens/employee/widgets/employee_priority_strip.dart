import 'package:flutter/material.dart';

import '../../../design_system/components/priority_strip.dart';
import '../../../models/task_model.dart';
import '../../../services/task_service.dart';
import '../../../theme/theme.dart';
import 'package:go_router/go_router.dart';

/// Dashboard priority strip for the employee home anatomy
/// (specs/ui_redesign/06_priority_redesigns_spec.md R1).
///
/// Counts reuse existing providers only: pending-request totals arrive from
/// [EmployeeRequestHistorySection] via [pendingRequestsCount] (no extra
/// queries) and due-today tasks come from `TaskService.watchMyTasks`, the
/// same stream the tasks screen already listens to.
class EmployeePriorityStrip extends StatelessWidget {
  const EmployeePriorityStrip({
    required this.userId,
    required this.pendingRequestsCount,
    super.key,
  });

  final String userId;
  final int pendingRequestsCount;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmployeeTaskModel>>(
      stream: TaskService().watchMyTasks(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final dueToday = snapshot.data!.where((task) {
          final isFutureKpiTask = task.dueDate.isAfter(endOfToday) &&
              (task.source == 'sales_analytics_api' ||
                  task.progressMode == 'cumulative_daily');
          return !isFutureKpiTask &&
              task.status != TaskStatus.done &&
              task.status != TaskStatus.cancelled &&
              !task.dueDate.isAfter(endOfToday);
        }).length;

        return PriorityStrip(
          items: [
            PriorityItem(
              label: 'طلب بانتظار الموافقة',
              count: pendingRequestsCount,
              icon: Icons.pending_actions_outlined,
              accent: ZaWolfColors.warning,
              onTap: () => context.go('/employee/requests'),
            ),
            PriorityItem(
              label: 'مهمة مستحقة اليوم',
              count: dueToday,
              icon: Icons.task_alt_outlined,
              accent: ZaWolfColors.primaryCyan,
              onTap: () => context.go('/employee/tasks'),
            ),
          ],
        );
      },
    );
  }
}
