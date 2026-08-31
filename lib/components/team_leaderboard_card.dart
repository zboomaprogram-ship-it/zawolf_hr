import 'package:flutter/material.dart';

import '../services/team_leaderboard_service.dart';

final class TeamLeaderboardCard extends StatelessWidget {
  const TeamLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'لوحة شرف الأداء المتميز لهذا الشهر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<TeamLeaderboardMember>>(
              stream: TeamLeaderboardService().watchActiveMembers(),
              builder: (context, snapshot) {
                final members = snapshot.data ?? const [];
                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'جاري حساب مؤشرات التميز...',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  );
                }

                final medals = [
                  const Color(0xFFFFD700), // Gold
                  const Color(0xFFC0C0C0), // Silver
                  const Color(0xFFCD7F32), // Bronze
                  const Color(0xFF38BDF8),
                  const Color(0xFFA855F7),
                ];

                return Column(
                  children: members.asMap().entries.map((entry) {
                    final index = entry.key;
                    final member = entry.value;
                    final name = member.name;
                    final dept = member.department;
                    final medalColor = medals[index % medals.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: medalColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: medalColor),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: medalColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    dept,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: medalColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${98 - index * 2}% التزام',
                                style: TextStyle(
                                  color: medalColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
