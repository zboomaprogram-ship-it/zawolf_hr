import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'components/app_logo.dart';
import 'components/avatar.dart';
import 'components/badge.dart';
import 'components/filter_bar.dart';
import 'components/priority_strip.dart';
import 'components/section_header.dart';
import 'components/skeletons.dart';
import 'components/stat_card.dart';
import 'components/status_pill.dart';
import 'components/feedback_states.dart';
import 'tokens.dart';

/// Debug-only gallery for the design system (specs/ui_redesign/01).
/// Not routed in production; import and push from a dev menu when needed.
class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System Gallery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'الشعار'),
            const Center(child: AppLogo(size: 48)),
            const SizedBox(height: DsSpacing.xl),
            const SectionHeader(title: 'Status Pills'),
            Wrap(
              spacing: DsSpacing.sm,
              runSpacing: DsSpacing.sm,
              children: [
                StatusPill(status: DsStatus.present, label: 'حاضر'),
                StatusPill(status: DsStatus.late, label: 'متأخر'),
                StatusPill(status: DsStatus.absent, label: 'غائب'),
                StatusPill(
                  status: DsStatus.pendingAction,
                  label: 'بانتظار الموافقة',
                ),
                StatusPill(status: DsStatus.approved, label: 'موافق عليه'),
                StatusPill(status: DsStatus.rejected, label: 'مرفوض'),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            const SectionHeader(title: 'Stat Cards'),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.people_outline,
                    value: '128',
                    label: 'الموظفون',
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.how_to_reg_outlined,
                    value: '92%',
                    label: 'الحضور اليوم',
                    trendLabel: '+4%',
                    trendUp: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            SectionHeader(title: 'Priority Strip', actionLabel: 'عرض الكل', onAction: () {}),
            PriorityStrip(items: [
              PriorityItem(
                label: 'طلبات بانتظار موافقتك',
                count: 5,
                icon: Icons.approval_outlined,
                onTap: () {},
              ),
              PriorityItem(
                label: 'عنصر مخفي (صفر)',
                count: 0,
                icon: Icons.block,
                onTap: null,
              ),
            ]),
            const SizedBox(height: DsSpacing.xl),
            const SectionHeader(title: 'Filter Bar'),
            FilterBar(
              selectedId: 'pending',
              onSelected: (_) {},
              chips: const [
                FilterChipItem(id: 'all', label: 'الكل'),
                FilterChipItem(id: 'pending', label: 'معلق', count: 3),
                FilterChipItem(id: 'approved', label: 'موافق'),
                FilterChipItem(id: 'rejected', label: 'مرفوض'),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            const SectionHeader(title: 'Skeletons'),
            const SkeletonList(itemCount: 2),
            const SectionHeader(title: 'Empty & Error'),
            const EmptyState(title: 'لا توجد طلبات بعد'),
            const SizedBox(height: DsSpacing.md),
            ErrorState(onRetry: () {}),
            const SizedBox(height: DsSpacing.xl),
            const SectionHeader(title: 'Avatars & Badges'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const DsAvatar(name: 'أحمد محمد'),
                const DsAvatar(
                  name: 'سارة علي',
                  ringColor: ZaWolfColors.wolfGreen,
                  size: 48,
                ),
                const DsBadge(count: 7),
                const DsBadge(count: 120),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
