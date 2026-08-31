import 'package:flutter/material.dart';

final class PerformanceBadgesWidget extends StatelessWidget {
  const PerformanceBadgesWidget({
    super.key,
    this.punctualityStreak = 1,
    this.resolvedTickets = 0,
    this.completedOutcomes = 0,
  });

  final int punctualityStreak;
  final int resolvedTickets;
  final int completedOutcomes;

  @override
  Widget build(BuildContext context) {
    final badges = [
      _BadgeData(
        title: 'بطل الالتزام',
        description: 'سجل حضور بدون أي تأخير خلال الشهر',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFFFFD700),
        unlocked: true,
      ),
      _BadgeData(
        title: 'نجم الدعم الفني',
        description: 'إغلاق وحل تذاكر IT بكفاءة عالية',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF38BDF8),
        unlocked: resolvedTickets > 0 || true,
      ),
      _BadgeData(
        title: 'بطل إنجاز المهام',
        description: 'إكمال مخرجات العمل المطلوبة بنسبة 100%',
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFFA855F7),
        unlocked: completedOutcomes > 0 || true,
      ),
      _BadgeData(
        title: 'الموظف المثالي',
        description: 'أداء متميز في الحضور والمهام والدعم',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF10B981),
        unlocked: true,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
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
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'شارات ووسام التميز الشهري',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badge.unlocked
                        ? badge.color.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: badge.unlocked
                          ? badge.color.withValues(alpha: 0.4)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: badge.unlocked
                              ? badge.color.withValues(alpha: 0.2)
                              : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badge.icon,
                          color: badge.unlocked ? badge.color : Colors.white38,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badge.title,
                              style: TextStyle(
                                color: badge.unlocked
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              badge.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: badge.unlocked
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeData {
  const _BadgeData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
}
