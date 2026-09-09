import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
import '../../../../components/wolf_card.dart';
import '../../domain/entities/request_view_query.dart';
import '../../domain/entities/request_visibility_record.dart';
import '../cubit/request_visibility_cubit.dart';
import '../widgets/request_type_style.dart';

final class RequestVisibilityPanel extends StatefulWidget {
  const RequestVisibilityPanel({
    super.key,
    required this.query,
    this.searchTerm = '',
    this.onSelectRecord,
  });

  final RequestViewQuery query;
  final String searchTerm;
  final void Function(RequestVisibilityRecord record)? onSelectRecord;

  @override
  State<RequestVisibilityPanel> createState() => _RequestVisibilityPanelState();
}

final class _RequestVisibilityPanelState extends State<RequestVisibilityPanel>
    with AutomaticKeepAliveClientMixin {
  RequestLifecycleState? _selectedLifecycle;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant RequestVisibilityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryIdentity(oldWidget.query) != _queryIdentity(widget.query)) {
      _load();
    }
  }

  String _queryIdentity(RequestViewQuery value) =>
      '${value.actorScope.actorId}|${value.actorScope.role}|${value.tab.name}|'
      '${value.fromDate.toIso8601String()}|${value.toDate.toIso8601String()}';

  void _load() => context.read<RequestVisibilityCubit>().load(widget.query);

  Widget _buildFilterChips() {
    final filters = <(RequestLifecycleState?, String)>[
      (null, 'الكل'),
      (RequestLifecycleState.pending, 'قيد المراجعة'),
      (RequestLifecycleState.approved, 'معتمد'),
      (RequestLifecycleState.rejected, 'مرفوض'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          for (final (lifecycle, label) in filters)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _selectedLifecycle == lifecycle,
                onSelected: (_) => setState(() => _selectedLifecycle = lifecycle),
                selectedColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _selectedLifecycle == lifecycle
                      ? ZaWolfColors.primaryCyan
                      : ZaWolfColors.textSecondary,
                  fontWeight: _selectedLifecycle == lifecycle
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<RequestVisibilityCubit, RequestVisibilityState>(
        builder: (context, state) {
          final records = state.records
              .where((record) => _matchesSearch(record, widget.searchTerm))
              .where((record) {
                if (_selectedLifecycle == null) return true;
                if (_selectedLifecycle == RequestLifecycleState.approved) {
                  return record.lifecycleState == RequestLifecycleState.approved ||
                      record.lifecycleState == RequestLifecycleState.confirmed;
                }
                return record.lifecycleState == _selectedLifecycle;
              })
              .toList(growable: false);
          if (state.loading && state.records.isEmpty) {
            return const _RequestState(
              icon: Icons.hourglass_top,
              message: 'جارٍ تحميل الطلبات والسجلات…',
              loading: true,
            );
          }
          if (state.safeMessage != null && state.records.isEmpty) {
            return _RequestState(
              icon: state.accessDenied
                  ? Icons.lock_outline
                  : Icons.cloud_off_outlined,
              message: state.safeMessage!,
              actionLabel: state.accessDenied ? null : 'إعادة المحاولة',
              onAction: state.accessDenied
                  ? null
                  : context.read<RequestVisibilityCubit>().retry,
            );
          }
          if (records.isEmpty) {
            return Column(
              children: [
                _buildFilterChips(),
                const Expanded(
                  child: _RequestState(
                    icon: Icons.inbox_outlined,
                    message: 'لا توجد سجلات مطابقة للبحث أو التصفية المحددة.',
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: records.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == records.length) {
                      return Center(
                        child: OutlinedButton.icon(
                          onPressed: state.loading
                              ? null
                              : context.read<RequestVisibilityCubit>().loadMore,
                          icon: state.loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more),
                          label: const Text('تحميل المزيد'),
                        ),
                      );
                    }
                    final record = records[index];
                    return _RequestRecordCard(
                      record: record,
                      onTap: widget.onSelectRecord != null
                          ? () => widget.onSelectRecord!(record)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesSearch(RequestVisibilityRecord record, String rawNeedle) {
    final needle = rawNeedle.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return <String?>[
      record.employeeName,
      record.employeeCode,
      record.employeeId,
      record.reason,
      record.stableId,
    ].whereType<String>().any((value) => value.toLowerCase().contains(needle));
  }
}

final class _RequestRecordCard extends StatelessWidget {
  const _RequestRecordCard({
    required this.record,
    this.onTap,
  });

  final RequestVisibilityRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RequestTypeStyle.fromSourceType(record.sourceType);
    final typeColor = style.borderColor;
    final shadowColor = style.shadowColor;
    final stateColor = RequestTypeStyle.stateColor(record.lifecycleState);

    return WolfCard(
      borderColor: typeColor,
      borderWidth: 1.5,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  style.icon,
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName?.isNotEmpty == true
                          ? record.employeeName!
                          : record.employeeCode ?? record.employeeId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy/MM/dd – HH:mm').format(record.occurredAt.toLocal()),
                      style: const TextStyle(
                        color: ZaWolfColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (record.reason?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.reason!,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stateColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      RequestTypeStyle.stateLabel(record.lifecycleState),
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'المرحلة: ${RequestTypeStyle.stageLabel(record.approvalStage)}',
                      style: const TextStyle(
                        color: ZaWolfColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (onTap != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'عرض الإجراء',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: typeColor,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _RequestState extends StatelessWidget {
  const _RequestState({
    required this.icon,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 48, color: ZaWolfColors.textSecondary),
          const SizedBox(height: 12),
          SelectableText(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
