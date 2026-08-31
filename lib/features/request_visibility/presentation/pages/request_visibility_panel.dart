import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
import '../../domain/entities/request_view_query.dart';
import '../../domain/entities/request_visibility_record.dart';
import '../cubit/request_visibility_cubit.dart';

final class RequestVisibilityPanel extends StatefulWidget {
  const RequestVisibilityPanel({
    super.key,
    required this.query,
    this.searchTerm = '',
  });

  final RequestViewQuery query;
  final String searchTerm;

  @override
  State<RequestVisibilityPanel> createState() => _RequestVisibilityPanelState();
}

final class _RequestVisibilityPanelState extends State<RequestVisibilityPanel>
    with AutomaticKeepAliveClientMixin {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<RequestVisibilityCubit, RequestVisibilityState>(
        builder: (context, state) {
          final records = state.records
              .where((record) => _matchesSearch(record, widget.searchTerm))
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
            return const _RequestState(
              icon: Icons.inbox_outlined,
              message: 'لا توجد سجلات مطابقة للبحث أو الفترة المحددة.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
              return _RequestRecordCard(record: records[index]);
            },
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
  const _RequestRecordCard({required this.record});

  final RequestVisibilityRecord record;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
        child: Icon(_icon(record.sourceType), color: ZaWolfColors.primaryCyan),
      ),
      title: Text(
        record.employeeName?.isNotEmpty == true
            ? record.employeeName!
            : record.employeeCode ?? record.employeeId,
      ),
      subtitle: Text(
        '${_typeLabel(record.sourceType)} · ${_stateLabel(record.lifecycleState)}\n'
        '${DateFormat('yyyy/MM/dd – HH:mm').format(record.occurredAt.toLocal())}'
        '${record.reason?.isNotEmpty == true ? '\n${record.reason}' : ''}',
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(_stageLabel(record.approvalStage))),
    ),
  );

  IconData _icon(RequestSourceType type) => switch (type) {
    RequestSourceType.leave => Icons.event_available_outlined,
    RequestSourceType.permission => Icons.schedule_outlined,
    RequestSourceType.attendanceCorrection => Icons.edit_calendar_outlined,
    RequestSourceType.salaryDeduction ||
    RequestSourceType.lateArrivalDeduction => Icons.money_off_outlined,
    RequestSourceType.advance => Icons.account_balance_wallet_outlined,
    RequestSourceType.administrative => Icons.assignment_outlined,
    RequestSourceType.complaint => Icons.report_problem_outlined,
    RequestSourceType.resignation => Icons.meeting_room_outlined,
    RequestSourceType.employeeDeletion => Icons.person_remove_outlined,
    RequestSourceType.unknown => Icons.description_outlined,
  };

  String _typeLabel(RequestSourceType type) => switch (type) {
    RequestSourceType.leave => 'إجازة',
    RequestSourceType.permission => 'إذن',
    RequestSourceType.attendanceCorrection => 'تصحيح حضور',
    RequestSourceType.salaryDeduction => 'خصم راتب',
    RequestSourceType.lateArrivalDeduction => 'خصم حضور',
    RequestSourceType.advance => 'سلفة',
    RequestSourceType.administrative => 'طلب إداري',
    RequestSourceType.complaint => 'شكوى',
    RequestSourceType.resignation => 'استقالة',
    RequestSourceType.employeeDeletion => 'حذف حساب موظف',
    RequestSourceType.unknown => 'طلب',
  };

  String _stateLabel(RequestLifecycleState state) => switch (state) {
    RequestLifecycleState.pending => 'قيد المراجعة',
    RequestLifecycleState.approved => 'مقبول',
    RequestLifecycleState.rejected => 'مرفوض',
    RequestLifecycleState.cancelled => 'ملغي',
    RequestLifecycleState.confirmed => 'معتمد نهائيًا',
    RequestLifecycleState.unknown => 'حالة غير محددة',
  };

  String _stageLabel(RequestApprovalStage stage) => switch (stage) {
    RequestApprovalStage.manager => 'المدير',
    RequestApprovalStage.ceo => 'المالك',
    RequestApprovalStage.hr => 'HR',
    RequestApprovalStage.finalised => 'مكتمل',
    RequestApprovalStage.unknown => 'مراجعة',
  };
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
