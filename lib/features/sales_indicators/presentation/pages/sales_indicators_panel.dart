import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/sales_identity_mapping.dart';
import '../../domain/entities/sales_indicator_filter.dart';
import '../../domain/entities/sales_indicator_snapshot.dart';
import '../cubit/sales_indicators_cubit.dart';

final class SalesIndicatorsPanel extends StatefulWidget {
  const SalesIndicatorsPanel({
    super.key,
    required this.filter,
    required this.canManageMappings,
  });
  final SalesIndicatorFilter filter;
  final bool canManageMappings;

  @override
  State<SalesIndicatorsPanel> createState() => _SalesIndicatorsPanelState();
}

final class _SalesIndicatorsPanelState extends State<SalesIndicatorsPanel>
    with AutomaticKeepAliveClientMixin {
  String _role = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesIndicatorsCubit>().load(widget.filter);
    });
  }

  @override
  void didUpdateWidget(covariant SalesIndicatorsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_filterIdentity(oldWidget.filter) != _filterIdentity(widget.filter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SalesIndicatorsCubit>().load(widget.filter);
      });
    }
  }

  String _filterIdentity(SalesIndicatorFilter value) {
    final map = value.toMap();
    return '${map['startDate']}|${map['endDate']}|${map['company']}|'
        '${(map['sales'] as List).join(',')}|'
        '${(map['teleSales'] as List).join(',')}|'
        '${map['entryChannel']}|${map['salesTarget']}|${map['teleTarget']}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<SalesIndicatorsCubit, SalesIndicatorsState>(
        builder: (context, state) {
          if (state.loading && state.snapshot == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.snapshot == null) {
            return _Message(
              icon: state.accessDenied
                  ? Icons.lock_outline
                  : Icons.cloud_off_outlined,
              text: state.safeMessage ?? 'لا توجد بيانات مبيعات متاحة.',
              onRetry: state.accessDenied
                  ? null
                  : context.read<SalesIndicatorsCubit>().retry,
            );
          }
          final snapshot = state.snapshot!;
          final rows = snapshot.rows
              .where((row) => _role == 'all' || row.providerRole == _role)
              .toList(growable: false);
          return RefreshIndicator(
            onRefresh: context.read<SalesIndicatorsCubit>().retry,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SourceHealthCard(snapshot: snapshot),
                if (state.safeMessage != null) ...[
                  const SizedBox(height: 10),
                  _InlineWarning(text: state.safeMessage!),
                ],
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('الكل')),
                    ButtonSegment(value: 'sales', label: Text('المبيعات')),
                    ButtonSegment(
                      value: 'tele_sales',
                      label: Text('المبيعات الهاتفية'),
                    ),
                  ],
                  selected: {_role},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _role = value.first),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const _Message(
                    icon: Icons.inbox_outlined,
                    text: 'لا توجد نتائج مطابقة للفلاتر المحفوظة.',
                  )
                else
                  ...rows.map(
                    (row) => _MappingCard(
                      row: row,
                      canManage: widget.canManageMappings,
                      onMap: () => _map(row),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _map(SalesIdentityMapping row) async {
    final controller = TextEditingController(text: row.userId);
    final userId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط سجل المبيعات بموظف'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'المعرّف الداخلي لحساب الموظف',
            helperText: 'يُراجع الخادم الحساب النشط قبل حفظ الربط.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ الربط'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || userId == null || userId.isEmpty) return;
    await context.read<SalesIndicatorsCubit>().reconcile(
      providerRole: row.providerRole,
      providerKey: row.providerKey,
      employeeUserId: userId,
    );
  }
}

final class _SourceHealthCard extends StatelessWidget {
  const _SourceHealthCard({required this.snapshot});
  final SalesIndicatorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (snapshot.sourceHealth) {
      SalesSourceHealth.healthy => (
        'المصدر متزامن والفلاتر متطابقة',
        ZaWolfColors.success,
        Icons.verified_outlined,
      ),
      SalesSourceHealth.partial => (
        'البيانات جزئية أو يوجد ربط يحتاج مراجعة',
        ZaWolfColors.warning,
        Icons.warning_amber,
      ),
      SalesSourceHealth.stale => (
        'البيانات تحتاج تحديثاً',
        ZaWolfColors.warning,
        Icons.schedule,
      ),
      SalesSourceHealth.unavailable => (
        'مصدر المبيعات غير متاح حالياً',
        ZaWolfColors.error,
        Icons.cloud_off_outlined,
      ),
    };
    return Semantics(
      label: 'حالة مصدر مؤشرات المبيعات: $label',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(label, textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}

final class _MappingCard extends StatelessWidget {
  const _MappingCard({
    required this.row,
    required this.canManage,
    required this.onMap,
  });
  final SalesIdentityMapping row;
  final bool canManage;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final status = switch (row.status) {
      SalesIdentityMappingStatus.mapped => 'مرتبط',
      SalesIdentityMappingStatus.unmapped => 'غير مرتبط',
      SalesIdentityMappingStatus.ambiguous => 'ربط ملتبس',
    };
    return Card(
      child: ListTile(
        title: SelectableText(
          row.employeeName.isEmpty ? row.providerKey : row.employeeName,
        ),
        subtitle: SelectableText(
          '${_roleLabel(row.providerRole)} · ${row.providerKey} · $status\n'
          'النتيجة: ${_number(row.actual)} / ${_number(row.target)} · '
          'KPI ${row.finalKpi.toStringAsFixed(1)}%',
        ),
        trailing: canManage && !row.isMapped
            ? IconButton(
                tooltip: 'مراجعة الربط',
                onPressed: onMap,
                icon: const Icon(Icons.link),
              )
            : Icon(row.isMapped ? Icons.link : Icons.link_off),
      ),
    );
  }

  String _roleLabel(String value) => switch (value) {
    'sales' => 'مبيعات',
    'tele_sales' => 'مبيعات هاتفية',
    _ => 'مصدر خارجي',
  };

  String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

final class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: ZaWolfColors.warning));
}

final class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          SelectableText(text, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}
