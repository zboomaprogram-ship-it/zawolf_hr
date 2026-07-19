import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/kpi_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/kpi_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class KpiManagementScreen extends StatefulWidget {
  const KpiManagementScreen({super.key});

  @override
  State<KpiManagementScreen> createState() => _KpiManagementScreenState();
}

class _KpiManagementScreenState extends State<KpiManagementScreen> {
  final KpiService _kpiService = KpiService();
  final String _monthKey = PayrollCycle.keyFor(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    if (reviewer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة KPI', style: theme.textTheme.headlineMedium),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'أهداف الموظفين'),
              Tab(text: 'القوالب'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'إضافة قالب',
              onPressed: () => _showTemplateSheet(context, reviewer),
              icon: const Icon(
                Icons.add_chart,
                color: ZaWolfColors.primaryCyan,
              ),
            ),
            IconButton(
              tooltip: 'تعيين KPI',
              onPressed: () => _showAssignSheet(context, reviewer),
              icon: const Icon(
                Icons.person_add_alt_1,
                color: ZaWolfColors.wolfGreen,
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _EmployeeKpiTab(
              reviewer: reviewer,
              monthKey: _monthKey,
              kpiService: _kpiService,
            ),
            _TemplatesTab(kpiService: _kpiService),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAssignSheet(context, reviewer),
          backgroundColor: ZaWolfColors.primaryCyan,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.flag),
          label: const Text('تعيين KPI'),
        ),
      ),
    );
  }

  void _showTemplateSheet(BuildContext context, UserModel reviewer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) =>
          _CreateTemplateSheet(reviewer: reviewer, kpiService: _kpiService),
    );
  }

  void _showAssignSheet(BuildContext context, UserModel reviewer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _AssignKpiSheet(
        reviewer: reviewer,
        kpiService: _kpiService,
        monthKey: _monthKey,
      ),
    );
  }
}

class _EmployeeKpiTab extends StatelessWidget {
  final UserModel reviewer;
  final String monthKey;
  final KpiService kpiService;

