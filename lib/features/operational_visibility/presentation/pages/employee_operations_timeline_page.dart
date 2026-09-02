import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
import '../../../../design_system/components/rtl_navigation.dart';
import '../../../../models/attendance_policy.dart';
import '../../domain/entities/employee_timeline_entry.dart';
import '../../domain/entities/employee_timeline_query.dart';
import '../cubit/employee_timeline_cubit.dart';
import '../cubit/operational_visibility_cubit.dart';

final class EmployeeOperationsTimelinePage extends StatefulWidget {
  const EmployeeOperationsTimelinePage({
    super.key,
    required this.employeeUserId,
    required this.canManageVisibility,
  });

  final String employeeUserId;
  final bool canManageVisibility;

  @override
  State<EmployeeOperationsTimelinePage> createState() =>
      _EmployeeOperationsTimelinePageState();
}

final class _EmployeeOperationsTimelinePageState
    extends State<EmployeeOperationsTimelinePage> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() => context.read<EmployeeTimelineCubit>().load(
    EmployeeTimelineQuery(
      employeeUserId: widget.employeeUserId,
      from: _range.start,
      to: _range.end,
    ),
  );

  Future<void> _pickPeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: _range,
      helpText: 'اختر فترة مراجعة الموظف',
      saveText: 'تطبيق',
      cancelText: 'إلغاء',
    );
    if (selected == null || !mounted) return;
    setState(() => _range = selected);
    _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: Icon(RtlNavigation.backIcon(context)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('سجل الموظف التشغيلي'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickPeriod,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${DateFormat('yyyy/MM/dd').format(_range.start)} — '
                    '${DateFormat('yyyy/MM/dd').format(_range.end)}',
                  ),
                ),
                if (widget.canManageVisibility)
                  BlocBuilder<
                    OperationalVisibilityCubit,
                    OperationalVisibilityState
                  >(
                    builder: (context, state) {
                      final hidden = state.hiddenEmployeeIds.contains(
                        widget.employeeUserId,
                      );
                      return FilterChip(
                        selected: hidden,
                        label: Text(
                          hidden
                              ? 'مخفي من الحضور اليومي'
                              : 'إخفاء حساب الاختبار من الحضور',
                        ),
                        onSelected:
                            state.savingEmployeeId != null
                                ? null
                                : (value) => context
                                    .read<OperationalVisibilityCubit>()
                                    .setHidden(
                                      employeeUserId: widget.employeeUserId,
                                      hidden: value,
                                      reasonAr:
                                          value
                                              ? 'حساب غير تشغيلي أو مخصص للاختبار'
                                              : 'إعادة الحساب إلى العرض التشغيلي',
                                    ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<EmployeeTimelineCubit, EmployeeTimelineState>(
              builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.safeErrorCode != null && state.items.isEmpty) {
                  return _TimelineMessage(
                    icon: Icons.error_outline,
                    message: 'تعذر تحميل السجل الآن. حاول مرة أخرى.',
                    onRetry: _load,
                  );
                }
                if (state.items.isEmpty) {
                  return const _TimelineMessage(
                    icon: Icons.history_toggle_off,
                    message: 'لا توجد عمليات ضمن الفترة المحددة.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: state.items.length + (state.hasMore ? 2 : 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PeriodSummaryCard(summary: state.summary),
                      );
                    }
                    final itemIndex = index - 1;
                    if (itemIndex == state.items.length) {
                      return Center(
                        child: TextButton(
                          onPressed:
                              state.loading
                                  ? null
                                  : context
                                      .read<EmployeeTimelineCubit>()
                                      .loadMore,
                          child: const Text('تحميل المزيد'),
                        ),
                      );
                    }
                    return _TimelineTile(item: state.items[itemIndex]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

final class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item});
  final EmployeeTimelineEntry item;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(_icon(item.kind), color: ZaWolfColors.primaryCyan),
      title: Text(_label(item.kind)),
      subtitle: Text(
        '${DateFormat('yyyy/MM/dd – HH:mm').format(item.effectiveAt.toLocal())}'
        '${item.summaryAr?.isNotEmpty == true ? '\n${item.summaryAr}' : ''}',
      ),
      trailing: Text(
        _statusLabel(item),
        textAlign: TextAlign.end,
        style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
      ),
    ),
  );

  static IconData _icon(EmployeeTimelineKind kind) => switch (kind) {
    EmployeeTimelineKind.attendance => Icons.fingerprint,
    EmployeeTimelineKind.leave => Icons.event_available,
    EmployeeTimelineKind.permission => Icons.schedule,
    EmployeeTimelineKind.correction => Icons.edit_calendar,
    EmployeeTimelineKind.deduction => Icons.money_off,
    _ => Icons.assignment_outlined,
  };

  static String _label(EmployeeTimelineKind kind) => switch (kind) {
    EmployeeTimelineKind.attendance => 'حضور',
    EmployeeTimelineKind.leave => 'إجازة',
    EmployeeTimelineKind.permission => 'إذن',
    EmployeeTimelineKind.correction => 'تصحيح حضور',
    EmployeeTimelineKind.deduction => 'خصم',
    _ => 'طلب إداري',
  };

  static String _statusLabel(EmployeeTimelineEntry item) {
    if (item.kind == EmployeeTimelineKind.deduction &&
        item.summaryAr?.trim().isNotEmpty == true) {
      return item.summaryAr!.trim();
    }
    if (item.kind == EmployeeTimelineKind.attendance ||
        item.kind == EmployeeTimelineKind.deduction) {
      if (item.status == 'present') return 'حضور مؤكد\nلا يوجد خصم';
      return AttendancePolicy.arabicDeductionLabel(
        item.status,
        fallback: item.summaryAr,
      );
    }
    return switch (item.status.trim().toLowerCase()) {
      'approved' || 'accepted' => 'تمت الموافقة',
      'pending' ||
      'pending_hr' ||
      'pending_manager' ||
      'pending_ceo' => 'بانتظار المراجعة',
      'rejected' => 'مرفوض',
      'cancelled' => 'ملغي',
      'reviewed' => 'تمت المراجعة',
      'present' => 'تم التأكيد',
      _ =>
        item.summaryAr?.trim().isNotEmpty == true
            ? item.summaryAr!.trim()
            : 'مسجل في السجل',
    };
  }
}

