import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/employee_role.dart';
import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/privacy_policy_screen.dart';
import 'navigation_wrapper.dart';
import '../screens/employee/employee_dashboard.dart';
import '../screens/employee/employee_requests.dart';
import '../screens/employee/employee_kpi_screen.dart';
import '../screens/employee/employee_productivity_screen.dart';
import '../screens/employee/employee_tasks_screen.dart';
import '../screens/employee/employee_warnings_rewards_screen.dart';
import '../screens/employee/employee_payroll_screen.dart';
import '../screens/employee/profile_settings.dart';
import '../screens/employee/performance_view.dart';
import '../screens/employee/suggestions_screen.dart';
import '../screens/hr/company_day_offs_screen.dart';
import '../screens/hr/attendance_policy_settings_screen.dart';
import '../screens/hr/field_assignments_screen.dart';
import '../screens/hr/location_mgmt.dart';
import '../screens/hr/payroll_screen.dart';
import '../screens/manager/manager_dashboard.dart';
import '../screens/manager/kpi_mgmt.dart';
import '../screens/manager/productivity_ranking_screen.dart';
import '../screens/manager/requests_mgmt.dart';
import '../screens/manager/suggestions_mgmt.dart';
import '../screens/manager/tasks_mgmt.dart';
import '../screens/manager/team_attendance.dart';
import '../screens/manager/team_members_screen.dart';
import '../screens/manager/warnings_rewards_mgmt.dart';
import '../screens/hr/hr_dashboard.dart';
import '../screens/hr/attendance_summary_details_screen.dart';
import '../screens/hr/employee_mgmt.dart';
import '../screens/hr/announcements.dart';
import '../screens/hr/sheets_export_screen.dart';
import '../screens/manager/rate_performance.dart';
import '../screens/smart_assistant_screen.dart';
import '../screens/hr/department_performance_screen.dart';
import '../screens/shared/employee_insights_screen.dart';
import '../screens/team_leader/team_leader_dashboard.dart';
import '../screens/team_leader/team_tasks_screen.dart';

