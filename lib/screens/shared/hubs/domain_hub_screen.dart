import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../design_system/tokens.dart';
import '../../../theme/theme.dart';
import '../../../navigation/nav_config.dart';
import '../../../design_system/components/rtl_navigation.dart';

/// Generic domain hub: lists all role-scoped destinations of one NavDomain
/// as grouped link tiles. Presentation-only; reads no Firestore data.
/// Specs: specs/ui_redesign/02_navigation_ia_spec.md
class DomainHubScreen extends StatelessWidget {
  final NavDomain domain;

  const DomainHubScreen({super.key, required this.domain});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthService>().currentUser?.role;
    if (role == null) return const SizedBox.shrink();
    final items = navItemsForRole(role)
        .where((item) => item.domain == domain)
        .toList();

    // De-duplicate identical destinations while preserving first label.
    final seen = <String>{};
    final unique = [
      for (final item in items)
        if (seen.add(item.path)) item,
    ];

    return Scaffold(
      backgroundColor: ZaWolfColors.background,
      appBar: AppBar(
        title: Text(
          domain.arabicLabel,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        centerTitle: false,
      ),
      body: unique.isEmpty
          ? Center(
              child: Text(
                'لا توجد عناصر متاحة لهذا القسم',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(DsSpacing.lg),
              itemCount: unique.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (context, index) {
                final item = unique[index];
                final selected =
                    GoRouterState.of(context).matchedLocation == item.path;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: selected ? null : () => context.go(item.path),
                    borderRadius: DsRadius.cardBorder,
                    child: Container(
                      padding: const EdgeInsets.all(DsSpacing.lg),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface01,
                        borderRadius: DsRadius.cardBorder,
                        border: Border.all(
                          color: selected
                              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.4)
                              : ZaWolfColors.surface03,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  ZaWolfColors.primaryCyan.withValues(alpha: 0.10),
                              borderRadius: DsRadius.inputBorder,
                            ),
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 20,
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ),
                          const SizedBox(width: DsSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: DsSpacing.xs),
                                Text(
                                  item.englishLabel,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            RtlNavigation.chevronEnd(context),
                            color: ZaWolfColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Convenience list of the five non-home domains exposed as hub routes.
const List<NavDomain> kHubDomains = [
  NavDomain.time,
  NavDomain.approvals,
  NavDomain.payroll,
  NavDomain.performance,
  NavDomain.people,
];
