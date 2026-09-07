import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/feature_flags/company_workspace_feature_flag.dart';
import '../core/feature_flags/phase007_feature_flags.dart';
import '../core/feature_flags/company_os_feature_flags.dart';
import '../features/company_os/domain/entities/operational_request_category.dart';
import '../models/employee_role.dart';
import '../navigation/nav_config.dart';
import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import 'rich_conversation_entry.dart';
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
import '../screens/employee/employee_deductions_screen.dart';
import '../screens/employee/profile_settings.dart';
import '../screens/employee/performance_view.dart';
import '../screens/employee/suggestions_screen.dart';
import '../screens/hr/company_day_offs_screen.dart';
import '../screens/hr/attendance_policy_settings_screen.dart';
import '../screens/hr/field_assignments_screen.dart';
import '../features/manual_attendance/data/manual_attendance_repository_impl.dart';
import '../features/manual_attendance/presentation/manual_attendance_screen.dart';
import '../features/meeting_requests/data/meeting_repository_impl.dart';
import '../features/meeting_requests/presentation/meeting_request_screen.dart';
import '../features/meeting_requests/presentation/meeting_rooms_management_screen.dart';
import '../features/meeting_requests/presentation/meeting_requests_list_screen.dart';
import '../features/configurable_requests/data/configurable_requests_repository_impl.dart';
import '../features/configurable_requests/presentation/custom_request_screens.dart';
import '../screens/hr/location_mgmt.dart';
import '../screens/hr/payroll_screen.dart';
import '../screens/hr/custom_badges_screen.dart';
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
import '../screens/hr/google_workspace_screen.dart';
import '../screens/manager/rate_performance.dart';
import '../screens/smart_assistant_screen.dart';
import '../screens/hr/department_performance_screen.dart';
import '../screens/shared/employee_insights_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/polls_screen.dart';
import '../screens/shared/company_workspace_center_screen.dart';
import '../screens/shared/hubs/domain_hub_screen.dart';
import '../screens/account_disabled_screen.dart';
import '../screens/team_leader/team_leader_dashboard.dart';
import 'company_workspace_v2_entry.dart';
import 'developer_tools_entry.dart';
import 'diagnostics_report_entry.dart';
import 'employee_operations_entry.dart';
import 'employee_assistant_entry.dart';
import 'operational_visibility_entry.dart';
import 'company_os_entry.dart';
import 'company_os_it_entry.dart';
import 'company_os_operations_entry.dart';
import 'company_os_requests_entry.dart';
import 'company_os_organization_entry.dart';