class ZaWolfRouter {
  static GoRouter getRouter(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authService,
      redirect: (BuildContext context, GoRouterState state) {
        final loggingIn = state.matchedLocation == '/login';
        final onSplash = state.matchedLocation == '/splash';
        final viewingPrivacy = state.matchedLocation == '/privacy';

        final authenticated = authService.isAuthenticated;
        if (authService.loading) {
          if (loggingIn && FirebaseAuth.instance.currentUser != null) {
            return '/splash';
          }
          return null;
        }

        // 1. Unauthenticated users must log in
        if (!authenticated) {
          if (!loggingIn && !onSplash && !viewingPrivacy) {
            return '/login';
          }
          return null;
        }

        // 2. Authenticated users should be sent to their dashboard if they hit splash or login
        if (loggingIn || onSplash) {
          final role = authService.currentUser?.role;
          if (role == EmployeeRole.superAdmin) return '/hr/dashboard';
          if (role == EmployeeRole.hrAdmin) return '/hr/dashboard';
          if (role == EmployeeRole.manager) return '/manager/dashboard';
          if (role == EmployeeRole.teamLeader) {
            return '/team-leader/dashboard';
          }
          return '/employee/dashboard';
        }

        // 3. Role Guards
        final role = authService.currentUser?.role;
        final goingToHr = state.matchedLocation.startsWith('/hr');
        final goingToManager = state.matchedLocation.startsWith('/manager');
        final goingToTeamLeader = state.matchedLocation.startsWith(
          '/team-leader',
        );

        if (role == EmployeeRole.superAdmin) {
          return null;
        }

        if (role == EmployeeRole.employee) {
          // Employees cannot access manager or hr paths
          if (goingToHr || goingToManager || goingToTeamLeader) {
            return '/employee/dashboard';
          }
        } else if (role == EmployeeRole.teamLeader) {
          if (goingToHr || goingToManager) {
            return '/team-leader/dashboard';
          }
        } else if (role == EmployeeRole.manager) {
          // Managers cannot access hr paths
          if (goingToHr) {
            return '/manager/dashboard';
          }
        } else if (role == EmployeeRole.hrAdmin) {
          // HR users cannot access manager-only paths.
          if (goingToManager) {
            return '/hr/dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),

        // Shell Route to wrap dashboard screens with bottom navigation
        ShellRoute(
          builder: (context, state, child) => NavigationWrapper(child: child),
          routes: [
            // Employee Routes
            GoRoute(
              path: '/employee/dashboard',
              builder: (context, state) => const EmployeeDashboardScreen(),
            ),
            GoRoute(
              path: '/employee/requests',
              builder: (context, state) => const EmployeeRequestsScreen(),
            ),
            GoRoute(
              path: '/employee/tasks',
              builder: (context, state) => const EmployeeTasksScreen(),
            ),
            GoRoute(
              path: '/employee/performance',
              builder: (context, state) =>
                  const EmployeePerformanceViewScreen(),
            ),
            GoRoute(
              path: '/employee/kpi',
              builder: (context, state) => const EmployeeKpiScreen(),
            ),
            GoRoute(
              path: '/employee/productivity',
              builder: (context, state) => const EmployeeProductivityScreen(),
            ),
            GoRoute(
              path: '/employee/profile',
              builder: (context, state) => const ProfileSettingsScreen(),
            ),
            GoRoute(
              path: '/employee/suggestions',
              builder: (context, state) => const EmployeeSuggestionsScreen(),
            ),
            GoRoute(
              path: '/employee/warnings-rewards',
              builder: (context, state) =>
                  const EmployeeWarningsRewardsScreen(),
            ),
            GoRoute(
              path: '/employee/payroll',
              builder: (context, state) => const EmployeePayrollScreen(),
            ),
            GoRoute(
              path: '/assistant',
              builder: (context, state) => const SmartAssistantScreen(),
            ),
            // Team Leader Routes (team visibility, no approval actions)
            GoRoute(
              path: '/team-leader/dashboard',
              builder: (context, state) => const TeamLeaderDashboardScreen(),
            ),
            GoRoute(
              path: '/team-leader/attendance-summary',
              builder: (context, state) =>
                  const AttendanceSummaryDetailsScreen(),
            ),
            GoRoute(
              path: '/team-leader/employees',
              builder: (context, state) => const TeamMembersScreen(),
            ),
            GoRoute(
              path: '/team-leader/tasks',
              builder: (context, state) => const TeamLeaderTasksScreen(),
            ),
            GoRoute(
              path: '/team-leader/employee/:userId',
              builder: (context, state) => EmployeeInsightsScreen(
                employeeUid: state.pathParameters['userId']!,
              ),
            ),
            // Manager Routes
            GoRoute(
              path: '/manager/dashboard',
              builder: (context, state) => const ManagerDashboardScreen(),
            ),
            GoRoute(
              path: '/manager/attendance-summary',
              builder: (context, state) =>
                  const AttendanceSummaryDetailsScreen(),
            ),
            GoRoute(
              path: '/manager/requests',
              builder: (context, state) => const RequestsManagementScreen(),
            ),
            GoRoute(
              path: '/manager/tasks',
              builder: (context, state) => const TasksManagementScreen(),
            ),
            GoRoute(
              path: '/manager/team',
              builder: (context, state) => const TeamAttendanceScreen(),
            ),
            GoRoute(
              path: '/manager/employees',
              builder: (context, state) => const TeamMembersScreen(),
            ),
            GoRoute(
              path: '/manager/employee/:userId',
              builder: (context, state) => EmployeeInsightsScreen(
                employeeUid: state.pathParameters['userId']!,
              ),
            ),
            GoRoute(
              path: '/manager/performance',
              builder: (context, state) => const RatePerformanceScreen(),
            ),
            GoRoute(
              path: '/manager/kpi',
              builder: (context, state) => const KpiManagementScreen(),
            ),
            GoRoute(
              path: '/manager/productivity',
              builder: (context, state) => const ProductivityRankingScreen(),
            ),
            GoRoute(
              path: '/manager/departments',
              builder: (context, state) => const DepartmentPerformanceScreen(),
            ),
            GoRoute(
              path: '/manager/suggestions',
              builder: (context, state) => const SuggestionsManagementScreen(),
            ),
            GoRoute(
              path: '/manager/warnings-rewards',
              builder: (context, state) =>
                  const WarningsRewardsManagementScreen(),
            ),
            // HR Admin Routes
            GoRoute(
              path: '/hr/dashboard',
              builder: (context, state) => const HrDashboardScreen(),
            ),
            GoRoute(
              path: '/hr/attendance-summary',
              builder: (context, state) =>
                  const AttendanceSummaryDetailsScreen(),
            ),
            GoRoute(
              path: '/hr/requests',
              builder: (context, state) => const RequestsManagementScreen(),
            ),
            GoRoute(
              path: '/hr/employees',
              builder: (context, state) => const EmployeeManagementScreen(),
            ),
            GoRoute(
              path: '/hr/employee/:userId',
              builder: (context, state) => EmployeeInsightsScreen(
                employeeUid: state.pathParameters['userId']!,
              ),
            ),
            GoRoute(
              path: '/hr/locations',
              builder: (context, state) => const LocationManagementScreen(),
            ),
            GoRoute(
              path: '/hr/reports',
              builder: (context, state) => const SheetsExportScreen(),
            ),
            GoRoute(
              path: '/hr/payroll',
              builder: (context, state) => const PayrollScreen(),
            ),
            GoRoute(
              path: '/hr/tasks',
              builder: (context, state) => const TasksManagementScreen(),
            ),
            GoRoute(
              path: '/hr/kpi',
              builder: (context, state) => const KpiManagementScreen(),
            ),
            GoRoute(
              path: '/hr/productivity',
              builder: (context, state) => const ProductivityRankingScreen(),
            ),
            GoRoute(
              path: '/hr/departments',
              builder: (context, state) => const DepartmentPerformanceScreen(),
            ),
            GoRoute(
              path: '/hr/warnings-rewards',
              builder: (context, state) =>
                  const WarningsRewardsManagementScreen(),
            ),
            GoRoute(
              path: '/hr/announcements',
              builder: (context, state) => const AnnouncementsScreen(),
            ),
            GoRoute(
              path: '/hr/day-offs',
              builder: (context, state) => const CompanyDayOffsScreen(),
            ),
            GoRoute(
              path: '/hr/attendance-policy',
              builder: (context, state) =>
                  const AttendancePolicySettingsScreen(),
            ),
            GoRoute(
              path: '/hr/field-assignments',
              builder: (context, state) => const FieldAssignmentsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
