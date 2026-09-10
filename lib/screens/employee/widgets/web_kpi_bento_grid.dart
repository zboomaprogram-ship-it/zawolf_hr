import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/wolf_card.dart';
import '../../../design_system/tokens.dart';
import '../../../models/attendance_model.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/task_service.dart';
import '../../../theme/theme.dart';

/// Enterprise Bento Grid KPI section for the Employee Web Dashboard.
/// Displays 4 high-impact operational metrics:
/// 1. Discipline & Attendance Score
/// 2. Leave & Permission Balances
/// 3. Task Execution Rate & States
/// 4. Pending Approvals
class WebKpiBentoGrid extends StatelessWidget {
  final UserModel user;
  final double disciplineScore;
  final int workedDays;
  final AttendanceModel? todayLog;
  final int pendingRequestsCount;
  final Stream<List<EmployeeTaskModel>>? taskStream;

  const WebKpiBentoGrid({
    super.key,
    required this.user,
    required this.disciplineScore,
    required this.workedDays,
    required this.todayLog,
    required this.pendingRequestsCount,
    this.taskStream,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final isMedium = constraints.maxWidth >= 680;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildAttendanceKpiCard(context)),
              const SizedBox(width: DsSpacing.md),
              Expanded(child: _buildTasksExecutionCard(context)),
              const SizedBox(width: DsSpacing.md),
              Expanded(child: _buildLeavesCard(context)),
              const SizedBox(width: DsSpacing.md),
              Expanded(child: _buildPendingRequestsCard(context)),
            ],
          );
        }

        final columns = isMedium ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: DsSpacing.md,
          mainAxisSpacing: DsSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMedium ? 1.85 : 2.2,
          children: [
            _buildAttendanceKpiCard(context),
            _buildTasksExecutionCard(context),
            _buildLeavesCard(context),
            _buildPendingRequestsCard(context),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceKpiCard(BuildContext context) {
    final hasCheckedIn = todayLog?.checkInTime != null;
    final hasCheckedOut = todayLog?.checkOutTime != null;
    String todayStatusLabel;
    Color todayStatusColor;

    if (hasCheckedOut) {
      todayStatusLabel = 'تم الانصراف';
      todayStatusColor = ZaWolfColors.primaryCyan;
    } else if (hasCheckedIn) {
      todayStatusLabel = 'حاضر اليوم';
      todayStatusColor = ZaWolfColors.success;
    } else {
      todayStatusLabel = 'لم يسجل بعد';
      todayStatusColor = ZaWolfColors.textMuted;
    }

    final scoreFormatted = disciplineScore.clamp(0, 100).toStringAsFixed(0);

    return WolfCard(
      borderColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
      shadowColor: ZaWolfColors.primaryCyan,
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: ZaWolfColors.primaryCyan,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: todayStatusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: todayStatusColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: todayStatusColor),
                    const SizedBox(width: 5),
                    Text(
                      todayStatusLabel,
                      style: TextStyle(
                        color: todayStatusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$scoreFormatted%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'نسبة الانضباط',
                    style: TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (disciplineScore / 100).clamp(0.0, 1.0),
              backgroundColor: ZaWolfColors.surface03,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ZaWolfColors.primaryCyan,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            'حضور $workedDays يوم خلال الدورة الحالية',
            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksExecutionCard(BuildContext context) {
    return StreamBuilder<List<EmployeeTaskModel>>(
      stream: taskStream ?? TaskService().watchMyTasks(user.uid),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final total = tasks.length;
        final done = tasks.where((t) => t.status == TaskStatus.done).length;
        final inProgress =
            tasks.where((t) => t.status == TaskStatus.inProgress).length;
        final late = tasks.where((t) => t.status == TaskStatus.late).length;

        final rate = total > 0 ? ((done / total) * 100).round() : 100;

        return WolfCard(
          borderColor: ZaWolfColors.warning.withValues(alpha: 0.3),
          shadowColor: ZaWolfColors.warning,
          padding: const EdgeInsets.all(DsSpacing.lg),
          onTap: () => context.go('/employee/tasks'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: ZaWolfColors.warning,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: ZaWolfColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$rate%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'إنجاز المهام',
                        style: TextStyle(
                          color: ZaWolfColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? (done / total).clamp(0.0, 1.0) : 1.0,
                  backgroundColor: ZaWolfColors.surface03,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZaWolfColors.warning,
                  ),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: DsSpacing.sm),
              Text(
                'مكتملة: $done • قيد التنفيذ: $inProgress${late > 0 ? " • متأخرة: $late" : ""}',
                style: TextStyle(
                  color: late > 0 ? ZaWolfColors.error : ZaWolfColors.textMuted,
                  fontSize: 11,
                  fontWeight: late > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeavesCard(BuildContext context) {
    final annualBalance = user.leaveBalance.annual;
    final usedPermissionHours = user.permissionBalance.usedHoursThisMonth;

    return WolfCard(
      borderColor: Colors.tealAccent.withValues(alpha: 0.25),
      shadowColor: Colors.tealAccent,
      padding: const EdgeInsets.all(DsSpacing.lg),
      onTap: () => context.go('/employee/requests'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: Colors.tealAccent,
                  size: 20,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: ZaWolfColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$annualBalance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: DsSpacing.xs),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'أيام متبقية',
                    style: TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          const Text(
            'رصيد الإجازات السنوية',
            style: TextStyle(
              color: Colors.tealAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            'أذونات مستخدمة هذا الشهر: $usedPermissionHours ساعة',
            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsCard(BuildContext context) {
    final hasPending = pendingRequestsCount > 0;
    final accentColor =
        hasPending ? ZaWolfColors.warning : ZaWolfColors.primaryCyan;

    return WolfCard(
      borderColor: accentColor.withValues(alpha: 0.3),
      shadowColor: accentColor,
      padding: const EdgeInsets.all(DsSpacing.lg),
      onTap: () => context.go('/employee/requests'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: ZaWolfColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pendingRequestsCount',
                style: TextStyle(
                  color: hasPending ? accentColor : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'طلبات معلقة',
                    style: TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            hasPending
                ? 'بانتظار موافقة الإدارة أو HR'
                : 'جميع الطلبات تمت معالجتها',
            style: TextStyle(
              color: hasPending ? accentColor : ZaWolfColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          const Text(
            'اضغط لعرض ومتابعة الطلبات ←',
            style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
