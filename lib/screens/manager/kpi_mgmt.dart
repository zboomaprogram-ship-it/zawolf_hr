import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/sales_kpi_details_panel.dart';
import '../../components/dynamic_dropdown.dart';
import '../../components/wolf_input_field.dart';
import '../../models/kpi_model.dart';
import '../../models/employee_role.dart';
import '../../models/location_model.dart';
import '../../models/sales_kpi_summary.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/department_service.dart';
import '../../services/kpi_service.dart';
import '../../services/location_service.dart';
import '../../services/sales_kpi_integration_service.dart';
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة KPI', style: theme.textTheme.headlineMedium),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'لوحة الفريق'),
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
            _ProviderDashboardTab(
              reviewer: reviewer,
              monthKey: _monthKey,
              kpiService: _kpiService,
            ),
            _EmployeeKpiTab(
              reviewer: reviewer,
              monthKey: _monthKey,
              kpiService: _kpiService,
            ),
            _TemplatesTab(reviewer: reviewer, kpiService: _kpiService),
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

class _ProviderDashboardTab extends StatefulWidget {
  final UserModel reviewer;
  final String monthKey;
  final KpiService kpiService;

  const _ProviderDashboardTab({
    required this.reviewer,
    required this.monthKey,
    required this.kpiService,
  });

