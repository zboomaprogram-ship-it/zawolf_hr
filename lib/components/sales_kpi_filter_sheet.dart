import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/sales_kpi_summary.dart';
import '../theme/theme.dart';

Future<SalesKpiFilters?> showSalesKpiFilterSheet(
  BuildContext context, {
  required SalesKpiFilters initial,
  required SalesKpiFilterOptions options,
}) {
  return showModalBottomSheet<SalesKpiFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => _SalesKpiFilterSheet(initial: initial, options: options),
  );
}

class _SalesKpiFilterSheet extends StatefulWidget {
  final SalesKpiFilters initial;
  final SalesKpiFilterOptions options;

  const _SalesKpiFilterSheet({required this.initial, required this.options});

  @override
  State<_SalesKpiFilterSheet> createState() => _SalesKpiFilterSheetState();
}

class _SalesKpiFilterSheetState extends State<_SalesKpiFilterSheet> {
  late DateTimeRange _period;
  late String _company;
  late String _entryChannel;
  late Set<String> _sales;
  late Set<String> _teleSales;
  late String _idEmp;
  late bool _cumulative;
  late final TextEditingController _salesTargetController;
  late final TextEditingController _teleTargetController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fallbackStart = DateTime(now.year, now.month, 1);
    final fallbackEnd = DateTime(now.year, now.month + 1, 0);
    final parsedStart = DateTime.tryParse(widget.initial.startDate);
    final parsedEnd = DateTime.tryParse(widget.initial.endDate);
    _period = DateTimeRange(
      start: parsedStart ?? fallbackStart,
      end: parsedEnd ?? fallbackEnd,
    );
    _company = _optionOrAll(widget.initial.company, widget.options.companies);
    _entryChannel = _optionOrAll(
      widget.initial.entryChannel,
      widget.options.entryChannels,
    );
    _sales = widget.initial.sales.toSet();
    _teleSales = widget.initial.teleSales.toSet();
    _idEmp = widget.initial.idEmp;
    _cumulative = widget.initial.cumulative;
    _salesTargetController = TextEditingController(
      text: widget.initial.salesTarget.toStringAsFixed(0),
    );
    _teleTargetController = TextEditingController(
      text: widget.initial.teleTarget.toStringAsFixed(0),
    );
  }

  String _optionOrAll(String value, List<String> options) {
    if (value == 'ALL' || options.contains(value)) return value;
    return 'ALL';
  }

  @override
  void dispose() {
    _salesTargetController.dispose();
    _teleTargetController.dispose();
    super.dispose();
  }

  List<SalesKpiAgentOption> get _linkedEmployees {
    final byId = <String, SalesKpiAgentOption>{};
    for (final agent in [
      ...widget.options.linkedSalesAgents,
      ...widget.options.linkedTeleSalesAgents,
    ]) {
      byId.putIfAbsent(agent.id.trim(), () => agent);
    }
    final result = byId.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      children: [
                        _Section(
                          title: 'الفترة الزمنية',
                          icon: Icons.date_range_outlined,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: _pickPeriod,
                            child: _FieldSurface(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    color: ZaWolfColors.primaryCyan,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_date(_period.start)} - ${_date(_period.end)}',
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _Section(
                          title: 'مصدر البيانات',
                          icon: Icons.tune_outlined,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 560;
                              final fields = [
                                _dropdown(
                                  label: 'الشركة',
                                  value: _company,
                                  values: widget.options.companies,
                                  onChanged: (value) =>
                                      setState(() => _company = value),
                                ),
                                _dropdown(
                                  label: 'قناة الدخول',
                                  value: _entryChannel,
                                  values: widget.options.entryChannels,
                                  onChanged: (value) =>
                                      setState(() => _entryChannel = value),
                                ),
                              ];
                              return wide
                                  ? Row(
                                      children: [
                                        Expanded(child: fields.first),
                                        const SizedBox(width: 12),
                                        Expanded(child: fields.last),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        fields.first,
                                        const SizedBox(height: 12),
                                        fields.last,
                                      ],
                                    );
                            },
                          ),
                        ),
                        _Section(
                          title: 'الموظف المرتبط',
                          icon: Icons.badge_outlined,
                          subtitle: 'تظهر الحسابات المرتبطة بكود موظف فقط',
                          child: DropdownButtonFormField<String>(
                            initialValue: _linkedEmployees.any(
                              (agent) => agent.id == _idEmp,
                            )
                                ? _idEmp
                                : '',
                            decoration: _decoration('كل الموظفين المرتبطين'),
                            dropdownColor: ZaWolfColors.surface02,
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('كل الموظفين المرتبطين'),
                              ),
                              ..._linkedEmployees.map(
                                (agent) => DropdownMenuItem(
                                  value: agent.id,
                                  child: Text('${agent.name} (${agent.id})'),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _idEmp = value ?? ''),
                          ),
                        ),
                        _AgentSelector(
                          title: 'موظفو المبيعات',
                          agents: widget.options.linkedSalesAgents,
                          selected: _sales,
                          onChanged: (value) => setState(() => _sales = value),
                        ),
                        _AgentSelector(
                          title: 'موظفو المبيعات الهاتفية',
                          agents: widget.options.linkedTeleSalesAgents,
                          selected: _teleSales,
                          onChanged: (value) =>
                              setState(() => _teleSales = value),
                        ),
                        _Section(
                          title: 'الأهداف',
                          icon: Icons.track_changes_outlined,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _teleTargetController,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  decoration: _decoration('هدف الهاتف'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _salesTargetController,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  decoration: _decoration('هدف المبيعات SAR'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: _cumulative,
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: ZaWolfColors.primaryCyan,
                          title: const Text('تجميع النتائج المتكررة'),
                          subtitle: const Text(
                            'يجمع أكثر من صف للموظف نفسه باستخدام idEmp',
                          ),
                          onChanged: (value) =>
                              setState(() => _cumulative = value),
                        ),
                      ],
                    ),
                  ),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'فلاتر مؤشرات التابعين',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${_linkedEmployees.length} موظف مرتبط متاح',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Icon(Icons.filter_alt_outlined, color: ZaWolfColors.primaryCyan),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: ZaWolfColors.surface01,
        border: Border(top: BorderSide(color: ZaWolfColors.surface03)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة ضبط'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check),
              label: const Text('حفظ وتطبيق'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _decoration(label),
      dropdownColor: ZaWolfColors.surface02,
      items: [
        const DropdownMenuItem(value: 'ALL', child: Text('الكل')),
        ...values.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: (item) => onChanged(item ?? 'ALL'),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ZaWolfColors.surface02,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      );

  Future<void> _pickPeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _period,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'اختر فترة مؤشرات الأداء',
      saveText: 'تطبيق',
    );
    if (selected != null && mounted) setState(() => _period = selected);
  }

  void _reset() {
    final now = DateTime.now();
    setState(() {
      _period = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      _company = 'ALL';
      _entryChannel = 'ALL';
      _sales = {};
      _teleSales = {};
      _idEmp = '';
      _cumulative = true;
      _salesTargetController.text = '20000';
      _teleTargetController.text = '50';
    });
  }

  void _apply() {
    final salesTarget = double.tryParse(_salesTargetController.text.trim());
    final teleTarget = double.tryParse(_teleTargetController.text.trim());
    if (salesTarget == null || salesTarget <= 0 || teleTarget == null || teleTarget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل أهدافاً صحيحة أكبر من صفر.')),
      );
      return;
    }
    Navigator.pop(
      context,
      SalesKpiFilters(
        startDate: _date(_period.start),
        endDate: _date(_period.end),
        company: _company,
        sales: _sales.toList()..sort(),
        teleSales: _teleSales.toList()..sort(),
        entryChannel: _entryChannel,
        salesTarget: salesTarget,
        teleTarget: teleTarget,
        idEmp: _idEmp,
        cumulative: _cumulative,
      ),
    );
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}

class _AgentSelector extends StatelessWidget {
  final String title;
  final List<SalesKpiAgentOption> agents;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _AgentSelector({
    required this.title,
    required this.agents,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      icon: Icons.groups_2_outlined,
      subtitle: selected.isEmpty ? 'الكل' : '${selected.length} محدد',
      child: agents.isEmpty
          ? const Text('لا يوجد موظفون مرتبطون في هذا القسم.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: agents.map((agent) {
                final active = selected.contains(agent.code);
                return FilterChip(
                  selected: active,
                  label: Text('${agent.name} (${agent.code})'),
                  avatar: const Icon(Icons.person_outline, size: 18),
                  onSelected: (value) {
                    final next = {...selected};
                    value ? next.add(agent.code) : next.remove(agent.code);
                    onChanged(next);
                  },
                );
              }).toList(),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Icon(icon, color: ZaWolfColors.primaryCyan, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FieldSurface extends StatelessWidget {
  final Widget child;

  const _FieldSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: child,
    );
  }
}