class ZaWolfRouter {
  static GoRouter getRouter(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final workspaceV2 = Provider.of<CompanyWorkspaceFeatureFlag>(
      context,
      listen: false,
    );
    final phase007 = Provider.of<Phase007FeatureFlags>(context, listen: false);
    final companyOs = Provider.of<CompanyOsFeatureFlags>(
      context,
      listen: false,
    );

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: Listenable.merge([
        authService,
        workspaceV2.changes,
        phase007.changes,
        companyOs.changes,
      ]),
      redirect: (BuildContext context, GoRouterState state) {
        final loggingIn = state.matchedLocation == '/login';
        final onSplash = state.matchedLocation == '/splash';
        final viewingPrivacy = state.matchedLocation == '/privacy';
        final viewingTerms = state.matchedLocation == '/terms';
        final viewingDisabled = state.matchedLocation == '/account-disabled';

        final authenticated = authService.isAuthenticated;
        if (authService.loading) {
          if (loggingIn && FirebaseAuth.instance.currentUser != null) {
            return '/splash';
          }
          return null;
        }

        // 1. Unauthenticated users must log in
        if (!authenticated) {
          if (!loggingIn && !onSplash && !viewingPrivacy && !viewingTerms) {
            return '/login';
          }
          return null;
        }

        if (authService.currentUser?.isActive == false) {
          return viewingDisabled ? null : '/account-disabled';
        }
        if (viewingDisabled) {
          return '/splash';
        }

        // 2. Authenticated users should be sent to their dashboard if they hit splash or login
        if (loggingIn || onSplash) {
          final role = authService.currentUser?.role;
          if (role == EmployeeRole.superAdmin) return '/hr/dashboard';
          if (EmployeeRole.isHrStaff(role)) return '/hr/dashboard';
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
        final goingToReports = state.matchedLocation == '/hr/reports';

        if (goingToReports && !EmployeeRole.canAccessReports(role)) {
          return '/hr/dashboard';
        }

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
        } else if (EmployeeRole.isHrStaff(role)) {
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
        GoRoute(
          path: '/terms',
          builder: (context, state) => const TermsConditionsScreen(),
        ),
        GoRoute(
          path: '/account-disabled',
          builder: (context, state) => const AccountDisabledScreen(),
        ),

        // Shell Route to wrap dashboard screens with bottom navigation
        ShellRoute(
          builder: (context, state, child) => NavigationWrapper(child: child),
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/conversations',
              builder:
                  (context, state) => const RichConversationEntry(),
            ),
            GoRoute(
              path: '/conversations/channel/:channelId',
              builder:
                  (context, state) => RichConversationEntry(
                    channelId: state.pathParameters['channelId']!,
                    channelName: state.uri.queryParameters['name'],
                  ),
            ),
            GoRoute(
              path: '/conversations/department/:channelId',
              builder:
                  (context, state) => RichConversationEntry(
                    department: state.pathParameters['channelId']!,
                    channelName: state.uri.queryParameters['name'],
                  ),
            ),
            GoRoute(
              path: '/conversations/managers',
              builder:
                  (context, state) => const RichConversationEntry(
                    department: 'manager-channel',
                    channelName: 'قناة المديرين',
                  ),
            ),
            GoRoute(
              path: '/operations/employee/:employeeUserId',
              redirect: (context, state) {
                final actor = authService.currentUser;
                final target = state.pathParameters['employeeUserId'] ?? '';
                if (actor == null || target.isEmpty) return '/splash';
                final enabled = phase007.isEnabledFor(
                  feature: Phase007Feature.operationalVisibility,
                  actorId: actor.uid,
                );
                if (!enabled) return null;
                if (actor.role == EmployeeRole.employee &&
                    actor.uid != target) {
                  return '/employee/dashboard';
                }
                return null;
              },
              builder: (context, state) {
                final actor = authService.currentUser!;
                final target = state.pathParameters['employeeUserId']!;
                final enabled = phase007.isEnabledFor(
                  feature: Phase007Feature.operationalVisibility,
                  actorId: actor.uid,
                );
                if (!enabled) {
                  return const Scaffold(
                    body: Center(child: Text('هذه الميزة غير مفعلة حالياً.')),
                  );
                }
                return OperationalVisibilityEntry(
                  employeeUserId: target,
                  canManageVisibility:
                      actor.role == EmployeeRole.superAdmin ||
                      EmployeeRole.isHrStaff(actor.role),
                );
              },
            ),
            GoRoute(
              path: '/polls',
              builder: (context, state) => const PollsScreen(),
            ),
            GoRoute(
              path: '/workspace',
              builder: (context, state) {
                if (!kIsWeb) return const _WorkspaceWebOnlyPage();
                final actorId = FirebaseAuth.instance.currentUser?.uid ?? '';
                return workspaceV2.isEnabledFor(actorId: actorId)
                    ? CompanyWorkspaceV2Entry(actorId: actorId)
                    : const CompanyWorkspaceCenterScreen();
              },
            ),
            // HR report discovery stays behind the same safe V2 switch. The
            // legacy workspace remains the rollback destination until pilot
            // evidence and the owner's default-route approval exist.
            GoRoute(
              path: '/hr/workspace-reports',
              redirect: (_, __) => '/workspace',
            ),
            // Employee Routes
            GoRoute(
              path: '/employee/dashboard',
              builder: (context, state) => const EmployeeDashboardScreen(),
            ),
            GoRoute(
              path: '/company-os',
              builder: (context, state) => const CompanyOsEntry(),
            ),
            for (final route in const <(String, CompanyOsItSurface)>[
              ('/company-os/it', CompanyOsItSurface.tickets),
              ('/company-os/it/assets', CompanyOsItSurface.assets),
              ('/company-os/it/licenses', CompanyOsItSurface.licenses),
            ])
              GoRoute(
                path: route.$1,
                builder:
                    (context, state) => CompanyOsItEntry(surface: route.$2),
              ),
            for (final route in const <(String, CompanyOsOperationsSurface)>[
              ('/company-os/operations', CompanyOsOperationsSurface.dashboard),
              (
                '/company-os/operations/search',
                CompanyOsOperationsSurface.search,
              ),
              (
                '/company-os/operations/reports',
                CompanyOsOperationsSurface.reports,
              ),
              (
                '/company-os/operations/audit',
                CompanyOsOperationsSurface.audit,
              ),
            ])
              GoRoute(
                path: route.$1,
                builder: (_, __) => CompanyOsOperationsEntry(surface: route.$2),
              ),
            GoRoute(
              path: '/employee/requests',
              builder:
                  (context, state) => EmployeeRequestsScreen(
                    initialView:
                        state.uri.queryParameters['view'] == 'history' ? 2 : 1,
                  ),
            ),
            GoRoute(
              path: '/employee/requests/operational/new',
              builder:
                  (_, state) => CompanyOsRequestsEntry(
                    surface: CompanyOsRequestSurface.create,
                    initialCategory: switch (state
                        .uri
                        .queryParameters['category']) {
                      'technical' => OperationalRequestCategory.technical,
                      'financial' => OperationalRequestCategory.financial,
                      _ => null,
                    },
                  ),
            ),
            GoRoute(
              path: '/employee/requests/operational/:requestId',
              builder:
                  (_, state) => CompanyOsRequestsEntry(
                    surface: CompanyOsRequestSurface.detail,
                    requestId: state.pathParameters['requestId'],
                  ),
            ),
            GoRoute(
              path: '/manager/requests/operational/:requestId',
              builder:
                  (_, state) => CompanyOsRequestsEntry(
                    surface: CompanyOsRequestSurface.detail,
                    requestId: state.pathParameters['requestId'],
                    canDecide: true,
                  ),
            ),
            GoRoute(
              path: '/hr/requests/operational/:requestId',
              builder:
                  (_, state) => CompanyOsRequestsEntry(
                    surface: CompanyOsRequestSurface.detail,
                    requestId: state.pathParameters['requestId'],
                    canDecide: true,
                  ),
            ),
            GoRoute(
              path: '/requests/operational/:requestId',
              builder:
                  (_, state) => CompanyOsRequestsEntry(
                    surface: CompanyOsRequestSurface.detail,
                    requestId: state.pathParameters['requestId'],
                    canDecide:
                        authService.currentUser?.role != EmployeeRole.employee,
                  ),
            ),
            GoRoute(
              path: '/employee/tasks',
              builder: (context, state) {
                final actorId = authService.currentUser?.uid ?? '';
                final enabled =
                    actorId.isNotEmpty &&
                    phase007.isEnabledFor(
                      feature: Phase007Feature.workOutcomes,
                      actorId: actorId,
                    );
                return enabled
                    ? WorkOutcomesEntry(actorUserId: actorId)
                    : const EmployeeTasksScreen();
              },
            ),
            GoRoute(
              path: '/employee/performance',
              builder:
                  (context, state) => const EmployeePerformanceViewScreen(),
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
              path: '/developer-tools',
              builder: (context, state) => const DeveloperToolsEntry(),
            ),
            GoRoute(
              path: '/hr/developer-tools',
              builder: (context, state) => const DeveloperToolsAdminEntry(),
            ),
            GoRoute(
              path: '/hr/diagnostics',
              builder: (context, state) {
                final actorId = authService.currentUser?.uid ?? '';
                final enabled =
                    actorId.isNotEmpty &&
                    phase007.isEnabledFor(
                      feature: Phase007Feature.diagnostics,
                      actorId: actorId,
                    );
                return enabled
                    ? const DiagnosticsReportEntry()
                    : const HrDashboardScreen();
              },
            ),
            GoRoute(
              path: '/employee/suggestions',
              builder: (context, state) => const EmployeeSuggestionsScreen(),
            ),
            GoRoute(
              path: '/employee/warnings-rewards',
              builder:
                  (context, state) => const EmployeeWarningsRewardsScreen(),
            ),
            GoRoute(
              path: '/employee/payroll',
              builder: (context, state) => const EmployeePayrollScreen(),
            ),
            GoRoute(
              path: '/employee/deductions',
              builder: (context, state) {
                final employeeUserId = authService.currentUser?.uid ?? '';
                final enabled =
                    employeeUserId.isNotEmpty &&
                    phase007.isEnabledFor(
                      feature: Phase007Feature.employeeOperations,
                      actorId: employeeUserId,
                    );
                if (!enabled) return const EmployeeDeductionsScreen();
                return EmployeeDeductionDetailsEntry(
                  employeeUserId: employeeUserId,
                  initialCycleKey: state.uri.queryParameters['cycle'],
                );
              },
            ),
            GoRoute(
              path: '/assistant',
              builder: (context, state) {
                final actorId = authService.currentUser?.uid ?? '';
                final enabled =
                    actorId.isNotEmpty &&
                    phase007.isEnabledFor(
                      feature: Phase007Feature.employeeAssistant,
                      actorId: actorId,
                    );
                return enabled
                    ? const EmployeeAssistantEntry()
                    : const SmartAssistantScreen();
              },
            ),
            // Team Leader Routes
            GoRoute(
              path: '/team-leader/dashboard',
              builder: (context, state) => const TeamLeaderDashboardScreen(),
            ),
            GoRoute(
              path: '/team-leader/attendance-summary',
              builder:
                  (context, state) => AttendanceSummaryDetailsScreen(
                    initialStatus: state.uri.queryParameters['status'],
                  ),
            ),
            GoRoute(
              path: '/team-leader/employees',
              builder: (context, state) => const TeamMembersScreen(),
            ),
            GoRoute(
              path: '/team-leader/tasks',
              builder: (context, state) => const TasksManagementScreen(),
            ),
            GoRoute(
              path: '/team-leader/requests',
              builder:
                  (context, state) => RequestsManagementScreen(
                    initialCategory:
                        state.uri.queryParameters['category'] ??
                        state.uri.queryParameters['tab'],
                    initialRequestId: state.uri.queryParameters['requestId'],
                    smartTabSelect:
                        state.uri.queryParameters['smart'] == 'true' ||
                        state.uri.queryParameters.isEmpty,
                  ),
            ),
            GoRoute(
              path: '/team-leader/employee/:userId',
              builder:
                  (context, state) => EmployeeInsightsScreen(
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
              builder:
                  (context, state) => AttendanceSummaryDetailsScreen(
                    initialStatus: state.uri.queryParameters['status'],
                  ),
            ),
            GoRoute(
              path: '/manager/requests',
              builder:
                  (context, state) => RequestsManagementScreen(
                    initialCategory:
                        state.uri.queryParameters['category'] ??
                        state.uri.queryParameters['tab'],
                    initialRequestId: state.uri.queryParameters['requestId'],
                    smartTabSelect:
                        state.uri.queryParameters['smart'] == 'true' ||
                        state.uri.queryParameters.isEmpty,
                  ),
            ),
            GoRoute(
              path: '/manager/tasks',
              builder: (context, state) {
                final actorId = authService.currentUser?.uid ?? '';
                final enabled =
                    actorId.isNotEmpty &&
                    phase007.isEnabledFor(
                      feature: Phase007Feature.workOutcomes,
                      actorId: actorId,
                    );
                return enabled
                    ? WorkOutcomesEntry(
                      actorUserId: actorId,
                      mode: WorkOutcomesPageMode.manager,
                    )
                    : const TasksManagementScreen();
              },
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
              builder:
                  (context, state) => EmployeeInsightsScreen(
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
              builder:
                  (context, state) => const WarningsRewardsManagementScreen(),
            ),
            // HR Admin Routes
            GoRoute(
              path: '/hr/dashboard',
              builder: (context, state) => const HrDashboardScreen(),
            ),
            GoRoute(
              path: '/hr/attendance-summary',
              builder:
                  (context, state) => AttendanceSummaryDetailsScreen(
                    initialStatus: state.uri.queryParameters['status'],
                  ),
            ),
            GoRoute(
              path: '/hr/manual-attendance',
              builder:
                  (context, state) => ManualAttendanceScreen(
                    repository: ManualAttendanceRepositoryImpl(),
                  ),
            ),
            GoRoute(
              path: '/employee/meeting-request',
              builder:
                  (context, state) =>
                      MeetingRequestScreen(repository: MeetingRepositoryImpl()),
            ),
            GoRoute(
              path: '/meeting/history',
              builder:
                  (context, state) => MeetingRequestsListScreen(
                    repository: MeetingRepositoryImpl(),
                    approvalQueue: false,
                  ),
            ),
            GoRoute(
              path: '/meeting/approvals',
              builder:
                  (context, state) => MeetingRequestsListScreen(
                    repository: MeetingRepositoryImpl(),
                    approvalQueue: true,
                  ),
            ),
            GoRoute(
              path: '/hr/custom-request-types',
              builder:
                  (context, state) => CustomRequestTypesScreen(
                    repository: ConfigurableRequestsRepositoryImpl(),
                  ),
            ),
            GoRoute(
              path: '/employee/custom-requests',
              builder:
                  (context, state) => CustomRequestSubmissionScreen(
                    repository: ConfigurableRequestsRepositoryImpl(),
                  ),
            ),
            GoRoute(
              path: '/approver/custom-requests',
              builder:
                  (context, state) => CustomRequestQueueScreen(
                    repository: ConfigurableRequestsRepositoryImpl(),
                  ),
            ),
            GoRoute(
              path: '/hr/meeting-rooms',
              builder:
                  (context, state) => MeetingRoomsManagementScreen(
                    repository: MeetingRepositoryImpl(),
                  ),
            ),
            GoRoute(
              path: '/hr/requests',
              builder:
                  (context, state) => RequestsManagementScreen(
                    initialCategory:
                        state.uri.queryParameters['category'] ??
                        state.uri.queryParameters['tab'],
                    initialRequestId: state.uri.queryParameters['requestId'],
                    smartTabSelect:
                        state.uri.queryParameters['smart'] == 'true' ||
                        state.uri.queryParameters.isEmpty,
                  ),
            ),
            GoRoute(
              path: '/hr/employees',
              builder: (context, state) => const EmployeeManagementScreen(),
            ),
            GoRoute(
              path: '/hr/employee/:userId',
              builder:
                  (context, state) => EmployeeInsightsScreen(
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
              path: '/hr/google-workspace',
              builder:
                  (context, state) =>
                      kIsWeb
                          ? const GoogleWorkspaceScreen()
                          : const _WorkspaceWebOnlyPage(),
            ),
            // Domain hubs (additive, specs/ui_redesign/02)
            GoRoute(
              path: '/hub/time',
              builder:
                  (context, state) =>
                      const DomainHubScreen(domain: NavDomain.time),
            ),
            GoRoute(
              path: '/hub/approvals',
              builder:
                  (context, state) =>
                      const DomainHubScreen(domain: NavDomain.approvals),
            ),
            GoRoute(
              path: '/hub/payroll',
              builder:
                  (context, state) =>
                      const DomainHubScreen(domain: NavDomain.payroll),
            ),
            GoRoute(
              path: '/hub/performance',
              builder:
                  (context, state) =>
                      const DomainHubScreen(domain: NavDomain.performance),
            ),
            GoRoute(
              path: '/hub/people',
              builder:
                  (context, state) =>
                      const DomainHubScreen(domain: NavDomain.people),
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
              // Keep the live hierarchy and the additive multi-tree editor in
              // one page. The legacy tab remains the default rollback seam.
              builder:
                  (context, state) => DepartmentPerformanceScreen(
                    organizationTreesBuilder:
                        (_) => const CompanyOsOrganizationEntry(embedded: true),
                  ),
            ),
            GoRoute(
              path: '/hr/organization-trees',
              builder:
                  (context, state) => DepartmentPerformanceScreen(
                    initialTab: 1,
                    initialOrganizationTreesView: true,
                    organizationTreesBuilder:
                        (_) => const CompanyOsOrganizationEntry(embedded: true),
                  ),
            ),
            GoRoute(
              path: '/hr/warnings-rewards',
              builder:
                  (context, state) => const WarningsRewardsManagementScreen(),
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
              builder:
                  (context, state) => const AttendancePolicySettingsScreen(),
            ),
            GoRoute(
              path: '/hr/field-assignments',
              builder: (context, state) => const FieldAssignmentsScreen(),
            ),
            GoRoute(
              path: '/hr/custom-badges',
              builder: (context, state) => const CustomBadgesScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceWebOnlyPage extends StatelessWidget {
  const _WorkspaceWebOnlyPage();

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_outlined, size: 48),
              SizedBox(height: 16),
              Text(
                'ملفات الشركة وGoogle Workspace متاحان من لوحة الويب فقط.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
