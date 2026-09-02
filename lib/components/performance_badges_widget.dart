import 'package:flutter/material.dart';
import '../services/performance_badge_service.dart';
import '../models/custom_badge_model.dart';

/// Presentation catalogue. HR manages award IDs on the employee document;
/// badges never affect salary, payroll, attendance, or performance scoring.
final class PerformanceBadgeDefinition {
  const PerformanceBadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

const performanceBadgeCatalog = <PerformanceBadgeDefinition>[
  PerformanceBadgeDefinition(
    id: 'punctuality_champion',
    title: 'بطل الالتزام',
    description: 'التزام متميز بالحضور خلال الشهر',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFFFD700),
  ),
  PerformanceBadgeDefinition(
    id: 'support_star',
    title: 'نجم الدعم الفني',
    description: 'مساندة فعّالة وحل سريع للتذاكر',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF38BDF8),
  ),
  PerformanceBadgeDefinition(
    id: 'task_achievement',
    title: 'بطل إنجاز المهام',
    description: 'إنجاز المخرجات المطلوبة بجودة عالية',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFA855F7),
  ),
  PerformanceBadgeDefinition(
    id: 'ideal_employee',
    title: 'الموظف المثالي',
    description: 'تميز متوازن في الحضور والمهام والتعاون',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFF10B981),
  ),
  PerformanceBadgeDefinition(
    id: 'team_player',
    title: 'روح الفريق',
    description: 'تعاون واضح ومساندة مستمرة للفريق',
    icon: Icons.groups_rounded,
    color: Color(0xFFF97316),
  ),
  PerformanceBadgeDefinition(
    id: 'customer_care',
    title: 'سفير الخدمة',
    description: 'تواصل احترافي وتجربة مميزة للمستفيدين',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFFEC4899),
  ),
  PerformanceBadgeDefinition(
    id: 'quality_guardian',
    title: 'حارس الجودة',
    description: 'دقة عالية وحرص على جودة العمل',
    icon: Icons.verified_user_rounded,
    color: Color(0xFF14B8A6),
  ),
  PerformanceBadgeDefinition(
    id: 'growth_mindset',
    title: 'نجم التطور',
    description: 'مبادرة بالتعلّم وتحسين أسلوب العمل',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF818CF8),
  ),
];

String performanceBadgeTitle(String id) {
  for (final badge in performanceBadgeCatalog) {
    if (badge.id == id) return badge.title;
  }
  return 'شارة تميز';
}

final class PerformanceBadgesWidget extends StatelessWidget {
  const PerformanceBadgesWidget({
    super.key,
    this.awardedBadgeIds = const <String>{},
  });

  final Set<String> awardedBadgeIds;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: StreamBuilder<List<CustomBadgeModel>>(
      stream: PerformanceBadgeService.instance.watchCustomBadges(),
      builder: (context, snapshot) {
        final customBadges = snapshot.data ?? [];
        final allBadges = <PerformanceBadgeDefinition>[
          ...performanceBadgeCatalog,
          ...customBadges.map((cb) => PerformanceBadgeDefinition(
            id: cb.id,
            title: cb.title,
            description: cb.description,
            icon: _parseCustomIcon(cb.iconName),
            color: _parseCustomColor(cb.colorHex),
          )),
        ];

        return Container(
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
                  const Expanded(
                    child: Text(
                      'شارات ووسام التميز الشهري',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${awardedBadgeIds.length}/${allBadges.length}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                awardedBadgeIds.isEmpty
                    ? 'لم تُعتمد لك شارة بعد. تُمنح الشارات من مديرك أو الموارد البشرية.'
                    : 'مبروك، لديك ${awardedBadgeIds.length} شارة تميز معتمدة.',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.05,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: allBadges.length,
                itemBuilder:
                    (context, index) => _BadgeTile(
                      badge: allBadges[index],
                      unlocked: awardedBadgeIds.contains(allBadges[index].id),
                    ),
              ),
            ],
          ),
        );
      },
    ),
  );

  static Color _parseCustomColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }

  static IconData _parseCustomIcon(String name) {
    return switch (name) {
      'star' => Icons.star_rounded,
      'rocket' => Icons.rocket_launch_rounded,
      'military_tech' => Icons.military_tech_rounded,
      'workspace_premium' => Icons.workspace_premium_rounded,
      'verified_user' => Icons.verified_user_rounded,
      _ => Icons.emoji_events_rounded,
    };
  }
}

final class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});
  final PerformanceBadgeDefinition badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color:
          unlocked
              ? badge.color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: unlocked ? badge.color.withValues(alpha: 0.4) : Colors.white12,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                unlocked ? badge.color.withValues(alpha: 0.2) : Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(
            unlocked ? badge.icon : Icons.lock_outline_rounded,
            color: unlocked ? badge.color : Colors.white38,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
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
                  color: unlocked ? Colors.white70 : Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
