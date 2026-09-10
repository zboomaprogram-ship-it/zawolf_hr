import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/rtl_navigation.dart';
import '../services/team_leaderboard_service.dart';
import '../theme/theme.dart';

final class TeamLeaderboardCard extends StatefulWidget {
  const TeamLeaderboardCard({super.key});

  @override
  State<TeamLeaderboardCard> createState() => _TeamLeaderboardCardState();
}

class _TeamLeaderboardCardState extends State<TeamLeaderboardCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface01,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ZaWolfColors.warning.withValues(alpha: 0.3),
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
                    color: ZaWolfColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    color: ZaWolfColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'لوحة شرف الأداء المتميز لهذا الشهر',
                    style: TextStyle(
                      color: ZaWolfColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZaWolfColors.surface03),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showAll ? 'عرض أقل' : 'عرض الكل',
                          style: const TextStyle(
                            color: ZaWolfColors.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showAll
                              ? Icons.keyboard_arrow_up_rounded
                              : RtlNavigation.chevronEnd(context),
                          color: ZaWolfColors.primaryCyan,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'فتح شاشة الإنتاجية الكاملة',
                  onPressed: () => context.go('/manager/productivity'),
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: ZaWolfColors.textMuted,
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<TeamLeaderboardMember>>(
              stream: TeamLeaderboardService().watchActiveMembers(),
              builder: (context, snapshot) {
                final allMembers = snapshot.data ?? const [];
                if (allMembers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'جاري حساب مؤشرات التميز...',
                        style: TextStyle(color: ZaWolfColors.textMuted),
                      ),
                    ),
                  );
                }

                final displayMembers =
                    _showAll ? allMembers : allMembers.take(5).toList();

                const medals = [
                  ZaWolfColors.warning, // Gold
                  ZaWolfColors.textSecondary, // Silver
                  Color(0xFFCD7F32), // Bronze
                  ZaWolfColors.primaryCyan,
                  Color(0xFFA855F7),
                ];

                return Column(
                  children: displayMembers.asMap().entries.map((entry) {
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
                          color: ZaWolfColors.surface02,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ZaWolfColors.surface03.withValues(
                              alpha: 0.5,
                            ),
                          ),
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
                                      color: ZaWolfColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    dept,
                                    style: const TextStyle(
                                      color: ZaWolfColors.textMuted,
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
                                '${member.commitmentScore.toInt()}% التزام',
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
