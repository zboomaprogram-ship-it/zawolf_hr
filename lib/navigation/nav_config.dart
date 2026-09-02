import 'package:flutter/material.dart';

import '../models/employee_role.dart';

/// Single source of truth for role-filtered navigation, consumed by both the
/// mobile bottom-nav shell and the desktop web sidebar shell.
/// Specs: specs/ui_redesign/02_navigation_ia_spec.md

enum NavDomain { home, time, approvals, payroll, performance, people }

extension NavDomainX on NavDomain {
  String get arabicLabel => switch (this) {
    NavDomain.home => 'الرئيسية',
    NavDomain.time => 'الحضور',
    NavDomain.approvals => 'الطلبات',
    NavDomain.payroll => 'الرواتب',
    NavDomain.performance => 'الأداء',
    NavDomain.people => 'الأشخاص',
  };

  String get englishLabel => switch (this) {
    NavDomain.home => 'Home',
    NavDomain.time => 'Time & Attendance',
    NavDomain.approvals => 'Approvals',
    NavDomain.payroll => 'Payroll',
    NavDomain.performance => 'Performance',
    NavDomain.people => 'People',
  };

  IconData get icon => switch (this) {
    NavDomain.home => Icons.home_outlined,
    NavDomain.time => Icons.fingerprint,
    NavDomain.approvals => Icons.assignment_outlined,
    NavDomain.payroll => Icons.payments_outlined,
    NavDomain.performance => Icons.bar_chart_outlined,
    NavDomain.people => Icons.people_outline,
  };

  IconData get activeIcon => switch (this) {
    NavDomain.home => Icons.home,
    NavDomain.time => Icons.fingerprint,
    NavDomain.approvals => Icons.assignment,
    NavDomain.payroll => Icons.payments,
    NavDomain.performance => Icons.bar_chart,
    NavDomain.people => Icons.people,
  };
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String englishLabel;
  final String path;

  /// Domain grouping used by the web sidebar and grouped More sheet.
  /// Null-domain items (profile, assistant) surface in the top bar instead.
  final NavDomain? domain;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.englishLabel,
    required this.path,
    this.domain,
  });
}

class NavDomainGroup {
  final NavDomain domain;
  final List<NavigationItem> items;

  const NavDomainGroup(this.domain, this.items);
}

const List<NavDomain> _domainOrder = [
  NavDomain.home,
  NavDomain.time,
  NavDomain.approvals,
  NavDomain.payroll,
  NavDomain.performance,
  NavDomain.people,
];

/// Flat, role-scoped item list. Order within each role preserves the
/// legacy mobile ordering so bottom-nav behavior stays familiar.
List<NavigationItem> navItemsForRole(String role) {
  if (role == EmployeeRole.employee) {
    return _employeeItems();
  } else if (role == EmployeeRole.teamLeader) {
    return _teamLeaderItems();
  } else if (role == EmployeeRole.manager) {
    return _managerItems();
  } else if (role == EmployeeRole.hrAdmin) {
    return _hrItems();
  } else if (role == EmployeeRole.superAdmin ||
      role == EmployeeRole.hrManager) {
    return _superAdminItems();
  }
  return _employeeItems();
}

/// Groups flat items into domain groups in canonical order, skipping
/// null-domain items (profile/assistant).
List<NavDomainGroup> groupNavItems(List<NavigationItem> items) {
  return [
    for (final domain in _domainOrder)
      NavDomainGroup(
        domain,
        items.where((item) => item.domain == domain).toList(),
      ),
  ].where((group) => group.items.isNotEmpty).toList();
}

String homeRouteForRole(String role) {
  return switch (role) {
    EmployeeRole.superAdmin ||
    EmployeeRole.hrManager ||
    EmployeeRole.hrAdmin => '/hr/dashboard',
    EmployeeRole.manager => '/manager/dashboard',
    EmployeeRole.teamLeader => '/team-leader/dashboard',
    _ => '/employee/dashboard',
  };
}

