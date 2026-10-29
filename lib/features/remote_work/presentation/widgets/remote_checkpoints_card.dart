import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

class RemoteCheckpointsCard extends StatefulWidget {
  const RemoteCheckpointsCard({
    required this.checkpoints,
    required this.completedUpdates,
    required this.onSubmit,
    super.key,
  });

  final List<Map<String, dynamic>> checkpoints;
  final Map<String, String> completedUpdates;
  final void Function(String checkpointId, String text, int slotIndex) onSubmit;

  @override
  State<RemoteCheckpointsCard> createState() => _RemoteCheckpointsCardState();
}

class _RemoteCheckpointsCardState extends State<RemoteCheckpointsCard> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String id) {
    return _controllers.putIfAbsent(id, () => TextEditingController());
  }

  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null) return 0;
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final displayCheckpoints = widget.checkpoints.isNotEmpty
        ? widget.checkpoints
        : const [
            {'id': 'cp_1', 'label': 'نقطة المتابعة الأولى', 'dueTime': '11:00', 'graceMinutes': 15},
            {'id': 'cp_2', 'label': 'نقطة المتابعة الثانية', 'dueTime': '13:30', 'graceMinutes': 15},
            {'id': 'cp_3', 'label': 'نقطة المتابعة الثالثة', 'dueTime': '15:30', 'graceMinutes': 15},
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alarm_on, color: ZaWolfColors.primaryCyan),
              const SizedBox(width: 8),
              Text(
                'نقاط المتابعة الدورية (${displayCheckpoints.length})',
                style: const TextStyle(
                  color: ZaWolfColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface03,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'قفل آلي بعد انتهاء الوقت',
                  style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < displayCheckpoints.length; i++) ...[
            _buildCheckpointItem(displayCheckpoints[i], i + 1, nowMinutes),
            if (i < displayCheckpoints.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckpointItem(Map<String, dynamic> cp, int slotIndex, int nowMinutes) {
    final cpId = cp['id']?.toString() ?? 'cp_$slotIndex';
    final label = cp['label']?.toString() ?? 'نقطة المتابعة $slotIndex';
    final dueTime = cp['dueTime']?.toString() ?? '12:00';
    final graceMinutes = (cp['graceMinutes'] as num?)?.toInt() ?? 15;

    final dueMinutes = _parseTimeToMinutes(dueTime);
    final deadlineMinutes = dueMinutes + graceMinutes;

    final hasCompleted = widget.completedUpdates.containsKey(cpId);
    final isExpired = nowMinutes > deadlineMinutes;
    final isOpen = nowMinutes >= dueMinutes && nowMinutes <= deadlineMinutes;

    Color borderColor;
    Color headerBg;
    Widget statusBadge;

    if (hasCompleted) {
      borderColor = ZaWolfColors.success.withValues(alpha: 0.5);
      headerBg = ZaWolfColors.success.withValues(alpha: 0.1);
      statusBadge = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: ZaWolfColors.success),
          SizedBox(width: 4),
          Text(
            'تم تسجيل المتابعة',
            style: TextStyle(color: ZaWolfColors.success, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (isExpired) {
      borderColor = ZaWolfColors.error.withValues(alpha: 0.4);
      headerBg = ZaWolfColors.error.withValues(alpha: 0.08);
      statusBadge = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 14, color: ZaWolfColors.error),
          SizedBox(width: 4),
          Text(
            'انتهت فترة السماح — مغلقة',
            style: TextStyle(color: ZaWolfColors.error, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (isOpen) {
      borderColor = ZaWolfColors.primaryCyan;
      headerBg = ZaWolfColors.primaryCyan.withValues(alpha: 0.12);
      final remaining = deadlineMinutes - nowMinutes;
      statusBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 14, color: ZaWolfColors.primaryCyan),
          const SizedBox(width: 4),
          Text(
            'متاحة الآن (متبقي $remaining دقيقة)',
            style: const TextStyle(color: ZaWolfColors.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      borderColor = ZaWolfColors.surface03;
      headerBg = ZaWolfColors.surface03.withValues(alpha: 0.3);
      statusBadge = Text(
        'تبدأ الساعة $dueTime',
        style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isOpen ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: ZaWolfColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($dueTime ± $graceMinutes دقيقة)',
                      style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                statusBadge,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: hasCompleted
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.completedUpdates[cpId] ?? '',
                      style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 13),
                    ),
                  )
                : isExpired
                    ? Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.block, size: 16, color: ZaWolfColors.error),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تجاوزت فترة السماح المحددة دون تسجيل؛ تم إشعار مديرك المباشر وإدارة الموارد البشرية، وتم قفل الإدخال تلقائياً.',
                                style: TextStyle(color: ZaWolfColors.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : isOpen
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _getController(cpId),
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'سجل ما أنجزته خلال هذه الفترة من يوم العمل...',
                                  hintStyle: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 13),
                                  filled: true,
                                  fillColor: ZaWolfColors.surface02,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final text = _getController(cpId).text.trim();
                                    if (text.isNotEmpty) {
                                      widget.onSubmit(cpId, text, slotIndex);
                                    }
                                  },
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text('إرسال المتابعة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ZaWolfColors.primaryCyan,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'المتابعة غير متاحة الآن. ستفتح الخانة في تمام الساعة $dueTime وتبقى متاحة لمدة $graceMinutes دقيقة.',
                            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
                          ),
          ),
        ],
      ),
    );
  }
}