  @override
  State<_ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<_ProviderDashboardTab> {
  String _department = 'all';
  final SalesKpiIntegrationService _salesIntegration =
      SalesKpiIntegrationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmployeeKpiModel>>(
      stream: widget.kpiService.watchManagedKpis(
        widget.reviewer,
        widget.monthKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final providerRecords = (snapshot.data ?? [])
            .where((record) => record.providerDetails.isNotEmpty)
            .toList();
        if (!EmployeeRole.isHr(widget.reviewer.role)) {
          return _buildDashboard(context, providerRecords, null);
        }
        return StreamBuilder<SalesKpiSummary?>(
          stream: _salesIntegration.watchCurrentSummary(),
          builder: (context, summarySnapshot) {
            if (summarySnapshot.connectionState == ConnectionState.waiting &&
                !summarySnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ZaWolfColors.primaryCyan,
                ),
              );
            }
            return _buildDashboard(
              context,
              providerRecords,
              summarySnapshot.data,
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<EmployeeKpiModel> providerRecords,
    SalesKpiSummary? summary,
  ) {
    // Unmapped API identities are integration diagnostics, not employees.
    // Excluding them keeps team counts, averages and lists accurate.
    final external = (summary?.agents ?? const <SalesKpiAgentSummary>[])
        .where((agent) => agent.isMapped)
        .toList();
    final visibleExternal = _department == 'all'
        ? external
        : external.where((agent) => agent.kind == _department).toList();
    final visibleRecords = _department == 'all'
        ? providerRecords
        : providerRecords
              .where((record) => record.providerDepartment == _department)
              .toList();
    final useExternal = external.isNotEmpty;
    final salesCount = useExternal
        ? summary!.availableSalesAgents
        : providerRecords.where((r) => r.providerDepartment == 'sales').length;
    final teleCount = useExternal
        ? summary!.availableTeleSalesAgents
        : providerRecords
              .where((r) => r.providerDepartment == 'tele_sales')
              .length;
    final totalCount = useExternal ? external.length : providerRecords.length;
    final average = useExternal
        ? (_department == 'sales'
              ? summary!.salesAverageKpi
              : _department == 'tele_sales'
              ? summary!.teleSalesAverageKpi
              : external.isEmpty
              ? 0.0
              : external.fold<double>(0, (sum, a) => sum + a.finalKpi) /
                    external.length)
        : visibleRecords.isEmpty
        ? 0.0
        : visibleRecords.fold<double>(
                0,
                (total, record) => total + record.overallProgress,
              ) /
              visibleRecords.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (summary != null &&
            summary.apiAgentCount > 0 &&
            !summary.apiIdentityMappingReady) ...[
          _KpiIdentityWarning(summary: summary),
          const SizedBox(height: 14),
        ],
        WolfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مؤشرات الفريق المتصلة',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all',
                    label: Text('الكل ($totalCount)'),
                    icon: const Icon(Icons.dashboard_outlined),
                  ),
                  ButtonSegment(
                    value: 'sales',
                    label: Text('المبيعات ($salesCount)'),
                    icon: const Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: 'tele_sales',
                    label: Text('الهاتف ($teleCount)'),
                    icon: const Icon(Icons.support_agent_outlined),
                  ),
                ],
                selected: {_department},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _department = value.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _DashboardStat(
                    label: 'متوسط KPI',
                    value: '${average.toStringAsFixed(1)}%',
                    color: ZaWolfColors.perfGold,
                  ),
                  const SizedBox(width: 10),
                  _DashboardStat(
                    label: 'الموظفون',
                    value:
                        '${useExternal ? visibleExternal.length : visibleRecords.length}',
                    color: ZaWolfColors.primaryCyan,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (useExternal && visibleExternal.isNotEmpty)
          ...visibleExternal.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExternalAgentCard(agent: agent),
            ),
          )
        else if (visibleRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Text(
              totalCount == 0
                  ? EmployeeRole.isHr(widget.reviewer.role)
                        ? 'لا توجد بيانات KPI متصلة في هذه الدورة'
                        : 'لا توجد مؤشرات مرتبطة بحسابات فريقك. يجب أن يرسل مصدر KPI كود الموظف الثابت idEmp لعرض بيانات كل موظف بأمان.'
                  : 'لا توجد بيانات في هذا القسم',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
        else
          ...visibleRecords.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: ZaWolfColors.background,
                  builder: (context) => DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, controller) => ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [SalesKpiDetailsPanel(kpi: record)],
                    ),
                  ),
                ),
                child: SalesKpiDetailsPanel(kpi: record, compact: true),
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiIdentityWarning extends StatelessWidget {
  final SalesKpiSummary summary;

  const _KpiIdentityWarning({required this.summary});

  @override
  Widget build(BuildContext context) {
    final missing = summary.apiMissingAgentIdCount;
    final total = summary.apiAgentCount;
    return Semantics(
      label: 'تحذير ربط بيانات مؤشرات الأداء بالموظفين',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZaWolfColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ZaWolfColors.warning.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.link_off_outlined, color: ZaWolfColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'بيانات الأقسام متاحة، وربط الموظفين غير مكتمل',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: ZaWolfColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مصدر KPI أعاد $missing من $total سجل بدون كود موظف ثابت. لن يربط النظام الأسماء تلقائياً لتجنب إسناد نتائج إلى موظف غير صحيح. يجب أن يعيد المصدر idEmp صالحاً لكل سجل.',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _ExternalAgentCard extends StatelessWidget {
  final SalesKpiAgentSummary agent;

  const _ExternalAgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final ratio = agent.target <= 0 ? 0.0 : agent.actual / agent.target;
    final color = agent.isMapped ? ZaWolfColors.success : ZaWolfColors.warning;
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${agent.finalKpi.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ZaWolfColors.perfGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 3,
                child: Text(
                  agent.mappedEmployeeName.isNotEmpty
                      ? agent.mappedEmployeeName
                      : agent.name,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                agent.kind == 'sales'
                    ? Icons.payments_outlined
                    : Icons.support_agent,
                color: ZaWolfColors.primaryCyan,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 8,
            color: color,
            backgroundColor: ZaWolfColors.surface03,
          ),
          const SizedBox(height: 8),
          Text(
            '${agent.actual.toStringAsFixed(0)} / ${agent.target.toStringAsFixed(0)} · '
            '${agent.isMapped ? 'مرتبط: ${agent.mappedEmployeeId}' : 'غير مرتبط بحساب موظف'} · ${agent.key}',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface02,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeKpiTab extends StatefulWidget {
  final UserModel reviewer;
  final String monthKey;
  final KpiService kpiService;

  const _EmployeeKpiTab({
    required this.reviewer,
    required this.monthKey,
    required this.kpiService,
  });

  @override
  State<_EmployeeKpiTab> createState() => _EmployeeKpiTabState();
}

class _EmployeeKpiTabState extends State<_EmployeeKpiTab> {
  String _searchQuery = '';
  String _departmentFilter = 'all';
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<EmployeeKpiModel>>(
      stream: widget.kpiService.watchManagedKpis(widget.reviewer, widget.monthKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        var records = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          records = records.where((kpi) => 
            kpi.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
            kpi.department.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }
        if (_statusFilter != null) {
          records = records.where((kpi) => kpi.status == _statusFilter).toList();
        }
        if (_departmentFilter != 'all') {
          records = records.where((kpi) => kpi.department == _departmentFilter).toList();
        }

        final departments = {'all': 'الكل'};
        if (snapshot.hasData) {
          for (final record in snapshot.data!) {
            if (record.department.isNotEmpty) {
              departments[record.department] = record.department;
            }
          }
        }

        if (records.isEmpty && (snapshot.data?.isEmpty ?? true)) {
          return Center(
            child: Text(
              'لا توجد أهداف KPI لهذا الشهر',
              style: theme.textTheme.titleMedium,
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'بحث بالاسم أو القسم',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('الكل')),
                        DropdownMenuItem(value: KpiStatus.active, child: Text('نشط')),
                        DropdownMenuItem(value: KpiStatus.finalized, child: Text('معتمد')),
                      ],
                      onChanged: (value) => setState(() => _statusFilter = value),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: departments.entries.map((entry) {
                  final isSelected = _departmentFilter == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      selectedColor: ZaWolfColors.primaryCyan.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? ZaWolfColors.primaryCyan : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _departmentFilter = entry.key);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد نتائج',
                        style: theme.textTheme.titleMedium,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                  '${widget.monthKey} · ${kpi.department}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                _StatusChip(status: kpi.status),
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
                              '${metric.actual.toStringAsFixed(0)} / ${metric.target.toStringAsFixed(0)} ${metric.unit}\n'
                              '${KpiMetricDirection.arabicLabel(metric.direction)} · وزن ${metric.weight.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                            ),
                            leading: IconButton(
                              tooltip: 'تحديث',
                              icon: const Icon(
                                Icons.edit,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              onPressed: kpi.status == KpiStatus.finalized
                                  ? null
                                  : () => _showProgressSheet(
                                      context,
                                      kpi,
                                      index,
                                      metric,
                                    ),
                            ),
                          );
                        }),
                        const Divider(),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'حذف KPI من الموظف',
                              onPressed: () => _deleteKpi(context, kpi),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: ZaWolfColors.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: kpi.status == KpiStatus.active
                                  ? FilledButton.icon(
                                      onPressed: () => _finalize(context, kpi),
                                      icon: const Icon(Icons.lock_outline),
                                      label: const Text(
                                        'اعتماد وإغلاق النتيجة',
                                      ),
                                    )
                                  : EmployeeRole.isHr(widget.reviewer.role)
                                  ? OutlinedButton.icon(
                                      onPressed: () => _reopen(context, kpi),
                                      icon: const Icon(
                                        Icons.lock_open_outlined,
                                      ),
                                      label: const Text('إعادة فتح النتيجة'),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
                    ),
            ),
          ],
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
        reviewer: widget.reviewer,
        employeeKpiId: kpi.employeeKpiId,
        metricIndex: metricIndex,
        metric: metric,
        kpiService: widget.kpiService,
      ),
    );
  }

  Future<void> _finalize(BuildContext context, EmployeeKpiModel kpi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد النتيجة'),
        content: Text(
          'سيتم إغلاق نتيجة ${kpi.employeeName} عند ${kpi.overallProgress.toStringAsFixed(1)}%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.kpiService.finalizeKpi(kpi: kpi, reviewer: widget.reviewer);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _reopen(BuildContext context, EmployeeKpiModel kpi) async {
    try {
      await widget.kpiService.reopenKpi(kpi: kpi, reviewer: widget.reviewer);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _deleteKpi(BuildContext context, EmployeeKpiModel kpi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف KPI المعين'),
        content: Text(
          'سيتم حذف أهداف ${kpi.employeeName} لدورة ${kpi.monthKey} نهائياً. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZaWolfColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.kpiService.deleteEmployeeKpi(kpi: kpi, actor: widget.reviewer);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _TemplatesTab extends StatelessWidget {
  final UserModel reviewer;
  final KpiService kpiService;

  const _TemplatesTab({required this.reviewer, required this.kpiService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<KpiTemplateModel>>(
      stream: kpiService.watchTemplates(includeInactive: true),
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
                  child: _TemplateCard(
                    template: template,
                    reviewer: reviewer,
                    kpiService: kpiService,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final KpiTemplateModel template;
  final UserModel reviewer;
  final KpiService kpiService;

  const _TemplateCard({
    required this.template,
    required this.reviewer,
    required this.kpiService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit =
        EmployeeRole.isHr(reviewer.role) || template.createdBy == reviewer.uid;
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            template.title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
          ),
          Text(
            template.department,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
          if (template.companyName.isNotEmpty)
            Text(
              'الشركة: ${template.companyName}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          const SizedBox(height: 10),
          ...template.metrics.map(
            (metric) => Text(
              '${metric.name}: ${metric.target.toStringAsFixed(0)} ${metric.unit} · ${KpiMetricDirection.arabicLabel(metric.direction)} · وزن ${metric.weight.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          const Divider(),
          Row(
            children: [
              Switch(
                value: template.isActive,
                onChanged: !canEdit
                    ? null
                    : (value) async {
                        try {
                          await kpiService.setTemplateActive(
                            template: template,
                            editor: reviewer,
                            isActive: value,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            _showError(context, error);
                          }
                        }
                      },
              ),
              Text(template.isActive ? 'نشط' : 'مؤرشف'),
              const Spacer(),
              IconButton(
                tooltip: 'حذف القالب',
                onPressed: !canEdit
                    ? null
                    : () => _confirmDeleteTemplate(context),
                icon: const Icon(
                  Icons.delete_outline,
                  color: ZaWolfColors.error,
                ),
              ),
              IconButton(
                tooltip: 'تعديل القالب',
                onPressed: !canEdit
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: ZaWolfColors.surface01,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        builder: (_) => _CreateTemplateSheet(
                          reviewer: reviewer,
                          kpiService: kpiService,
                          existingTemplate: template,
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTemplate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف قالب KPI'),
        content: const Text(
          'سيتم حذف القالب فقط. سجلات KPI التي سبق تعيينها للموظفين ستبقى كما هي حتى تحذفها بشكل منفصل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZaWolfColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف القالب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await kpiService.deleteTemplate(template: template, actor: reviewer);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _CreateTemplateSheet extends StatefulWidget {
  final UserModel reviewer;
  final KpiService kpiService;
  final KpiTemplateModel? existingTemplate;

  const _CreateTemplateSheet({
    required this.reviewer,
    required this.kpiService,
    this.existingTemplate,
  });

  @override
  State<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends State<_CreateTemplateSheet> {
  final _title = TextEditingController();
  final _metricName = TextEditingController();
  final _unit = TextEditingController(text: 'عدد');
  final _target = TextEditingController();
  final _weight = TextEditingController(text: '100');
  final List<KpiMetricTemplate> _metrics = [];
  String _direction = KpiMetricDirection.higherIsBetter;
  String? _department;
  String? _companyLocationId;
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTemplate;
    if (existing != null) {
      _title.text = existing.title;
      _department = existing.department;
      _companyLocationId = existing.companyLocationId.isEmpty
          ? null
          : existing.companyLocationId;
      _companyName = existing.companyName;
      _metrics.addAll(existing.metrics);
    }
  }

  @override
  void dispose() {
    _title.dispose();
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
              widget.existingTemplate == null
                  ? 'قالب KPI جديد'
                  : 'تعديل قالب KPI',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            WolfInputField(controller: _title, labelText: 'اسم القالب'),
            const SizedBox(height: 10),
            DynamicDropdown(
              label: 'القسم / الإدارة',
              actionLabel: 'قسم جديد',
              dialogTitle: 'إضافة قسم جديد لكل النظام',
              initialValue: _department,
              onChanged: (value) => _department = value,
              stream: DepartmentService.instance.watchDepartments(),
              onAdd: DepartmentService.instance.addDepartment,
              onInit: DepartmentService.instance.bootstrapDepartmentsIfNeeded,
              canAdd: EmployeeRole.isHr(widget.reviewer.role),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<LocationModel>>(
              stream: LocationService().watchActiveLocations(),
              builder: (context, snapshot) {
                final locations = snapshot.data ?? const <LocationModel>[];
                final knownIds = locations
                    .map((location) => location.locationId)
                    .toSet();
                return DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${_companyLocationId ?? 'all'}-${knownIds.length}',
                  ),
                  initialValue:
                      _companyLocationId == null ||
                          knownIds.contains(_companyLocationId)
                      ? _companyLocationId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'الشركة (اختياري)',
                    helperText: 'القائمة مأخوذة من مواقع وفروع الشركة',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('كل الشركات / غير محدد'),
                    ),
                    ...locations.map(
                      (location) => DropdownMenuItem<String>(
                        value: location.locationId,
                        child: Text(location.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    final selected = value == null
                        ? null
                        : locations
                              .where((location) => location.locationId == value)
                              .firstOrNull;
                    setState(() {
                      _companyLocationId = selected?.locationId;
                      _companyName = selected?.name ?? '';
                    });
                  },
                );
              },
            ),
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
                  '${metric.target.toStringAsFixed(0)} ${metric.unit} · ${KpiMetricDirection.arabicLabel(metric.direction)} · وزن ${metric.weight.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                ),
                leading: IconButton(
                  tooltip: 'حذف المؤشر',
                  onPressed: () => setState(() => _metrics.remove(metric)),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: ZaWolfColors.error,
                  ),
                ),
              ),
            ),
            Text(
              'إجمالي الأوزان: ${_totalWeight.toStringAsFixed(0)}% / 100%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: (_totalWeight - 100).abs() < 0.01
                    ? ZaWolfColors.success
                    : ZaWolfColors.warning,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _direction,
              decoration: const InputDecoration(labelText: 'طريقة القياس'),
              items: KpiMetricDirection.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(KpiMetricDirection.arabicLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _direction = value ?? KpiMetricDirection.higherIsBetter;
              }),
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
              label: Text(
                widget.existingTemplate == null
                    ? 'حفظ القالب'
                    : 'حفظ التعديلات',
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _totalWeight =>
      _metrics.fold<double>(0, (total, metric) => total + metric.weight);

  void _addMetric() {
    final target = double.tryParse(_target.text.trim()) ?? 0;
    final weight = double.tryParse(_weight.text.trim()) ?? 0;
    if (_metricName.text.trim().length < 2 || target <= 0 || weight <= 0) {
      _showError(context, 'أدخل اسم المؤشر والهدف والوزن بشكل صحيح.');
      return;
    }
    setState(() {
      _metrics.add(
        KpiMetricTemplate(
          name: _metricName.text.trim(),
          unit: _unit.text.trim().isEmpty ? 'عدد' : _unit.text.trim(),
          target: target,
          weight: weight,
          direction: _direction,
        ),
      );
      _metricName.clear();
      _target.clear();
      final remaining = (100 - _totalWeight).clamp(0, 100);
      _weight.text = remaining == 0 ? '' : remaining.toStringAsFixed(0);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3 ||
        (_department?.trim().isEmpty ?? true) ||
        _metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أكمل اسم القالب والقسم ومؤشر واحد على الأقل.'),
        ),
      );
      return;
    }
    try {
      final existing = widget.existingTemplate;
      if (existing == null) {
        await widget.kpiService.createTemplate(
          creator: widget.reviewer,
          title: _title.text,
          department: _department!,
          companyLocationId: _companyLocationId ?? '',
          companyName: _companyName,
          metrics: _metrics,
        );
      } else {
        await widget.kpiService.updateTemplate(
          template: existing,
          editor: widget.reviewer,
          title: _title.text,
          department: _department!,
          companyLocationId: _companyLocationId ?? '',
          companyName: _companyName,
          metrics: _metrics,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
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
  final Set<String> _selectedEmployeeIds = {};
  KpiTemplateModel? _template;
  bool _saving = false;

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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('${_selectedEmployeeIds.length} محدد'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            if (_selectedEmployeeIds.length ==
                                employees.length) {
                              _selectedEmployeeIds.clear();
                            } else {
                              _selectedEmployeeIds
                                ..clear()
                                ..addAll(employees.map((user) => user.uid));
                            }
                          }),
                          icon: const Icon(Icons.checklist_rtl),
                          label: Text(
                            _selectedEmployeeIds.length == employees.length
                                ? 'إلغاء تحديد الكل'
                                : 'تحديد الكل',
                          ),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          return CheckboxListTile(
                            value: _selectedEmployeeIds.contains(employee.uid),
                            title: Text(employee.displayName),
                            subtitle: Text(employee.department),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (selected) => setState(() {
                              if (selected == true) {
                                _selectedEmployeeIds.add(employee.uid);
                              } else {
                                _selectedEmployeeIds.remove(employee.uid);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
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
                            '${template.title} · ${template.department}${template.companyName.isEmpty ? '' : ' · ${template.companyName}'}',
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
              onPressed: _saving ? null : _assign,
              icon: const Icon(Icons.flag),
              label: Text(_saving ? 'جاري التعيين...' : 'تعيين الأهداف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign() async {
    final template = _template;
    if (_selectedEmployeeIds.isEmpty || template == null) {
      _showError(context, 'اختر موظفاً واحداً على الأقل وقالب KPI.');
      return;
    }
    setState(() => _saving = true);
    try {
      final allEmployees = await _employeesFuture;
      final selected = allEmployees
          .where((user) => _selectedEmployeeIds.contains(user.uid))
          .toList();
      final result = await widget.kpiService.assignMonthlyKpiToEmployees(
        creator: widget.reviewer,
        employees: selected,
        template: template,
        monthKey: widget.monthKey,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'تم التعيين لـ ${result.assigned} موظف، وتم تخطي ${result.skipped} سبق تعيينهم.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
  late final TextEditingController _evidenceUrl;
  late final TextEditingController _managerComment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _actual = TextEditingController(
      text: widget.metric.actual.toStringAsFixed(0),
    );
    _evidenceUrl = TextEditingController(text: widget.metric.evidenceUrl);
    _managerComment = TextEditingController(text: widget.metric.managerComment);
  }

  @override
  void dispose() {
    _actual.dispose();
    _evidenceUrl.dispose();
    _managerComment.dispose();
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
          Text(
            '${KpiMetricDirection.arabicLabel(widget.metric.direction)} · الهدف ${widget.metric.target.toStringAsFixed(0)} ${widget.metric.unit}',
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          WolfInputField(
            controller: _actual,
            labelText: 'القيمة الحالية',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          WolfInputField(
            controller: _managerComment,
            labelText: 'ملاحظة المدير (اختياري)',
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          WolfInputField(
            controller: _evidenceUrl,
            labelText: 'رابط الإثبات (اختياري)',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.kpiService.updateMetricProgress(
                        employeeKpiId: widget.employeeKpiId,
                        reviewer: widget.reviewer,
                        metricIndex: widget.metricIndex,
                        actual: double.tryParse(_actual.text.trim()) ?? 0,
                        evidenceUrl: _evidenceUrl.text,
                        managerComment: _managerComment.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (error) {
                      if (context.mounted) _showError(context, error);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            icon: const Icon(Icons.save),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final finalized = status == KpiStatus.finalized;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (finalized ? ZaWolfColors.success : ZaWolfColors.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        finalized ? 'معتمد' : 'قيد المتابعة',
        style: TextStyle(
          color: finalized ? ZaWolfColors.success : ZaWolfColors.warning,
          fontSize: 12,
        ),
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
