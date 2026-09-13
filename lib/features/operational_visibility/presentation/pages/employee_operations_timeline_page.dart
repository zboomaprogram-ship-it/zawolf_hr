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
  String _selectedCategory = 'all';

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

  void _setPresetRange(int monthOffset) {
    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + monthOffset, 1);
    setState(() {
      _range = DateTimeRange(
        start: targetMonth,
        end: DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59),
      );
    });
    _load();
  }

  List<EmployeeTimelineEntry> _filterItems(List<EmployeeTimelineEntry> items) {
    if (_selectedCategory == 'all') return items;
    return items.where((item) {
      return switch (_selectedCategory) {
        'attendance' => item.kind == EmployeeTimelineKind.attendance,
        'leave' => item.kind == EmployeeTimelineKind.leave,
        'permission' => item.kind == EmployeeTimelineKind.permission,
        'deduction' => item.kind == EmployeeTimelineKind.deduction,
        'correction' => item.kind == EmployeeTimelineKind.correction,
        _ => true,
      };
    }).toList();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return BlocBuilder<EmployeeTimelineCubit, EmployeeTimelineState>(
            builder: (context, state) {
              if (state.loading && state.items.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                );
              }
              if (state.safeErrorCode != null && state.items.isEmpty) {
                return _TimelineMessage(
                  icon: Icons.error_outline,
                  message: 'تعذر تحميل السجل الآن. حاول مرة أخرى.',
                  onRetry: _load,
                );
              }

              final filteredItems = _filterItems(state.items);

              if (isDesktop) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: ListView(
                              children: [
                                _buildPeriodCard(isDesktop),
                                const SizedBox(height: 16),
                                _PeriodSummaryCard(summary: state.summary),
                                const SizedBox(height: 16),
                                _buildFilterCard(),
                                if (widget.canManageVisibility) ...[
                                  const SizedBox(height: 16),
                                  _buildVisibilityCard(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTimelineStream(state, filteredItems),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        _buildPeriodCard(isDesktop),
                        const SizedBox(height: 10),
                        _PeriodSummaryCard(summary: state.summary),
                        const SizedBox(height: 10),
                        _buildFilterChipsRow(),
                        if (widget.canManageVisibility) ...[
                          const SizedBox(height: 8),
                          _buildVisibilityChipOnly(),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: ZaWolfColors.surface03, height: 1),
                  Expanded(
                    child: _buildTimelineStream(state, filteredItems),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );

  Widget _buildPeriodCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, color: ZaWolfColors.primaryCyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'فترة المراجعة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickPeriod,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'تعديل',
                        style: TextStyle(
                          color: ZaWolfColors.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_calendar_outlined, size: 14, color: ZaWolfColors.primaryCyan),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface02,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${DateFormat('yyyy/MM/dd').format(_range.start)} — ${DateFormat('yyyy/MM/dd').format(_range.end)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: ZaWolfColors.surface03),
                  ),
                  onPressed: () => _setPresetRange(0),
                  child: const Text('الشهر الحالي', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: ZaWolfColors.surface03),
                  ),
                  onPressed: () => _setPresetRange(-1),
                  child: const Text('الشهر السابق', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    final categories = [
      ('all', 'جميع العمليات', Icons.all_inclusive_rounded),
      ('attendance', 'بصمات الحضور', Icons.fingerprint_rounded),
      ('leave', 'الإجازات', Icons.event_available_rounded),
      ('permission', 'الأذونات', Icons.schedule_rounded),
      ('deduction', 'الخصومات', Icons.money_off_rounded),
      ('correction', 'تصحيحات الحضور', Icons.edit_calendar_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تصفية نوع العملية',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...categories.map((cat) {
            final isSelected = _selectedCategory == cat.$1;
            return InkWell(
              onTap: () => setState(() => _selectedCategory = cat.$1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZaWolfColors.primaryCyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? ZaWolfColors.primaryCyan : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat.$3,
                      size: 18,
                      color: isSelected ? ZaWolfColors.primaryCyan : ZaWolfColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cat.$2,
                      style: TextStyle(
                        color: isSelected ? Colors.white : ZaWolfColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    final categories = [
      ('all', 'الكل'),
      ('attendance', 'حضور'),
      ('leave', 'إجازات'),
      ('permission', 'أذونات'),
      ('deduction', 'خصومات'),
      ('correction', 'تصحيحات'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(cat.$2),
              onSelected: (_) => setState(() => _selectedCategory = cat.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return BlocBuilder<OperationalVisibilityCubit, OperationalVisibilityState>(
      builder: (context, state) {
        final hidden = state.hiddenEmployeeIds.contains(widget.employeeUserId);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface01,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZaWolfColors.surface03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرؤية والظهور التشغيلي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              FilterChip(
                selected: hidden,
                label: Text(
                  hidden
                      ? 'مخفي من الحضور اليومي'
                      : 'إخفاء حساب الاختبار من الحضور',
                ),
                onSelected: state.savingEmployeeId != null
                    ? null
                    : (value) => context.read<OperationalVisibilityCubit>().setHidden(
                          employeeUserId: widget.employeeUserId,
                          hidden: value,
                          reasonAr: value
                              ? 'حساب غير تشغيلي أو مخصص للاختبار'
                              : 'إعادة الحساب إلى العرض التشغيلي',
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisibilityChipOnly() {
    return BlocBuilder<OperationalVisibilityCubit, OperationalVisibilityState>(
      builder: (context, state) {
        final hidden = state.hiddenEmployeeIds.contains(widget.employeeUserId);
        return Align(
          alignment: Alignment.centerRight,
          child: FilterChip(
            selected: hidden,
            label: Text(
              hidden
                  ? 'مخفي من الحضور اليومي'
                  : 'إخفاء حساب الاختبار من الحضور',
            ),
            onSelected: state.savingEmployeeId != null
                ? null
                : (value) => context.read<OperationalVisibilityCubit>().setHidden(
                      employeeUserId: widget.employeeUserId,
                      hidden: value,
                      reasonAr: value
                          ? 'حساب غير تشغيلي أو مخصص للاختبار'
                          : 'إعادة الحساب إلى العرض التشغيلي',
                    ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineStream(
    EmployeeTimelineState state,
    List<EmployeeTimelineEntry> items,
  ) {
    if (items.isEmpty) {
      return const _TimelineMessage(
        icon: Icons.history_toggle_off,
        message: 'لا توجد عمليات مسجلة مطابقة للفترة والتصفية المحددة.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton.tonal(
                onPressed: state.loading
                    ? null
                    : context.read<EmployeeTimelineCubit>().loadMore,
                child: const Text('تحميل المزيد من العمليات'),
              ),
            ),
          );
        }
        return _TimelineTile(item: items[index]);
      },
    );
  }
}

final class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item});
  final EmployeeTimelineEntry item;

  @override
  Widget build(BuildContext context) {
    final color = _color(item.kind);
    final statusText = _statusLabel(item);
    final isConfirmed = item.status == 'present' ||
        item.status == 'approved' ||
        item.status == 'accepted';
    final isPending = item.status.contains('pending');
    final isNegative = item.status == 'rejected' ||
        item.status == 'cancelled' ||
        item.kind == EmployeeTimelineKind.deduction;

    final badgeColor = isConfirmed
        ? ZaWolfColors.success
        : isPending
            ? ZaWolfColors.warning
            : isNegative
                ? ZaWolfColors.error
                : ZaWolfColors.primaryCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(_icon(item.kind), color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _label(item.kind),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: ZaWolfColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy/MM/dd – hh:mm a').format(item.effectiveAt.toLocal()),
                        style: const TextStyle(
                          color: ZaWolfColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (item.summaryAr?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface02,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.summaryAr!,
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(EmployeeTimelineKind kind) => switch (kind) {
    EmployeeTimelineKind.attendance => Icons.fingerprint,
    EmployeeTimelineKind.leave => Icons.event_available,
    EmployeeTimelineKind.permission => Icons.schedule,
    EmployeeTimelineKind.correction => Icons.edit_calendar,
    EmployeeTimelineKind.deduction => Icons.money_off,
    _ => Icons.assignment_outlined,
  };

  static Color _color(EmployeeTimelineKind kind) => switch (kind) {
    EmployeeTimelineKind.attendance => ZaWolfColors.success,
    EmployeeTimelineKind.leave => ZaWolfColors.dayoffPurple,
    EmployeeTimelineKind.permission => ZaWolfColors.permissionTeal,
    EmployeeTimelineKind.correction => ZaWolfColors.primaryCyan,
    EmployeeTimelineKind.deduction => ZaWolfColors.error,
    _ => ZaWolfColors.primaryBlue,
  };

  static String _label(EmployeeTimelineKind kind) => switch (kind) {
    EmployeeTimelineKind.attendance => 'تسجيل حضور / انصراف',
    EmployeeTimelineKind.leave => 'طلب إجازة',
    EmployeeTimelineKind.permission => 'طلب إذن',
    EmployeeTimelineKind.correction => 'تصحيح حضور يدوي',
    EmployeeTimelineKind.deduction => 'خصم من الراتب',
    _ => 'طلب إداري',
  };

  static String _statusLabel(EmployeeTimelineEntry item) {
    if (item.kind == EmployeeTimelineKind.deduction &&
        item.summaryAr?.trim().isNotEmpty == true) {
      return item.summaryAr!.trim();
    }
    if (item.kind == EmployeeTimelineKind.attendance ||
        item.kind == EmployeeTimelineKind.deduction) {
      if (item.status == 'present') return 'حضور مؤكد';
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
            : 'مسجل بالنظام',
    };
  }
}

final class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.summary});

  final EmployeeTimelineSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ZaWolfColors.surface01,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ZaWolfColors.surface03),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملخص مؤشرات الفترة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 500;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: isWide ? 2.4 : 2.2,
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
                  color: ZaWolfColors.dayoffPurple,
                ),
                _SummaryMetric(
                  icon: Icons.schedule_outlined,
                  value: '${summary.permissionRequests}',
                  label: 'طلبات إذن',
                  color: ZaWolfColors.permissionTeal,
                ),
                _SummaryMetric(
                  icon: Icons.assignment_outlined,
                  value: '${summary.otherRequests}',
                  label: 'طلبات أخرى',
                  color: ZaWolfColors.primaryCyan,
                ),
              ],
            );
          },
        ),
      ],
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
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
                  color: ZaWolfColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  color: ZaWolfColors.textSecondary,
                  fontSize: 10,
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
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: ZaWolfColors.textMuted),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ],
      ),
    ),
  );
}