/// Fixed four-tab sets per role for the mobile bottom nav.
List<NavigationItem> mobileTabsForRole(String role) {
  if (role == EmployeeRole.employee) {
    return [
      NavigationItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'الرئيسية',
        englishLabel: 'Home',
        path: '/employee/dashboard',
        domain: NavDomain.home,
      ),
      NavigationItem(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'طلباتي',
        englishLabel: 'Requests',
        path: '/employee/requests',
        domain: NavDomain.approvals,
      ),
      NavigationItem(
        icon: Icons.task_alt_outlined,
        activeIcon: Icons.task_alt,
        label: 'مهامي',
        englishLabel: 'Tasks',
        path: '/employee/tasks',
        domain: NavDomain.performance,
      ),
      NavigationItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'حسابي',
        englishLabel: 'Profile',
        path: '/employee/profile',
      ),
    ];
  }
  if (role == EmployeeRole.teamLeader) {
    return [
      NavigationItem(
        icon: Icons.groups_2_outlined,
        activeIcon: Icons.groups_2,
        label: 'فريقي',
        englishLabel: 'My Team',
        path: '/team-leader/dashboard',
        domain: NavDomain.home,
      ),
      NavigationItem(
        icon: Icons.fingerprint,
        activeIcon: Icons.fingerprint,
        label: 'الحضور',
        englishLabel: 'Attendance',
        path: '/employee/dashboard',
        domain: NavDomain.time,
      ),
      NavigationItem(
        icon: Icons.rule_outlined,
        activeIcon: Icons.rule,
        label: 'الموافقات',
        englishLabel: 'Approvals',
        path: '/team-leader/requests',
        domain: NavDomain.approvals,
      ),
      NavigationItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'حسابي',
        englishLabel: 'Profile',
        path: '/employee/profile',
      ),
    ];
  }
  if (role == EmployeeRole.manager) {
    return [
      NavigationItem(
        icon: Icons.dashboard_customize_outlined,
        activeIcon: Icons.dashboard_customize,
        label: 'لوحتي',
        englishLabel: 'Dashboard',
        path: '/manager/dashboard',
        domain: NavDomain.home,
      ),
      NavigationItem(
        icon: Icons.fingerprint,
        activeIcon: Icons.fingerprint,
        label: 'الحضور',
        englishLabel: 'Attendance',
        path: '/employee/dashboard',
        domain: NavDomain.time,
      ),
      NavigationItem(
        icon: Icons.rule_outlined,
        activeIcon: Icons.rule,
        label: 'الموافقات',
        englishLabel: 'Approvals',
        path: '/manager/requests',
        domain: NavDomain.approvals,
      ),
      NavigationItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'حسابي',
        englishLabel: 'Profile',
        path: '/employee/profile',
      ),
    ];
  }
  // HR family
  return [
    NavigationItem(
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings,
      label: 'الرئيسية',
      englishLabel: 'Control Panel',
      path: '/hr/dashboard',
      domain: NavDomain.home,
    ),
    NavigationItem(
      icon: Icons.fingerprint,
      activeIcon: Icons.fingerprint,
      label: 'الحضور',
      englishLabel: 'Attendance',
      path: '/employee/dashboard',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.rule_outlined,
      activeIcon: Icons.rule,
      label: 'الطلبات',
      englishLabel: 'Approvals',
      path: '/hr/requests',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'حسابي',
      englishLabel: 'Profile',
      path: '/employee/profile',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Role item definitions (paths preserved from legacy wrapper)

NavigationItem _myAttendance() => NavigationItem(
  icon: Icons.fingerprint,
  activeIcon: Icons.fingerprint,
  label: 'حضوري',
  englishLabel: 'Attendance',
  path: '/employee/dashboard',
  domain: NavDomain.home,
);

NavigationItem _myRequests() => NavigationItem(
  icon: Icons.assignment_outlined,
  activeIcon: Icons.assignment,
  label: 'طلباتي',
  englishLabel: 'Requests',
  path: '/employee/requests',
  domain: NavDomain.approvals,
);

NavigationItem _myTasks(String label) => NavigationItem(
  icon: Icons.task_alt_outlined,
  activeIcon: Icons.task_alt,
  label: label,
  englishLabel: 'My Tasks',
  path: '/employee/tasks',
  domain: NavDomain.performance,
);

NavigationItem _myProfile() => NavigationItem(
  icon: Icons.person_outline,
  activeIcon: Icons.person,
  label: 'حسابي',
  englishLabel: 'Profile',
  path: '/employee/profile',
);

NavigationItem _teamAnnouncement() => NavigationItem(
  icon: Icons.campaign_outlined,
  activeIcon: Icons.campaign,
  label: 'إعلان للفريق',
  englishLabel: 'Team Announcement',
  path: '/hr/announcements',
  domain: NavDomain.people,
);

NavigationItem _departmentChat() => NavigationItem(
  icon: Icons.chat_bubble_outline_rounded,
  activeIcon: Icons.chat_rounded,
  label: 'محادثات القسم',
  englishLabel: 'Department Chat',
  path: '/conversations/department/general',
  domain: NavDomain.people,
);

List<NavigationItem> _employeeItems() {
  return [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'الرئيسية',
      englishLabel: 'Home',
      path: '/employee/dashboard',
      domain: NavDomain.home,
    ),
    _myRequests(),
    _myTasks('مهامي'),
    NavigationItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'أدائي',
      englishLabel: 'Performance',
      path: '/employee/performance',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      label: 'KPI',
      englishLabel: 'Goals',
      path: '/employee/kpi',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'إنتاجيتي',
      englishLabel: 'Productivity',
      path: '/employee/productivity',
      domain: NavDomain.performance,
    ),
    _myProfile(),
    NavigationItem(
      icon: Icons.workspace_premium_outlined,
      activeIcon: Icons.workspace_premium,
      label: 'السجل',
      englishLabel: 'Records',
      path: '/employee/warnings-rewards',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'راتبي',
      englishLabel: 'Payroll',
      path: '/employee/payroll',
      domain: NavDomain.payroll,
    ),
    NavigationItem(
      icon: Icons.lightbulb_outline,
      activeIcon: Icons.lightbulb,
      label: 'مقترحاتي',
      englishLabel: 'Suggestions',
      path: '/employee/suggestions',
      domain: NavDomain.approvals,
    ),
    _departmentChat(),
  ];
}

