import 'package:flutter/material.dart';

import '../../components/performance_badges_widget.dart';
import '../../services/performance_badge_service.dart';
import '../../models/custom_badge_model.dart';
import '../../theme/theme.dart';

final class PerformanceBadgesOverviewScreen extends StatelessWidget {
  const PerformanceBadgesOverviewScreen({
    super.key,
    required this.viewerId,
    required this.canViewAll,
  });

  final String viewerId;
  final bool canViewAll;

  void _showAwardModal(BuildContext context, PerformanceBadgeRecipient recipient) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
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
                  icon: Icons.emoji_events_rounded,
                  color: const Color(0xFFFFD700),
                )),
              ];

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إدارة شارات الموظف (${recipient.displayName})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'اضغط على الشارة لمنحها أو سحبها من الموظف',
                      style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 16),

                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allBadges.length,
                        itemBuilder: (context, index) {
                          final badge = allBadges[index];
                          final isAwarded = recipient.badgeIds.contains(badge.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isAwarded
                                  ? badge.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAwarded ? badge.color : Colors.white12,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(badge.icon, color: badge.color),
                              title: Text(
                                badge.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                badge.description,
                                style: const TextStyle(
                                  color: ZaWolfColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAwarded ? ZaWolfColors.error : badge.color,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () async {
                                  if (isAwarded) {
                                    await PerformanceBadgeService.instance.removeBadgeFromEmployee(
                                      targetUserId: recipient.uid,
                                      badgeId: badge.id,
                                    );
                                  } else {
                                    await PerformanceBadgeService.instance.awardBadgeToEmployee(
                                      targetUserId: recipient.uid,
                                      badgeId: badge.id,
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: Text(isAwarded ? 'سحب الشارة' : 'منح الشارة'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('شارات ووسام فريق العمل')),
      body: StreamBuilder<List<PerformanceBadgeRecipient>>(
        stream: PerformanceBadgeService.instance.watchVisibleRecipients(
          viewerId: viewerId,
          canViewAll: canViewAll,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل شارات الفريق.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recipients = snapshot.data!;
          if (recipients.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد شارات مُعتمدة لفريقك حتى الآن.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recipients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final recipient = recipients[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface01,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZaWolfColors.surface03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          recipient.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          tooltip: 'تعديل الشارات يدوياً',
                          icon: const Icon(Icons.edit_note_rounded, color: ZaWolfColors.primaryCyan),
                          onPressed: () => _showAwardModal(context, recipient),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recipient.employeeId} · ${recipient.department}',
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipient.badgeIds
                          .map(
                            (id) => Chip(
                              avatar: const Icon(
                                Icons.emoji_events_outlined,
                                size: 16,
                              ),
                              label: Text(performanceBadgeTitle(id)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