final class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.summary});

  final EmployeeTimelineSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    color: ZaWolfColors.surface01,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الفترة المختارة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isWide ? 2.8 : 2.4,
                children: [
                  _SummaryMetric(
                    icon: Icons.money_off_csred_outlined,
                    value: _formatDays(summary.salaryDeductionDays),
                    label: 'خصومات راتب',
                    color: ZaWolfColors.warning,
                  ),
                  _SummaryMetric(
                    icon: Icons.event_available_outlined,
                    value: '${summary.leaveRequests}',
                    label: 'طلبات إجازة',
                    color: ZaWolfColors.primaryCyan,
                  ),
                  _SummaryMetric(
                    icon: Icons.schedule_outlined,
                    value: '${summary.permissionRequests}',
                    label: 'طلبات إذن',
                    color: ZaWolfColors.success,
                  ),
                  _SummaryMetric(
                    icon: Icons.assignment_outlined,
                    value: '${summary.otherRequests}',
                    label: 'طلبات أخرى',
                    color: Colors.deepPurpleAccent,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  static String _formatDays(double value) {
    if (value == 0) return '0 يوم';
    if (value == value.roundToDouble()) return '${value.toInt()} يوم';
    return '${value.toStringAsFixed(1)} يوم';
  }
}

final class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  color: ZaWolfColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _TimelineMessage extends StatelessWidget {
  const _TimelineMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: ZaWolfColors.textMuted),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