List<NavigationItem> _teamLeaderItems() {
  return [
    NavigationItem(
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2,
      label: 'فريقي',
      englishLabel: 'My Team',
      path: '/team-leader/dashboard',
      domain: NavDomain.home,
    ),
    _myRequests(),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'الأعضاء',
      englishLabel: 'Members',
      path: '/team-leader/employees',
      domain: NavDomain.people,
    ),
    NavigationItem(
      icon: Icons.rule_outlined,
      activeIcon: Icons.rule,
      label: 'موافقات الفريق',
      englishLabel: 'Team Approvals',
      path: '/team-leader/requests',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      label: 'مهام الفريق',
      englishLabel: 'Team Tasks',
      path: '/team-leader/tasks',
      domain: NavDomain.performance,
    ),
    _teamAnnouncement(),
    _departmentChat(),
    _myTasks('مهامي'),
    _myProfile(),
  ];
}

List<NavigationItem> _managerItems() {
  return [
    _myAttendance(),
    _myRequests(),
    NavigationItem(
      icon: Icons.dashboard_customize_outlined,
      activeIcon: Icons.dashboard_customize,
      label: 'لوحتي',
      englishLabel: 'Dashboard',
      path: '/manager/dashboard',
      domain: NavDomain.home,
    ),
    NavigationItem(
      icon: Icons.rule_outlined,
      activeIcon: Icons.rule,
      label: 'الطلبات',
      englishLabel: 'Team Approvals',
      path: '/manager/requests',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      label: 'المهام',
      englishLabel: 'Tasks',
      path: '/manager/tasks',
      domain: NavDomain.performance,
    ),
    _teamAnnouncement(),
    NavigationItem(
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2,
      label: 'فريقي',
      englishLabel: 'Team Attendance',
      path: '/manager/team',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.grade_outlined,
      activeIcon: Icons.grade,
      label: 'الأداء',
      englishLabel: 'Team Performance',
      path: '/manager/performance',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      label: 'KPI',
      englishLabel: 'Goals',
      path: '/manager/kpi',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
      label: 'الإنتاجية',
      englishLabel: 'Ranking',
      path: '/manager/productivity',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.domain_outlined,
      activeIcon: Icons.domain,
      label: 'الأقسام',
      englishLabel: 'Departments',
      path: '/manager/departments',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.lightbulb_outline,
      activeIcon: Icons.lightbulb,
      label: 'المقترحات',
      englishLabel: 'Suggestions',
      path: '/manager/suggestions',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.workspace_premium_outlined,
      activeIcon: Icons.workspace_premium,
      label: 'السجلات',
      englishLabel: 'Records',
      path: '/manager/warnings-rewards',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'المساعد',
      englishLabel: 'Assistant',
      path: '/assistant',
    ),
    _departmentChat(),
    _myProfile(),
  ];
}

