import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../services/department_report_service.dart';
import '../../theme/theme.dart';
import 'performance_report_export_dialog.dart';

typedef BehaviorScoreUpdater =
    Future<void> Function(
      ProductivityScoreModel score,
      double value,
      String reason,
    );

Future<void> showProductivityScoreDetails(
  BuildContext context,
  ProductivityScoreModel score, {
  UserModel? reviewer,
  BehaviorScoreUpdater? onUpdateBehavior,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    useSafeArea: true,
    builder: (context) => _ScoreDetailsSheet(
      score: score,
      reviewer: reviewer,
      onUpdateBehavior: onUpdateBehavior,
    ),
  );
}

Future<void> showDepartmentProductivityDetails(
  BuildContext context, {
  required String department,
  required List<ProductivityScoreModel> scores,
  UserModel? reviewer,
  String? monthKey,
  BehaviorScoreUpdater? onUpdateBehavior,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    useSafeArea: true,
    builder: (context) => _DepartmentProductivitySheet(
      department: department,
      scores: scores,
      reviewer: reviewer,
      monthKey: monthKey,
      onUpdateBehavior: onUpdateBehavior,
    ),
  );
}

class _DepartmentProductivitySheet extends StatefulWidget {
  const _DepartmentProductivitySheet({
    required this.department,
    required this.scores,
    this.reviewer,
    this.monthKey,
    this.onUpdateBehavior,
  });

  final String department;
  final List<ProductivityScoreModel> scores;
  final UserModel? reviewer;
  final String? monthKey;
  final BehaviorScoreUpdater? onUpdateBehavior;

  @override
  State<_DepartmentProductivitySheet> createState() =>
      _DepartmentProductivitySheetState();
}

