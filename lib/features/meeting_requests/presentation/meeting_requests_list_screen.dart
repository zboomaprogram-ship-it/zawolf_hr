import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../domain/meeting_repository.dart';

/// Reusable requester history and recipient approval queue. The server decides
/// which rows are visible, so changing the route cannot expose another user's
/// meeting request.
class MeetingRequestsListScreen extends StatefulWidget {
  const MeetingRequestsListScreen({
    required this.repository,
    required this.approvalQueue,
    this.embedded = false,
    super.key,
  });

  final MeetingRepository repository;
  final bool approvalQueue;
  final bool embedded;

  @override
  State<MeetingRequestsListScreen> createState() =>
      _MeetingRequestsListScreenState();
}

class _MeetingRequestsListScreenState extends State<MeetingRequestsListScreen> {
  var _loading = true;
  List<MeetingRequest> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await widget.repository.requests(
        approvalQueue: widget.approvalQueue,
      );
      if (mounted) setState(() => _items = values);
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(MeetingRequest request, bool approved) async {
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                approved ? 'الموافقة على الاجتماع' : 'رفض طلب الاجتماع',
              ),
              content: TextField(
                controller: comment,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      approved ? 'ملاحظة (اختيارية)' : 'سبب الرفض (اختياري)',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(approved ? 'موافقة' : 'رفض'),
                ),
              ],
            ),
          ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.decide(
        requestId: request.id,
        approved: approved,
        comment: comment.text.trim(),
      );
      if (mounted) {
        _notice(
          approved
              ? 'تمت الموافقة وإشعار مقدم الطلب.'
              : 'تم الرفض وإشعار مقدم الطلب.',
        );
        await _load();
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    } finally {
      comment.dispose();
    }
  }

  Future<void> _cancel(MeetingRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إلغاء طلب الاجتماع؟'),
              content: const Text('سيتم تحرير القاعة وإشعار المسؤول المختار.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('رجوع'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('إلغاء الطلب'),
                ),
              ],
            ),
          ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.cancel(request.id);
      if (mounted) {
        _notice('تم إلغاء طلب الاجتماع.');
        await _load();
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    }
  }

  void _notice(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );

  String _status(String value) => switch (value) {
    'pending' => 'بانتظار القرار',
    'approved' => 'تمت الموافقة',
    'rejected' => 'مرفوض',
    'cancelled' => 'ملغى',
    _ => value,
  };

  Widget _content(BuildContext context) =>
      _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
            onRefresh: _load,
            child:
                _items.isEmpty
                    ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('لا توجد طلبات اجتماعات حالياً.')),
                      ],
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: _buildItem,
                    ),
          );

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final date = item.startAt == null
        ? 'لم يحدد الموعد'
        : DateFormat('yyyy/MM/dd  hh:mm a', 'ar').format(item.startAt!.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(widget.approvalQueue ? item.requesterName : item.approverName, style: Theme.of(context).textTheme.titleMedium)),
              Chip(label: Text(_status(item.status))),
            ]),
            Text('$date · ${item.roomName}'),
            const SizedBox(height: 6),
            Text(item.purpose),
            if (item.approvalRoute.isNotEmpty) ...[
              const Divider(),
              Text('المسار: ${item.approvalRoute.map((x) => '${x['approverName'] ?? 'مسؤول'} (${_status('${x['state'] ?? 'pending'}')})').join(' ← ')}'),
            ],
            if (item.status == 'pending') Padding(
              padding: const EdgeInsets.only(top: 8),
              child: widget.approvalQueue
                  ? Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _decide(item, false), child: const Text('رفض'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(onPressed: () => _decide(item, true), child: const Text('موافقة'))),
                  ])
                  : OutlinedButton.icon(onPressed: () => _cancel(item), icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء الطلب')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: widget.embedded
        ? _content(context)
        : Scaffold(
      appBar: AppBar(
        title: Text(
          widget.approvalQueue
              ? 'طلبات الاجتماعات بانتظار قراري'
              : 'سجل طلبات الاجتماعات',
        ),
      ),
      body: _content(context),
    ),
  );
}
