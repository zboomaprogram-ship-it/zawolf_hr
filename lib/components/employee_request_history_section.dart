import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../theme/theme.dart';

class EmployeeRequestHistorySection extends StatefulWidget {
  const EmployeeRequestHistorySection({super.key, required this.userId});

  final String userId;

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
    return requests;
  }

  void _reload() {
    setState(() => _requests = _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            const Spacer(),
            Text(
              'سجل الطلبات',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<_RequestSummary>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 88,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _HistoryMessage(
                icon: Icons.cloud_off_outlined,
                text: 'تعذر تحميل سجل الطلبات الآن.',
                action: _reload,
              );
            }
            final requests = snapshot.data ?? const <_RequestSummary>[];
            if (requests.isEmpty) {
              return const _HistoryMessage(
                icon: Icons.inbox_outlined,
                text: 'لا توجد طلبات حتى الآن.',
              );
            }

            return Column(
              children: [
                for (final request in requests.take(5))
                  _RequestSummaryTile(request: request),
                TextButton.icon(
                  onPressed: () => context.go('/employee/requests'),
                  icon: const Icon(Icons.history),
                  label: const Text('عرض السجل الكامل'),
                ),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
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

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (action != null)
            IconButton(onPressed: action, icon: const Icon(Icons.refresh)),
          Text(text, style: const TextStyle(color: ZaWolfColors.textSecondary)),
          const SizedBox(width: 8),
          Icon(icon, color: ZaWolfColors.textMuted),
        ],
      ),
    );
  }
}

({String label, Color color}) _statusPresentation(String status) {
  if (status == 'approved') {
    return (label: 'مقبول', color: ZaWolfColors.success);
  }
  if (status == 'rejected') {
    return (label: 'مرفوض', color: ZaWolfColors.error);
  }
  if (status == 'cancelled') {
    return (label: 'ملغي', color: ZaWolfColors.textMuted);
  }
  if (status == 'pending_hr') {
    return (label: 'بانتظار HR', color: ZaWolfColors.warning);
  }
  if (status == 'pending_ceo') {
    return (label: 'بانتظار CEO', color: ZaWolfColors.warning);
  }
  return (label: 'بانتظار المدير', color: ZaWolfColors.warning);
}