class _DepartmentProductivitySheetState
    extends State<_DepartmentProductivitySheet> {
  Map<String, DepartmentAnalyticsDetail>? _detailsMap;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final res = await DepartmentReportService.instance.loadDepartmentDetails(
        scores: widget.scores,
        reviewer: widget.reviewer,
        monthKey: widget.monthKey,
      );
      if (mounted) {
        setState(() {
          _detailsMap = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openExportDialog({String? specificEmployeeId}) {
    if (widget.reviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات المراجع غير متوفرة للتصدير.')),
      );
      return;
    }
    showPerformanceExportDialog(
      context,
      scores: widget.scores,
      reviewer: widget.reviewer!,
      initialDepartment: widget.department,
      initialEmployeeId: specificEmployeeId,
      monthKey: widget.monthKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.scores]
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));

    final totalEmployees = widget.scores.length;
    final totalAbsent =
        widget.scores.fold<int>(0, (sum, s) => sum + s.absentDays);
    final totalLate =
        widget.scores.fold<int>(0, (sum, s) => sum + s.lateDays);
    final avgScore = widget.scores.isEmpty
        ? 0.0
        : widget.scores.fold<double>(0, (sum, s) => sum + s.overallScore) /
            widget.scores.length;
    final totalCompletedTasks =
        widget.scores.fold<int>(0, (sum, s) => sum + s.completedTasks);
    final totalOverdueTasks =
        widget.scores.fold<int>(0, (sum, s) => sum + s.overdueTasks);

    double totalDeductionsDays = 0;
    int totalDeductionsCount = 0;
    int totalRequests = 0;
    int totalLeaves = 0;
    int totalPermissions = 0;

    if (_detailsMap != null) {
      for (final detail in _detailsMap!.values) {
        totalDeductionsDays += detail.totalDeductionDays;
        totalDeductionsCount += detail.deductionCount;
        totalRequests += detail.requestsCount;
        totalLeaves += detail.leavesCount;
        totalPermissions += detail.permissionsCount;
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _SheetHeader(
              title: widget.department,
              subtitle:
                  '$totalEmployees موظف · دورة ${widget.monthKey ?? 'الحالية'}',
              actions: [
                if (widget.reviewer != null)
                  IconButton(
                    tooltip: 'تصدير تقرير القسم (Excel / CSV)',
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    onPressed: () => _openExportDialog(),
                  ),
              ],
            ),

            // Top Department KPI and Summary Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface02,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZaWolfColors.surface03),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ScoreCircle(value: avgScore, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'متوسط أداء القسم: ${avgScore.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'إجمالي الموظفين: $totalEmployees · المهام المكتملة: $totalCompletedTasks (متأخرة: $totalOverdueTasks)',
                                style: const TextStyle(
                                  color: ZaWolfColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.reviewer != null)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ZaWolfColors.primaryCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _openExportDialog(),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('تقرير القسم'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: ZaWolfColors.surface03),
                    const SizedBox(height: 10),
                    // Metrics Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStatItem(
                          label: 'الغياب',
                          value: '$totalAbsent يوم',
                          color: totalAbsent > 0
                              ? ZaWolfColors.error
                              : ZaWolfColors.success,
                          icon: Icons.person_off_outlined,
                        ),
                        _SummaryStatItem(
                          label: 'الخصومات',
                          value: _loading
                              ? '...'
                              : '${totalDeductionsDays.toStringAsFixed(2)} يوم'
                                  '${totalDeductionsCount > 0 ? ' ($totalDeductionsCount)' : ''}',
                          color: totalDeductionsDays > 0
                              ? ZaWolfColors.warning
                              : ZaWolfColors.success,
                          icon: Icons.remove_circle_outline,
                        ),
                        _SummaryStatItem(
                          label: 'التأخيرات',
                          value: '$totalLate يوم',
                          color: totalLate > 0
                              ? ZaWolfColors.warning
                              : ZaWolfColors.success,
                          icon: Icons.timer_outlined,
                        ),
                        _SummaryStatItem(
                          label: 'الطلبات',
                          value: _loading
                              ? '...'
                              : '$totalRequests ($totalLeaves إجازة · $totalPermissions إذن)',
                          color: ZaWolfColors.primaryCyan,
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Employee List with enhanced cards
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: ZaWolfColors.surface03),
                itemBuilder: (context, index) {
                  final score = sorted[index];
                  final detail = _detailsMap?[score.userId];

                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    leading: _ScoreCircle(value: score.overallScore),
                    title: Text(
                      score.employeeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${score.employeeId} · ${score.statusLabel}',
                            style: const TextStyle(
                              color: ZaWolfColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _MiniBadge(
                                label: 'غياب: ${score.absentDays} يوم',
                                color: score.absentDays > 0
                                    ? ZaWolfColors.error
                                    : ZaWolfColors.textMuted,
                              ),
                              _MiniBadge(
                                label: detail != null
                                    ? (detail.totalDeductionDays > 0
                                        ? 'خصم: ${detail.totalDeductionDays.toStringAsFixed(2)} يوم'
                                        : (detail.deductionCount > 0
                                            ? 'خصم: ${detail.deductionCount} مرة'
                                            : 'خصم: 0'))
                                    : 'خصم: ...',
                                color: (detail?.totalDeductionDays ?? 0) > 0
                                    ? ZaWolfColors.warning
                                    : ZaWolfColors.textMuted,
                              ),
                              _MiniBadge(
                                label: 'تأخير: ${score.lateDays} يوم',
                                color: score.lateDays > 0
                                    ? ZaWolfColors.warning
                                    : ZaWolfColors.textMuted,
                              ),
                              _MiniBadge(
                                label: detail != null
                                    ? 'طلبات: ${detail.requestsCount}'
                                    : 'طلبات: ...',
                                color: (detail?.requestsCount ?? 0) > 0
                                    ? ZaWolfColors.primaryCyan
                                    : ZaWolfColors.textMuted,
                              ),
                              _MiniBadge(
                                label:
                                    'مهام: ${score.completedTasks}/${score.totalTasks}',
                                color: score.overdueTasks > 0
                                    ? ZaWolfColors.warning
                                    : ZaWolfColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    children: [
                      const SizedBox(height: 8),
                      // 1. Performance breakdown bars
                      _ScoreBreakdown(
                        score: score,
                        onUpdateBehavior: widget.onUpdateBehavior,
                      ),
                      const Divider(color: ZaWolfColors.surface03),

                      // 2. Attendance & Tasks metrics
                      _SectionHeader(title: 'ملخص الحضور والمهام'),
                      _MetricLine(
                        label: 'أيام الغياب',
                        value: '${score.absentDays} يوم',
                      ),
                      _MetricLine(
                        label: 'أيام التأخير',
                        value: '${score.lateDays} يوم',
                      ),
                      _MetricLine(
                        label: 'المهام المكتملة',
                        value:
                            '${score.completedTasks} من أصل ${score.totalTasks}',
                      ),
                      _MetricLine(
                        label: 'المهام المتأخرة',
                        value: '${score.overdueTasks}',
                      ),
                      const SizedBox(height: 10),

                      // 3. Deductions breakdown
                      _SectionHeader(title: 'سجل الخصومات والتأخيرات'),
                      if (detail == null && _loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (detail != null && detail.deductions.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final totalDays = detail.totalDeductionDays;
                            final lateItems = detail.deductions.where(
                              (d) =>
                                  d.reasonLabel.contains('تأخير') ||
                                  (d.lateMinutes != null && d.lateMinutes! > 0),
                            );
                            final lateDays = lateItems.fold(
                              0.0,
                              (sum, d) => sum + d.dayFraction,
                            );
                            final absentItems = detail.deductions.where(
                              (d) =>
                                  d.sourceLabel.contains('غياب') ||
                                  d.reasonLabel.contains('غياب') ||
                                  d.dayFraction >= 1.0,
                            );
                            final absentDays = absentItems.fold(
                              0.0,
                              (sum, d) => sum + d.dayFraction,
                            );
                            final otherItems = detail.deductions.where(
                              (d) =>
                                  !lateItems.contains(d) &&
                                  !absentItems.contains(d),
                            );
                            final otherDays = otherItems.fold(
                              0.0,
                              (sum, d) => sum + d.dayFraction,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ZaWolfColors.warning.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.summarize_outlined,
                                            size: 18,
                                            color: ZaWolfColors.warning,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'إجمالي الخصومات المسجلة على الموظف',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ZaWolfColors.warning,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${totalDays.toStringAsFixed(2)} يوم (${detail.deductions.length} إجراء)',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1, color: ZaWolfColors.surface03),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (lateDays > 0)
                                        _MiniBadge(
                                          label:
                                              'تأخيرات: ${lateDays.toStringAsFixed(2)} يوم (${lateItems.length})',
                                          color: ZaWolfColors.warning,
                                        ),
                                      if (absentDays > 0)
                                        _MiniBadge(
                                          label:
                                              'غياب: ${absentDays.toStringAsFixed(2)} يوم (${absentItems.length})',
                                          color: ZaWolfColors.error,
                                        ),
                                      if (otherDays > 0)
                                        _MiniBadge(
                                          label:
                                              'أخرى / جزاءات: ${otherDays.toStringAsFixed(2)} يوم (${otherItems.length})',
                                          color: ZaWolfColors.primaryCyan,
                                        ),
                                      if (detail.totalDeductionAmount > 0)
                                        _MiniBadge(
                                          label:
                                              'القيمة المالية: ${detail.totalDeductionAmount.toStringAsFixed(2)} ج.م',
                                          color: Colors.amberAccent,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Column(
                          children: detail.deductions.map((ded) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.surface02,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ZaWolfColors.surface03,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: ZaWolfColors.warning
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.money_off,
                                          size: 16,
                                          color: ZaWolfColors.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ded.reasonLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${ded.date} · المصدر: ${ded.sourceLabel}',
                                              style: const TextStyle(
                                                color: ZaWolfColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ZaWolfColors.warning
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: ZaWolfColors.warning
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              ded.fractionLabel,
                                              style: const TextStyle(
                                                color: ZaWolfColors.warning,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ded.approvalLabel,
                                            style: TextStyle(
                                              color: ded.approvalStatus == 'approved'
                                                  ? ZaWolfColors.success
                                                  : ZaWolfColors.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (ded.detailedExplanation != null &&
                                      ded.detailedExplanation!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: ZaWolfColors.surface03,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.info_outline,
                                                size: 14,
                                                color: ZaWolfColors.primaryCyan,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  ded.detailedExplanation!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (ded.policyRule != null &&
                                              ded.policyRule!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '📌 ${ded.policyRule}',
                                              style: const TextStyle(
                                                color: ZaWolfColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (ded.checkInTime != null ||
                                      ded.checkOutTime != null ||
                                      (ded.lateMinutes != null &&
                                          ded.lateMinutes! > 0) ||
                                      ded.approvedByName != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (ded.checkInTime != null)
                                          _MiniBadge(
                                            label:
                                                'حضور: ${intl.DateFormat('hh:mm a', 'ar').format(ded.checkInTime!)}',
                                            color: ZaWolfColors.primaryCyan,
                                          ),
                                        if (ded.lateMinutes != null &&
                                            ded.lateMinutes! > 0)
                                          _MiniBadge(
                                            label:
                                                'تأخير: ${ded.lateMinutes} دقيقة',
                                            color: ZaWolfColors.warning,
                                          ),
                                        if (ded.checkOutTime != null)
                                          _MiniBadge(
                                            label:
                                                'انصراف: ${intl.DateFormat('hh:mm a', 'ar').format(ded.checkOutTime!)}',
                                            color: ZaWolfColors.textSecondary,
                                          ),
                                        if (ded.approvedByName != null &&
                                            ded.approvedByName!.isNotEmpty)
                                          _MiniBadge(
                                            label:
                                                'المعتمد: ${ded.approvedByName}',
                                            color: ZaWolfColors.textMuted,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ]
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                ZaWolfColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ لا توجد خصومات مسجلة على الموظف في هذه الدورة',
                            style: TextStyle(
                              color: ZaWolfColors.success,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // 4. Requests breakdown
                      _SectionHeader(title: 'سجل الطلبات (إجازات / أذونات / مأموريات)'),
                      if (detail == null && _loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (detail != null && detail.requests.isNotEmpty)
                        Column(
                          children: detail.requests.map((req) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.surface02,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: ZaWolfColors.surface03),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    req.type == 'leave'
                                        ? Icons.beach_access
                                        : (req.type == 'permission'
                                            ? Icons.access_time
                                            : Icons.assignment_outlined),
                                    size: 18,
                                    color: ZaWolfColors.primaryCyan,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req.requestType,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${req.details} · ${intl.DateFormat('yyyy/MM/dd').format(req.occursAt ?? req.submittedAt)}',
                                          style: const TextStyle(
                                            color: ZaWolfColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (req.status == 'approved'
                                              ? ZaWolfColors.success
                                              : (req.isPending
                                                  ? ZaWolfColors.warning
                                                  : ZaWolfColors.error))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      req.statusLabel,
                                      style: TextStyle(
                                        color: req.status == 'approved'
                                            ? ZaWolfColors.success
                                            : (req.isPending
                                                ? ZaWolfColors.warning
                                                : ZaWolfColors.error),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface02,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'لا توجد طلبات مسجلة للموظف في هذه الدورة',
                            style: TextStyle(
                              color: ZaWolfColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // 5. Download Employee Report Button
                      if (widget.reviewer != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ZaWolfColors.primaryCyan,
                              side: const BorderSide(
                                color: ZaWolfColors.primaryCyan,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () => _openExportDialog(
                              specificEmployeeId: score.employeeId,
                            ),
                            icon: const Icon(Icons.download, size: 16),
                            label: Text(
                              'تصدير تقرير ${score.employeeName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatItem extends StatelessWidget {
  const _SummaryStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: const TextStyle(
            color: ZaWolfColors.primaryCyan,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ScoreDetailsSheet extends StatelessWidget {
  const _ScoreDetailsSheet({
    required this.score,
    this.reviewer,
    this.onUpdateBehavior,
  });

  final ProductivityScoreModel score;
  final UserModel? reviewer;
  final BehaviorScoreUpdater? onUpdateBehavior;

  @override
  Widget build(BuildContext context) {
    final calculatedAt = score.calculatedAt == null
        ? 'لم يُسجل وقت الحساب'
        : intl.DateFormat('yyyy/MM/dd - hh:mm a').format(score.calculatedAt!);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            _SheetHeader(
              title: score.employeeName,
              subtitle: '${score.department} · ${score.employeeId}',
              actions: [
                if (reviewer != null)
                  IconButton(
                    tooltip: 'تصدير تقرير الموظف',
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    onPressed: () {
                      showPerformanceExportDialog(
                        context,
                        scores: [score],
                        reviewer: reviewer!,
                        initialDepartment: score.department,
                        initialEmployeeId: score.employeeId,
                        monthKey: score.monthKey,
                      );
                    },
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Row(
                    children: [
                      _ScoreCircle(value: score.overallScore, size: 68),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              score.statusLabel,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: _scoreColor(score.overallScore),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'دورة ${score.monthKey}',
                              style: const TextStyle(
                                color: ZaWolfColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'حالة مصادر البيانات: ${score.inputStateLabel}',
                              style: TextStyle(
                                color: switch (score.inputState) {
                                  ProductivityInputState.complete =>
                                    ZaWolfColors.success,
                                  ProductivityInputState.partial =>
                                    ZaWolfColors.warning,
                                  ProductivityInputState.unavailable =>
                                    ZaWolfColors.error,
                                },
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ScoreBreakdown(
                    score: score,
                    onUpdateBehavior: onUpdateBehavior,
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: ZaWolfColors.surface03),
                  _MetricLine(
                    label: 'المهام المكتملة',
                    value: '${score.completedTasks} من ${score.totalTasks}',
                  ),
                  _MetricLine(
                    label: 'المهام المتأخرة',
                    value: '${score.overdueTasks}',
                  ),
                  _MetricLine(
                    label: 'أيام الغياب',
                    value: '${score.absentDays}',
                  ),
                  _MetricLine(
                    label: 'أيام التأخير',
                    value: '${score.lateDays}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'آخر حساب: $calculatedAt',
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ZaWolfColors.textMuted,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
              IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.score, this.onUpdateBehavior});

  final ProductivityScoreModel score;
  final BehaviorScoreUpdater? onUpdateBehavior;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (score.hasKpiData)
          _ScoreBar(label: 'KPI · وزن 70%', value: score.kpiScore)
        else
          const _ScoreBar(label: 'KPI · غير مطبق (بدون KPI مسند)', value: 0),
        _ScoreBar(
          label: score.hasKpiData
              ? 'الحضور والانضباط · وزن 15%'
              : 'الحضور والانضباط · وزن 50%',
          value: score.attendanceComponentScore,
        ),
        _ScoreBar(
          label: score.hasKpiData ? 'السلوك · وزن 15%' : 'السلوك · وزن 50%',
          value: score.behaviorScore,
        ),
        if (onUpdateBehavior != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _editBehavior(context),
              icon: const Icon(Icons.edit_note),
              label: const Text('تعديل تقييم السلوك'),
            ),
          ),
      ],
    );
  }

  Future<void> _editBehavior(BuildContext context) async {
    var value = score.behaviorScore;
    final reasonController = TextEditingController();
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تعديل تقييم السلوك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.toStringAsFixed(0)}%'),
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (next) => setState(() => value = next),
              ),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب التعديل',
                  hintText: 'اكتب سببًا واضحًا للموظف',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.length < 3) return;
                Navigator.pop(dialogContext, (value, reason));
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (result != null) await onUpdateBehavior!(score, result.$1, result.$2);
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _scoreColor(value),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            color: _scoreColor(value),
            backgroundColor: ZaWolfColors.surface03,
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.value, this.size = 48});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _scoreColor(value).withValues(alpha: 0.12),
        border: Border.all(color: _scoreColor(value).withValues(alpha: 0.5)),
      ),
      child: Text(
        value.toStringAsFixed(0),
        style: TextStyle(
          color: _scoreColor(value),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Color _scoreColor(double value) {
  if (value >= 85) return ZaWolfColors.success;
  if (value >= 70) return ZaWolfColors.warning;
  return ZaWolfColors.error;
}
