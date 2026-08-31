import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
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
      appBar: AppBar(title: const Text('سجل الموظف التشغيلي')),
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
                        onSelected: state.savingEmployeeId != null
                            ? null
                            : (value) => context
                                  .read<OperationalVisibilityCubit>()
                                  .setHidden(
                                    employeeUserId: widget.employeeUserId,
                                    hidden: value,
                                    reasonAr: value
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
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return Center(
                        child: TextButton(
                          onPressed: state.loading
                              ? null
                              : context.read<EmployeeTimelineCubit>().loadMore,
                          child: const Text('تحميل المزيد'),
                        ),
                      );
                    }
                    return _TimelineTile(item: state.items[index]);
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
      trailing: Text(item.status),
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
