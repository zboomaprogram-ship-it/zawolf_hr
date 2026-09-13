import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/end_of_day_briefing_service.dart';
import '../../theme/theme.dart';

final class EndOfDayBriefingCard extends StatefulWidget {
  const EndOfDayBriefingCard({super.key, required this.isHr, this.managerUid});

  final bool isHr;
  final String? managerUid;

  @override
  State<EndOfDayBriefingCard> createState() => _EndOfDayBriefingCardState();
}

class _EndOfDayBriefingCardState extends State<EndOfDayBriefingCard> {
  bool _loading = true;
  int _presentCount = 0;
  int _lateCount = 0;
  int _totalEmployees = 0;
  int _resolvedTicketsCount = 0;
  int _tomorrowLeavesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBriefingData();
  }

  Future<void> _loadBriefingData() async {
    setState(() => _loading = true);
    try {
      final briefing = await EndOfDayBriefingService().load(
        isHr: widget.isHr,
        managerUid: widget.managerUid,
      );
      _totalEmployees = briefing.totalEmployees;
      _presentCount = briefing.presentCount;
      _lateCount = briefing.lateCount;
      _resolvedTicketsCount = briefing.resolvedTicketsCount;
      _tomorrowLeavesCount = briefing.tomorrowLeavesCount;
    } catch (_) {
      // Safe fallback
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendancePct = _totalEmployees > 0
        ? (((_presentCount + _lateCount) / _totalEmployees) * 100)
              .toStringAsFixed(0)
        : '100';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ZaWolfColors.surface02, ZaWolfColors.surface01],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: ZaWolfColors.primaryCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isHr
                          ? 'تقرير الإحاطة اليومي للمنظومة'
                          : 'تقرير الإحاطة اليومي لفريق العمل',
                      style: const TextStyle(
                        color: ZaWolfColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ملخص اليوم ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                      style: const TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: ZaWolfColors.textSecondary,
                  size: 20,
                ),
                onPressed: _loadBriefingData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _BriefingStatTile(
                    label: 'نسبة الحضور',
                    value: '$attendancePct%',
                    icon: Icons.pie_chart_outline_rounded,
                    color: ZaWolfColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BriefingStatTile(
                    label: 'التأخيرات',
                    value: '$_lateCount',
                    icon: Icons.access_time_filled_rounded,
                    color: ZaWolfColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BriefingStatTile(
                    label: 'تذاكر حُلت',
                    value: '$_resolvedTicketsCount',
                    icon: Icons.task_alt_rounded,
                    color: ZaWolfColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: ZaWolfColors.dayoffPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tomorrowLeavesCount > 0
                          ? 'تنويه الغد: يوجد $_tomorrowLeavesCount إجازة معتمدة غداً'
                          : 'تنويه الغد: لا توجد إجازات جديدة مسجلة غداً',
                      style: const TextStyle(color: ZaWolfColors.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BriefingStatTile extends StatelessWidget {
  const _BriefingStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
