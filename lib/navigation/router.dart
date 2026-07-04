import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import 'navigation_wrapper.dart';
import '../screens/employee/employee_dashboard.dart';
import '../screens/employee/employee_requests.dart';
import '../screens/employee/profile_settings.dart';
import '../screens/employee/performance_view.dart';
import '../screens/employee/suggestions_screen.dart';
import '../screens/hr/company_day_offs_screen.dart';
import '../screens/hr/location_mgmt.dart';
import '../screens/manager/manager_dashboard.dart';
import '../screens/manager/requests_mgmt.dart';
import '../screens/manager/suggestions_mgmt.dart';
import '../screens/manager/team_attendance.dart';
import '../screens/hr/hr_dashboard.dart';
import '../screens/hr/employee_mgmt.dart';
import '../screens/hr/announcements.dart';
import '../screens/hr/sheets_export_screen.dart';
import '../screens/manager/rate_performance.dart';

class ZaWolfRouter {
  static GoRouter getRouter(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authService,
      redirect: (BuildContext context, GoRouterState state) {
        final loggingIn = state.matchedLocation == '/login';
        final onSplash = state.matchedLocation == '/splash';

        final authenticated = authService.isAuthenticated;

        // 1. Unauthenticated users must log in
        if (!authenticated) {
          if (!loggingIn && !onSplash) {
            return '/login';
          }
          return null;
        }

        // 2. Authenticated users should be sent to their dashboard if they hit splash or login
        if (loggingIn || onSplash) {
          final role = authService.currentUser?.role;
          if (role == 'super_admin') return '/hr/dashboard';
          if (role == 'hr_admin') return '/hr/dashboard';
          if (role == 'manager') return '/manager/dashboard';
          return '/employee/dashboard';
        }

        // 3. Role Guards
        final role = authService.currentUser?.role;
        final goingToHr = state.matchedLocation.startsWith('/hr');
        final goingToManager = state.matchedLocation.startsWith('/manager');

        if (role == 'super_admin') {
          return null;
        }

        if (role == 'employee') {
          // Employees cannot access manager or hr paths
          if (goingToHr || goingToManager) {
            return '/employee/dashboard';
          }
        } else if (role == 'manager') {
          // Managers cannot access hr paths
          if (goingToHr) {
            return '/manager/dashboard';
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
              path: '/employee/performance',
              builder: (context, state) =>
                  const EmployeePerformanceViewScreen(),
            ),
            GoRoute(
              path: '/employee/profile',
              builder: (context, state) => const ProfileSettingsScreen(),
            ),
            GoRoute(
              path: '/employee/suggestions',
              builder: (context, state) => const EmployeeSuggestionsScreen(),
            ),
            // Manager Routes
            GoRoute(
              path: '/manager/dashboard',
              builder: (context, state) => const ManagerDashboardScreen(),
            ),
            GoRoute(
              path: '/manager/requests',
              builder: (context, state) => const RequestsManagementScreen(),
            ),
            GoRoute(
              path: '/manager/team',
              builder: (context, state) => const TeamAttendanceScreen(),
            ),
            GoRoute(
              path: '/manager/performance',
              builder: (context, state) => const RatePerformanceScreen(),
            ),
            GoRoute(
              path: '/manager/suggestions',
              builder: (context, state) => const SuggestionsManagementScreen(),
            ),
            // HR Admin Routes
            GoRoute(
              path: '/hr/dashboard',
              builder: (context, state) => const HrDashboardScreen(),
            ),
            GoRoute(
              path: '/hr/employees',
              builder: (context, state) => const EmployeeManagementScreen(),
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
              path: '/hr/announcements',
              builder: (context, state) => const AnnouncementsScreen(),
            ),
            GoRoute(
              path: '/hr/day-offs',
              builder: (context, state) => const CompanyDayOffsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