List<NavigationItem> _hrItems() {
  return [
    _myAttendance(),
    _myRequests(),
    NavigationItem(
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings,
      label: 'لوحة التحكم',
      englishLabel: 'Control Panel',
      path: '/hr/dashboard',
      domain: NavDomain.home,
    ),
    NavigationItem(
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge,
      label: 'الموظفون',
      englishLabel: 'Employees',
      path: '/hr/employees',
      domain: NavDomain.people,
    ),
    NavigationItem(
      icon: Icons.add_location_alt_outlined,
      activeIcon: Icons.add_location_alt,
      label: 'المواقع',
      englishLabel: 'Locations',
      path: '/hr/locations',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'الرواتب',
      englishLabel: 'Payroll',
      path: '/hr/payroll',
      domain: NavDomain.payroll,
    ),
    NavigationItem(
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      label: 'المهام',
      englishLabel: 'Tasks',
      path: '/hr/tasks',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      label: 'KPI',
      englishLabel: 'Goals',
      path: '/hr/kpi',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
      label: 'الإنتاجية',
      englishLabel: 'Ranking',
      path: '/hr/productivity',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.domain_outlined,
      activeIcon: Icons.domain,
      label: 'الأقسام',
      englishLabel: 'Departments',
      path: '/hr/departments',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.workspace_premium_outlined,
      activeIcon: Icons.workspace_premium,
      label: 'السجلات',
      englishLabel: 'Records',
      path: '/hr/warnings-rewards',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      label: 'الإعلانات',
      englishLabel: 'Announcements',
      path: '/hr/announcements',
      domain: NavDomain.people,
    ),
    NavigationItem(
      icon: Icons.event_busy_outlined,
      activeIcon: Icons.event_busy,
      label: 'أيام العطلة',
      englishLabel: 'Days Off',
      path: '/hr/day-offs',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'المساعد',
      englishLabel: 'Assistant',
      path: '/assistant',
    ),
    _departmentChat(),
    _myProfile(),
  ];
}

List<NavigationItem> _superAdminItems() {
  return [
    _myAttendance(),
    _myRequests(),
    NavigationItem(
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings,
      label: 'تحكم',
      englishLabel: 'Control',
      path: '/hr/dashboard',
      domain: NavDomain.home,
    ),
    NavigationItem(
      icon: Icons.rule_outlined,
      activeIcon: Icons.rule,
      label: 'الموافقات',
      englishLabel: 'Approvals',
      path: '/manager/requests',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      label: 'المهام',
      englishLabel: 'Tasks',
      path: '/manager/tasks',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      label: 'الإعلانات',
      englishLabel: 'Announcements',
      path: '/hr/announcements',
      domain: NavDomain.people,
    ),
    NavigationItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      label: 'KPI',
      englishLabel: 'Goals',
      path: '/manager/kpi',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
      label: 'الإنتاجية',
      englishLabel: 'Ranking',
      path: '/manager/productivity',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.domain_outlined,
      activeIcon: Icons.domain,
      label: 'الأقسام',
      englishLabel: 'Departments',
      path: '/hr/departments',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge,
      label: 'الموظفون',
      englishLabel: 'Employees',
      path: '/hr/employees',
      domain: NavDomain.people,
    ),
    NavigationItem(
      icon: Icons.assessment_outlined,
      activeIcon: Icons.assessment,
      label: 'التقارير',
      englishLabel: 'Reports',
      path: '/hr/reports',
      domain: NavDomain.payroll,
    ),
    NavigationItem(
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'الرواتب',
      englishLabel: 'Payroll',
      path: '/hr/payroll',
      domain: NavDomain.payroll,
    ),
    NavigationItem(
      icon: Icons.add_location_alt_outlined,
      activeIcon: Icons.add_location_alt,
      label: 'المواقع',
      englishLabel: 'Locations',
      path: '/hr/locations',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.event_busy_outlined,
      activeIcon: Icons.event_busy,
      label: 'أيام العطلة',
      englishLabel: 'Days Off',
      path: '/hr/day-offs',
      domain: NavDomain.time,
    ),
    NavigationItem(
      icon: Icons.lightbulb_outline,
      activeIcon: Icons.lightbulb,
      label: 'المقترحات',
      englishLabel: 'Suggestions',
      path: '/manager/suggestions',
      domain: NavDomain.approvals,
    ),
    NavigationItem(
      icon: Icons.workspace_premium_outlined,
      activeIcon: Icons.workspace_premium,
      label: 'السجلات',
      englishLabel: 'Records',
      path: '/manager/warnings-rewards',
      domain: NavDomain.performance,
    ),
    NavigationItem(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'المساعد',
      englishLabel: 'Assistant',
      path: '/assistant',
    ),
    _departmentChat(),
    _myProfile(),
  ];
}
