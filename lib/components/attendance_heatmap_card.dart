import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

final class AttendanceHeatmapCard extends StatefulWidget {
  const AttendanceHeatmapCard({super.key});

  @override
  State<AttendanceHeatmapCard> createState() => _AttendanceHeatmapCardState();
}

class _AttendanceHeatmapCardState extends State<AttendanceHeatmapCard> {
  DateTime _currentMonth = DateTime.now();
  Map<String, int> _dailyPresentCounts = {};
  Map<String, int> _dailyLateCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonthAttendance();
  }

  Future<void> _fetchMonthAttendance() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final prefix = DateFormat('yyyy-MM').format(_currentMonth);

    try {
      final snap = await db.collection('attendance').get();
      final present = <String, int>{};
      final late = <String, int>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String? ?? '';
        if (dateStr.startsWith(prefix)) {
          final isLate = data['isLate'] as bool? ?? false;
          final status = data['status'] as String? ?? '';
          if (isLate || status.contains('late')) {
            late[dateStr] = (late[dateStr] ?? 0) + 1;
          } else {
            present[dateStr] = (present[dateStr] ?? 0) + 1;
          }
        }
      }
      _dailyPresentCounts = present;
      _dailyLateCounts = late;
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _getDayColor(String dateKey) {
    final p = _dailyPresentCounts[dateKey] ?? 0;
    final l = _dailyLateCounts[dateKey] ?? 0;
    final total = p + l;

    if (total == 0) return Colors.white10;
    final ratio = p / total;

    if (ratio >= 0.85) return const Color(0xFF10B981); // Green
    if (ratio >= 0.65) return const Color(0xFFF59E0B); // Amber
    return const Color(0xEFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(_currentMonth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.grid_on_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الخريطة الحرارية للحضور ($monthLabel)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'الشهر السابق',
                      icon: const Icon(Icons.chevron_right, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month - 1,
                          );
                        });
                        _fetchMonthAttendance();
                      },
                    ),
                    IconButton(
                      tooltip: 'الشهر التالي',
                      icon: const Icon(Icons.chevron_left, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(
                            _currentMonth.year,
                            _currentMonth.month + 1,
                          );
                        });
                        _fetchMonthAttendance();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: daysInMonth,
                itemBuilder: (context, index) {
                  final dayNum = index + 1;
                  final dateKey =
                      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                  final color = _getDayColor(dateKey);
                  final present = _dailyPresentCounts[dateKey] ?? 0;
                  final late = _dailyLateCounts[dateKey] ?? 0;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: (present + late > 0)
                        ? () => _showDayDetails(context, dateKey, present, late)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.6)),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            color: color == Colors.white10
                                ? Colors.white38
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Color(0xFF10B981), label: 'ممتاز (>85%)'),
                  SizedBox(width: 12),
                  _LegendDot(color: Color(0xFFF59E0B), label: 'متوسط (65-85%)'),
                  SizedBox(width: 12),
                  _LegendDot(color: Color(0xEFEF4444), label: 'منخفض (<65%)'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDayDetails(
    BuildContext context,
    String dateKey,
    int present,
    int late,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تفاصيل يوم $dateKey',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                ),
                title: const Text(
                  'حاضر في الموعد',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '$present موظف',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.access_time_filled,
                  color: Color(0xFFF59E0B),
                ),
                title: const Text(
                  'حاضر متأخر',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '$late موظف',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}
