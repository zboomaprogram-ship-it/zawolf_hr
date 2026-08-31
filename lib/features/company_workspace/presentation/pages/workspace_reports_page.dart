import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_report_period.dart';
import '../cubit/workspace_reports_cubit.dart';
import '../widgets/workspace_sync_status_banner.dart';

class WorkspaceReportsPage extends StatefulWidget {
  const WorkspaceReportsPage({required this.onOpenResource, super.key});
  final ValueChanged<String> onOpenResource;

  @override
  State<WorkspaceReportsPage> createState() => _WorkspaceReportsPageState();
}

class _WorkspaceReportsPageState extends State<WorkspaceReportsPage> {
  WorkspaceReportPeriodType _type = WorkspaceReportPeriodType.monthly;
  String _reportType = 'attendance';
  bool _activityReport = false;
  DateTimeRange? _customRange;

  WorkspaceReportPeriod _period() {
    final today = DateUtils.dateOnly(DateTime.now());
    return switch (_type) {
      WorkspaceReportPeriodType.daily => WorkspaceReportPeriod(
        type: _type,
        startsOn: today,
        endsOn: today,
      ),
      WorkspaceReportPeriodType.weekly => WorkspaceReportPeriod(
        type: _type,
        startsOn: today.subtract(const Duration(days: 6)),
        endsOn: today,
      ),
      WorkspaceReportPeriodType.monthly => WorkspaceReportPeriod(
        type: _type,
        startsOn: DateTime(today.year, today.month, 1),
        endsOn: today,
      ),
      WorkspaceReportPeriodType.custom => WorkspaceReportPeriod(
        type: _type,
        startsOn:
            _customRange?.start ?? today.subtract(const Duration(days: 29)),
        endsOn: _customRange?.end ?? today,
      ),
    };
  }

  Future<void> _chooseCustomRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          ),
    );
    if (selected != null && mounted) setState(() => _customRange = selected);
  }

  void _generate(BuildContext context) {
    final cubit = context.read<WorkspaceReportsCubit>();
    if (_activityReport) {
      cubit.generateActivity(period: _period());
      return;
    }
    cubit.generateHr(period: _period(), reportType: _reportType);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('تقارير ملفات الشركة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<WorkspaceReportsCubit, WorkspaceReportsState>(
          listener: (context, state) {
            if (state case WorkspaceReportsReady(
              :final resourceId,
              :final message,
            )) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
              widget.onOpenResource(resourceId);
            }
          },
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state is WorkspaceReportsGenerating)
                const WorkspaceSyncStatusBanner(
                  message: 'يجري إعداد التقرير. لا تعِد إرسال الطلب.',
                  kind: WorkspaceSyncStatusKind.pending,
                ),
              if (state is WorkspaceReportsFailure)
                WorkspaceSyncStatusBanner(
                  message: state.message,
                  kind: WorkspaceSyncStatusKind.failure,
                  actionLabel: 'إعادة المحاولة',
                  onAction: () => _generate(context),
                ),
              const Text(
                'تُنشأ التقارير داخل مجلد التقارير بصلاحيات النظام، ولا تُعرض روابط Google مباشرة.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DropdownButton<WorkspaceReportPeriodType>(
                    value: _type,
                    items: WorkspaceReportPeriodType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      setState(() => _type = value!);
                      if (value == WorkspaceReportPeriodType.custom) {
                        await _chooseCustomRange();
                      }
                    },
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('تشغيلي HR')),
                      ButtonSegment(value: true, label: Text('نشاط الملفات')),
                    ],
                    selected: {_activityReport},
                    onSelectionChanged: (value) =>
                        setState(() => _activityReport = value.first),
                  ),
                  if (!_activityReport)
                    DropdownButton<String>(
                      value: _reportType,
                      items: const [
                        DropdownMenuItem(
                          value: 'attendance',
                          child: Text('الحضور'),
                        ),
                        DropdownMenuItem(
                          value: 'requests',
                          child: Text('الطلبات'),
                        ),
                        DropdownMenuItem(
                          value: 'deductions',
                          child: Text('الخصومات'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _reportType = value!),
                    ),
                  FilledButton.icon(
                    onPressed: state is WorkspaceReportsGenerating
                        ? null
                        : () => _generate(context),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('إنشاء التقرير'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state is WorkspaceReportsIdle)
                const Expanded(
                  child: Center(
                    child: Text(
                      'اختر نوع التقرير والفترة ثم اضغط إنشاء التقرير.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
