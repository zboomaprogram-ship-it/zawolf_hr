import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../design_system/components/feedback_states.dart';
import '../design_system/components/section_header.dart';
import '../design_system/components/skeletons.dart';
import '../design_system/components/status_pill.dart';
import '../design_system/tokens.dart';
import '../theme/theme.dart';

class EmployeeRequestHistorySection extends StatefulWidget {
  const EmployeeRequestHistorySection({
    super.key,
    required this.userId,
    this.onPendingCount,
  });

  final String userId;

  /// Reports how many loaded requests are still awaiting approval so the
  /// dashboard priority strip can reuse this load without extra queries.
  final ValueChanged<int>? onPendingCount;

  @override
  State<EmployeeRequestHistorySection> createState() =>
      _EmployeeRequestHistorySectionState();
}

class _EmployeeRequestHistorySectionState
    extends State<EmployeeRequestHistorySection> {
  late Future<List<_RequestSummary>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  @override
  void didUpdateWidget(covariant EmployeeRequestHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _requests = _loadRequests();
    }
  }

  bool _isPending(String status) =>
      status != 'approved' && status != 'rejected' && status != 'cancelled';

  Future<List<_RequestSummary>> _loadRequests() async {
    final firestore = FirebaseFirestore.instance;
    final snapshots = await Future.wait([
      firestore
          .collection('leaves')
          .where('userId', isEqualTo: widget.userId)
          .get(),
      firestore
          .collection('permissions')
          .where('userId', isEqualTo: widget.userId)
          .get(),
      firestore
          .collection('administrativeRequests')
          .where('userId', isEqualTo: widget.userId)
          .get(),
    ]);

    final requests = <_RequestSummary>[
      ...snapshots[0].docs.map(
        (doc) => _RequestSummary.fromDocument(doc, 'إجازة'),
      ),
      ...snapshots[1].docs.map(
        (doc) => _RequestSummary.fromDocument(doc, 'إذن'),
      ),
      ...snapshots[2].docs.map(
        (doc) => _RequestSummary.fromDocument(doc, 'طلب إداري'),
      ),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    widget.onPendingCount?.call(
      requests.where((request) => _isPending(request.status)).length,
    );
    return requests;
  }

  void _reload() {
    setState(() => _requests = _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'تحديث سجل الطلبات',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            Expanded(
              child: SectionHeader(
                title: 'سجل الطلبات',
                actionLabel: 'عرض الكل',
                onAction: () => context.go('/employee/requests'),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.sm),
        FutureBuilder<List<_RequestSummary>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasError) {
              return const SkeletonList(itemCount: 3, itemHeight: 64);
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: 'تعذر تحميل سجل الطلبات الآن.',
                onRetry: _reload,
              );
            }
            final requests = snapshot.data ?? const <_RequestSummary>[];
            if (requests.isEmpty) {
              return const EmptyState(
                title: 'لا توجد طلبات حتى الآن.',
                subtitle: 'الطلبات التي ترسلها تظهر هنا، وتنتقل إلى السجل بعد مراجعتها.',
              );
            }

            return Column(
              children: [
                for (final request in requests.take(5))
                  _RequestSummaryTile(request: request),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestSummary {
  const _RequestSummary({
    required this.type,
    required this.status,
    required this.submittedAt,
    required this.detail,
  });

  final String type;
  final String status;
  final DateTime submittedAt;
  final String detail;

  factory _RequestSummary.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String type,
  ) {
    final data = doc.data();
    final submittedAt =
        (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
    final detail = switch (type) {
      'إجازة' =>
        '${data['numberOfDays'] ?? 1} يوم · ${_date(data['startDate'])}',
      'إذن' => '${data['requestDate'] ?? ''} · ${data['expectedTime'] ?? ''}',
      _ => data['category'] as String? ?? 'طلب إداري',
    };
    return _RequestSummary(
      type: type,
      status: data['status'] as String? ?? 'pending_manager',
      submittedAt: submittedAt,
      detail: detail,
    );
  }

  static String _date(Object? value) {
    final date = value is Timestamp ? value.toDate() : null;
    return date == null ? '' : DateFormat('yyyy/MM/dd').format(date);
  }
}

class _RequestSummaryTile extends StatelessWidget {
  const _RequestSummaryTile({required this.request});

  final _RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Row(
        children: [
          StatusPill(status: status.$1, label: status.$2, compact: true),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  request.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  request.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ZaWolfColors.textSecondary),
                ),
                Text(
                  DateFormat(
                    'yyyy/MM/dd · hh:mm a',
                  ).format(request.submittedAt),
                  style: const TextStyle(
                    color: ZaWolfColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(DsStatus, String) _statusPresentation(String status) {
  switch (status) {
    case 'approved':
      return (DsStatus.approved, 'مقبول');
    case 'rejected':
      return (DsStatus.rejected, 'مرفوض');
    case 'cancelled':
      return (DsStatus.neutral, 'ملغي');
    case 'pending_hr':
      return (DsStatus.pendingAction, 'بانتظار HR');
    case 'pending_ceo':
      return (DsStatus.pendingAction, 'بانتظار CEO');
    default:
      return (DsStatus.pendingAction, 'بانتظار المدير');
  }
}
