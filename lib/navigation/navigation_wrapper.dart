import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/employee_role.dart';
import '../theme/theme.dart';

class NavigationWrapper extends StatelessWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return child; // Fallback
    }

    final String matchedLocation = GoRouterState.of(context).matchedLocation;
    final String role = user.role;

    // Define tabs based on role
    List<NavigationItem> items = [];
    if (role == EmployeeRole.employee) {
      items = [
        NavigationItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'الرئيسية',
          englishLabel: 'Home',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'أدائي',
          englishLabel: 'Performance',
          path: '/employee/performance',
        ),
        NavigationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'حسابي',
          englishLabel: 'Profile',
          path: '/employee/profile',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'مقترحاتي',
          englishLabel: 'Suggestions',
          path: '/employee/suggestions',
        ),
      ];
    } else if (role == EmployeeRole.manager) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.dashboard_customize_outlined,
          activeIcon: Icons.dashboard_customize,
          label: 'لوحتي',
          englishLabel: 'Dashboard',
          path: '/manager/dashboard',
        ),
        NavigationItem(
          icon: Icons.rule_outlined,
          activeIcon: Icons.rule,
          label: 'الطلبات',
          englishLabel: 'Approvals',
          path: '/manager/requests',
        ),
        NavigationItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'فريقي',
          englishLabel: 'Team Attendance',
          path: '/manager/team',
        ),
        NavigationItem(
          icon: Icons.grade_outlined,
          activeIcon: Icons.grade,
          label: 'الأداء',
          englishLabel: 'Team Performance',
          path: '/manager/performance',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'المقترحات',
          englishLabel: 'Suggestions',
          path: '/manager/suggestions',
        ),
      ];
    } else if (role == EmployeeRole.hrAdmin) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'لوحة التحكم',
          englishLabel: 'Control Panel',
          path: '/hr/dashboard',
        ),
        NavigationItem(
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge,
          label: 'الموظفون',
          englishLabel: 'Employees',
          path: '/hr/employees',
        ),
        NavigationItem(
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt,
          label: 'المواقع',
          englishLabel: 'Locations',
          path: '/hr/locations',
        ),
        NavigationItem(
          icon: Icons.assessment_outlined,
          activeIcon: Icons.assessment,
          label: 'التقارير',
          englishLabel: 'Reports',
          path: '/hr/reports',
        ),
        NavigationItem(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign,
          label: 'الإعلانات',
          englishLabel: 'Announcements',
          path: '/hr/announcements',
        ),
        NavigationItem(
          icon: Icons.event_busy_outlined,
          activeIcon: Icons.event_busy,
          label: 'أيام العطلة',
          englishLabel: 'Days Off',
          path: '/hr/day-offs',
        ),
      ];
    } else if (role == EmployeeRole.superAdmin) {
      items = [
        NavigationItem(
          icon: Icons.fingerprint,
          activeIcon: Icons.fingerprint,
          label: 'حضوري',
          englishLabel: 'Attendance',
          path: '/employee/dashboard',
        ),
        NavigationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          label: 'طلباتي',
          englishLabel: 'Requests',
          path: '/employee/requests',
        ),
        NavigationItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'تحكم',
          englishLabel: 'Control',
          path: '/hr/dashboard',
        ),
        NavigationItem(
          icon: Icons.rule_outlined,
          activeIcon: Icons.rule,
          label: 'الموافقات',
          englishLabel: 'Approvals',
          path: '/manager/requests',
        ),
        NavigationItem(
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge,
          label: 'الموظفون',
          englishLabel: 'Employees',
          path: '/hr/employees',
        ),
        NavigationItem(
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt,
          label: 'المواقع',
          englishLabel: 'Locations',
          path: '/hr/locations',
        ),
        NavigationItem(
          icon: Icons.event_busy_outlined,
          activeIcon: Icons.event_busy,
          label: 'أيام العطلة',
          englishLabel: 'Days Off',
          path: '/hr/day-offs',
        ),
        NavigationItem(
          icon: Icons.lightbulb_outline,
          activeIcon: Icons.lightbulb,
          label: 'المقترحات',
          englishLabel: 'Suggestions',
          path: '/manager/suggestions',
        ),
      ];
    }

    final hasOverflow = items.length > 4;
    final bottomItems = hasOverflow
        ? [
            ...items.take(3),
            NavigationItem(
              icon: Icons.menu,
              activeIcon: Icons.menu_open,
              label: 'المزيد',
              englishLabel: 'More',
              path: '__more__',
            ),
          ]
        : items;
    final overflowItems = hasOverflow
        ? items.skip(3).toList()
        : <NavigationItem>[];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ZaWolfColors.surface01,
          border: Border(
            top: BorderSide(color: ZaWolfColors.borderGlow, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F00D4FF),
              blurRadius: 15,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: bottomItems.map((item) {
                final isMoreItem = item.path == '__more__';
                final isSelected = isMoreItem
                    ? overflowItems.any(
                        (extra) => extra.path == matchedLocation,
                      )
                    : item.path == matchedLocation;
                final accentColor = isSelected
                    ? ZaWolfColors.primaryCyan
                    : ZaWolfColors.textSecondary;

                Widget iconWidget = Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: accentColor,
                  size: 26,
                );

                // Show badge for notifications on Profile for employee, dashboard for manager/HR
                final unreadCount = user.unreadNotifications;
                final showBadge =
                    unreadCount > 0 &&
                    ((role == 'employee' && item.path == '/employee/profile') ||
                        (role == 'manager' &&
                            item.path == '/manager/dashboard') ||
                        (role == 'hr_admin' && item.path == '/hr/dashboard'));

                if (showBadge) {
                  iconWidget = Badge(
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: ZaWolfColors.error,
                    child: iconWidget,
                  );
                }

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (isMoreItem) {
                        _showMoreSheet(
                          context: context,
                          theme: theme,
                          items: overflowItems,
                          matchedLocation: matchedLocation,
                        );
                      } else if (!isSelected) {
                        context.go(item.path);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconWidget,
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.englishLabel.toUpperCase(),
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: isSelected
                                  ? ZaWolfColors.primaryCyan.withValues(
                                      alpha: 0.7,
                                    )
                                  : ZaWolfColors.textMuted,
                              fontSize: 7,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet({
    required BuildContext context,
    required ThemeData theme,
    required List<NavigationItem> items,
    required String matchedLocation,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'المزيد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final isSelected = item.path == matchedLocation;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected
                          ? ZaWolfColors.primaryCyan
                          : ZaWolfColors.textSecondary,
                    ),
                    title: Text(
                      item.label,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isSelected
                            ? ZaWolfColors.primaryCyan
                            : Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      item.englishLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: ZaWolfColors.textMuted),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (!isSelected) context.go(item.path);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String englishLabel;
  final String path;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.englishLabel,
    required this.path,
  });
}