  const _EmployeeKpiTab({
    required this.reviewer,
    required this.monthKey,
    required this.kpiService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<EmployeeKpiModel>>(
      stream: kpiService.watchManagedKpis(reviewer, monthKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return Center(
            child: Text(
              'لا توجد أهداف KPI لهذا الشهر',
              style: theme.textTheme.titleMedium,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: records
              .map(
                (kpi) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _ProgressBadge(value: kpi.overallProgress),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  kpi.employeeName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$monthKey · ${kpi.department}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...kpi.metrics.asMap().entries.map((entry) {
                          final index = entry.key;
                          final metric = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              metric.name,
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              '${metric.actual.toStringAsFixed(0)} / ${metric.target.toStringAsFixed(0)} ${metric.unit}',
                              textAlign: TextAlign.right,
                            ),
                            leading: IconButton(
                              tooltip: 'تحديث',
                              icon: const Icon(
                                Icons.edit,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              onPressed: () => _showProgressSheet(
                                context,
                                kpi,
                                index,
                                metric,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _showProgressSheet(
    BuildContext context,
    EmployeeKpiModel kpi,
    int metricIndex,
    EmployeeKpiMetric metric,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _UpdateProgressSheet(
        reviewer: reviewer,
        employeeKpiId: kpi.employeeKpiId,
        metricIndex: metricIndex,
        metric: metric,
        kpiService: kpiService,
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  final KpiService kpiService;

  const _TemplatesTab({required this.kpiService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<KpiTemplateModel>>(
      stream: kpiService.watchTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final templates = snapshot.data ?? [];
        if (templates.isEmpty) {
          return Center(
            child: Text(
              'ابدأ بإنشاء قالب KPI',
              style: theme.textTheme.titleMedium,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: templates
              .map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          template.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        Text(
                          template.department,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 10),
                        ...template.metrics.map(
                          (metric) => Text(
                            '${metric.name}: ${metric.target.toStringAsFixed(0)} ${metric.unit} · وزن ${metric.weight.toStringAsFixed(1)}',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CreateTemplateSheet extends StatefulWidget {
  final UserModel reviewer;
  final KpiService kpiService;

  const _CreateTemplateSheet({
    required this.reviewer,
    required this.kpiService,
  });

  @override
  State<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends State<_CreateTemplateSheet> {
  final _title = TextEditingController();
  final _department = TextEditingController();
  final _metricName = TextEditingController();
  final _unit = TextEditingController(text: 'عدد');
  final _target = TextEditingController();
  final _weight = TextEditingController(text: '1');
  final List<KpiMetricTemplate> _metrics = [];

  @override
  void dispose() {
    _title.dispose();
    _department.dispose();
    _metricName.dispose();
    _unit.dispose();
    _target.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'قالب KPI جديد',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            WolfInputField(controller: _title, labelText: 'اسم القالب'),
            const SizedBox(height: 10),
            WolfInputField(controller: _department, labelText: 'القسم'),
            const SizedBox(height: 16),
            Text(
              'المؤشرات',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            ..._metrics.map(
              (metric) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(metric.name, textAlign: TextAlign.right),
                subtitle: Text(
                  '${metric.target.toStringAsFixed(0)} ${metric.unit} · وزن ${metric.weight}',
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            WolfInputField(controller: _metricName, labelText: 'اسم المؤشر'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: WolfInputField(controller: _unit, labelText: 'الوحدة'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WolfInputField(
                    controller: _target,
                    labelText: 'الهدف',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WolfInputField(
                    controller: _weight,
                    labelText: 'الوزن',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _addMetric,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مؤشر'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ القالب'),
            ),
          ],
        ),
      ),
    );
  }

  void _addMetric() {
    final target = double.tryParse(_target.text.trim()) ?? 0;
    final weight = double.tryParse(_weight.text.trim()) ?? 1;
    if (_metricName.text.trim().length < 2 || target <= 0) return;
    setState(() {
      _metrics.add(
        KpiMetricTemplate(
          name: _metricName.text.trim(),
          unit: _unit.text.trim().isEmpty ? 'عدد' : _unit.text.trim(),
          target: target,
          weight: weight <= 0 ? 1 : weight,
        ),
      );
      _metricName.clear();
      _target.clear();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3 ||
        _department.text.trim().isEmpty ||
        _metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أكمل اسم القالب والقسم ومؤشر واحد على الأقل.'),
        ),
      );
      return;
    }
    await widget.kpiService.createTemplate(
      creator: widget.reviewer,
      title: _title.text,
      department: _department.text,
      metrics: _metrics,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _AssignKpiSheet extends StatefulWidget {
  final UserModel reviewer;
  final KpiService kpiService;
  final String monthKey;

  const _AssignKpiSheet({
    required this.reviewer,
    required this.kpiService,
    required this.monthKey,
  });

  @override
  State<_AssignKpiSheet> createState() => _AssignKpiSheetState();
}

class _AssignKpiSheetState extends State<_AssignKpiSheet> {
  late final Future<List<UserModel>> _employeesFuture;
  UserModel? _employee;
  KpiTemplateModel? _template;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.kpiService.loadAssignableEmployees(
      widget.reviewer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تعيين KPI لشهر ${widget.monthKey}',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<UserModel>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                final employees = snapshot.data ?? [];
                return DropdownButtonFormField<UserModel>(
                  initialValue: _employee,
                  decoration: const InputDecoration(labelText: 'الموظف'),
                  items: employees
                      .map(
                        (user) => DropdownMenuItem(
                          value: user,
                          child: Text(
                            '${user.displayName} · ${user.department}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _employee = value),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<KpiTemplateModel>>(
              stream: widget.kpiService.watchTemplates(),
              builder: (context, snapshot) {
                final templates = snapshot.data ?? [];
                return DropdownButtonFormField<KpiTemplateModel>(
                  initialValue: _template,
                  decoration: const InputDecoration(labelText: 'قالب KPI'),
                  items: templates
                      .map(
                        (template) => DropdownMenuItem(
                          value: template,
                          child: Text(
                            '${template.title} · ${template.department}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _template = value),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _assign,
              icon: const Icon(Icons.flag),
              label: const Text('تعيين الأهداف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign() async {
    final employee = _employee;
    final template = _template;
    if (employee == null || template == null) return;
    await widget.kpiService.assignMonthlyKpi(
      creator: widget.reviewer,
      employee: employee,
      template: template,
      monthKey: widget.monthKey,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _UpdateProgressSheet extends StatefulWidget {
  final UserModel reviewer;
  final String employeeKpiId;
  final int metricIndex;
  final EmployeeKpiMetric metric;
  final KpiService kpiService;

  const _UpdateProgressSheet({
    required this.reviewer,
    required this.employeeKpiId,
    required this.metricIndex,
    required this.metric,
    required this.kpiService,
  });

  @override
  State<_UpdateProgressSheet> createState() => _UpdateProgressSheetState();
}

class _UpdateProgressSheetState extends State<_UpdateProgressSheet> {
  late final TextEditingController _actual;

  @override
  void initState() {
    super.initState();
    _actual = TextEditingController(
      text: widget.metric.actual.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _actual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.metric.name, textAlign: TextAlign.right),
          const SizedBox(height: 12),
          WolfInputField(
            controller: _actual,
            labelText: 'القيمة الحالية',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await widget.kpiService.updateMetricProgress(
                employeeKpiId: widget.employeeKpiId,
                reviewer: widget.reviewer,
                metricIndex: widget.metricIndex,
                actual: double.tryParse(_actual.text.trim()) ?? 0,
              );
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final double value;

  const _ProgressBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.10),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '${value.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: ZaWolfColors.primaryCyan,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
