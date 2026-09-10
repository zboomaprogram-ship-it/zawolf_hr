import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/employee_role.dart';
import '../theme/theme.dart';

import '../design_system/tokens.dart';
import '../services/notification_service.dart';
import '../core/feature_flags/phase007_feature_flags.dart';
import '../core/feature_flags/company_os_feature_flags.dart';
import '../core/feature_flags/remote_company_os_feature_flags.dart';
import '../core/feature_flags/remote_phase007_feature_flags.dart';
import '../core/sync/authenticated_operation_client.dart';
import '../features/employee_operations/data/notification_operations_repository_impl.dart';
import '../features/employee_operations/presentation/cubit/notification_badge_cubit.dart';
import '../services/pending_requests_service.dart';
import '../services/required_attendance_alarm_service.dart';
import '../models/user_model.dart';
import 'guarded_back_navigation.dart';
import 'nav_config.dart';
import 'web_shell.dart';
import 'dart:async';

class NavigationWrapper extends StatefulWidget {
  final Widget child;

  const NavigationWrapper({super.key, required this.child});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notifTapSub;
  StreamSubscription? _notificationBadgeSub;
  http.Client? _notificationHttpClient;
  NotificationBadgeCubit? _notificationBadgeCubit;
  String? _notificationBadgeActorId;
  int? _notificationUnreadCount;
  String? _currentUserUid;
  String? _attendanceAlarmCheckedForUid;
  UserModel? _alarmUser;
  final List<String> _webRouteHistory = <String>[];
  String? _lastWebRoute;
  bool _webBackNavigationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifTapSub = NotificationService.instance.onNotificationTap.listen((
      route,
    ) {
      if (mounted && route.isNotEmpty) {
        context.go(route);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifTapSub?.cancel();
    _notificationBadgeSub?.cancel();
    unawaited(_notificationBadgeCubit?.close());
    _notificationHttpClient?.close();
    PendingRequestsService.instance.stopListening();
    super.dispose();
  }

  void _ensureNotificationOperations(
    BuildContext context,
    Phase007FeatureFlags flags,
    String actorId,
  ) {
    final enabled = flags.isEnabledFor(
      feature: Phase007Feature.notificationOperations,
      actorId: actorId,
    );
    if (!enabled) {
      _disposeNotificationOperations();
      return;
    }
    if (_notificationBadgeActorId == actorId &&
        _notificationBadgeCubit != null) {
      return;
    }
    _disposeNotificationOperations();
    final client = http.Client();
    final cubit = NotificationBadgeCubit(
      actorId: actorId,
      repository: NotificationOperationsRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        operationClient: AuthenticatedOperationClient(
          client: client,
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
      ),
    );
    _notificationHttpClient = client;
    _notificationBadgeCubit = cubit;
    _notificationBadgeActorId = actorId;
    _notificationUnreadCount = cubit.state.unreadCount;
    NotificationService.instance.configureAuthorizedRouteResolver((id) async {
      final destination = await cubit.resolve(id);
      return destination?.toUri().toString();
    });
    _notificationBadgeSub = cubit.stream.listen((state) {
      if (!mounted || _notificationBadgeActorId != actorId) return;
      setState(() => _notificationUnreadCount = state.unreadCount);
    });
  }

  void _disposeNotificationOperations() {
    _notificationBadgeSub?.cancel();
    _notificationBadgeSub = null;
    unawaited(_notificationBadgeCubit?.close());
    _notificationBadgeCubit = null;
    NotificationService.instance.configureAuthorizedRouteResolver(null);
    _notificationHttpClient?.close();
    _notificationHttpClient = null;
    _notificationBadgeActorId = null;
    _notificationUnreadCount = null;
  }

  Widget _withNotificationOperations(Widget child) {
    final cubit = _notificationBadgeCubit;
    return cubit == null
        ? child
        : BlocProvider<NotificationBadgeCubit>.value(
            value: cubit,
            child: child,
          );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || state != AppLifecycleState.resumed || _alarmUser == null) return;
    unawaited(
      RequiredAttendanceAlarmService.instance
          .syncIfEnabled(_alarmUser!)
          .catchError((_) => false),
    );
  }

  void _checkRequiredAttendanceAlarm(UserModel user) {
    if (kIsWeb) return;
    if (_attendanceAlarmCheckedForUid == user.uid) return;
    _attendanceAlarmCheckedForUid = user.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final alreadyEnabled = await RequiredAttendanceAlarmService.instance
            .syncIfEnabled(user);
        if (alreadyEnabled || !mounted) return;
        final alreadyPrompted = await RequiredAttendanceAlarmService.instance
            .hasPrompted(user.uid);
        if (alreadyPrompted || !mounted) return;

        final startTime = RequiredAttendanceAlarmService.instance.startTimeFor(
          user,
        );
        final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('منبه تسجيل الحضور'),
            content: Text(
              'يمكنك تفعيل منبه اختياري للحضور الساعة $startTime. يعمل بصوت الذئب في أيام العمل، ويتوقف تلقائياً في الإجازات المعتمدة وأيام العطلة. يمكنك متابعة استخدام التطبيق من دون تفعيله.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ليس الآن'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.alarm),
                label: const Text('تفعيل'),
              ),
            ],
          ),
        );
        await RequiredAttendanceAlarmService.instance.markPrompted(user.uid);
        if (shouldEnable != true || !mounted) return;

        final settings = await RequiredAttendanceAlarmService.instance
            .enableFor(user);
        RequiredAttendanceAlarmService.instance.startWatching(user);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تفعيل منبه الحضور الساعة ${settings.formattedTime}.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    _alarmUser = user;
    final theme = Theme.of(context);

    if (user == null) {
      if (_currentUserUid != null) {
        _currentUserUid = null;
        _attendanceAlarmCheckedForUid = null;
        PendingRequestsService.instance.stopListening();
        _disposeNotificationOperations();
      }
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    final phase007Flags = context.watch<RemotePhase007FeatureFlags>();
    _ensureNotificationOperations(context, phase007Flags, user.uid);
    final effectiveUser = _notificationUnreadCount == null
        ? user
        : user.copyWith(unreadNotifications: _notificationUnreadCount);

    if (_currentUserUid != user.uid) {
      _currentUserUid = user.uid;
      if (user.role == EmployeeRole.manager ||
          user.role == EmployeeRole.hrAdmin ||
          user.role == EmployeeRole.hrManager ||
          user.role == EmployeeRole.superAdmin) {
        PendingRequestsService.instance.startListening(user);
      } else {
        PendingRequestsService.instance.stopListening();
      }
    }
    _checkRequiredAttendanceAlarm(user);

    final routerState = GoRouterState.of(context);
    final String matchedLocation = routerState.matchedLocation;
    final String role = user.role;
    _recordWebRoute(routerState.uri.toString());

    // Single shared source for both shells.
    final List<NavigationItem> items = navItemsForRole(role);
    // Watch the remote configuration so Company OS entries appear as soon as
    // the signed-in user's entitlements finish loading. Using `read` here
    // made a valid enabled feature remain invisible until a full app rebuild.
    final companyOs = context.watch<RemoteCompanyOsFeatureFlags>();
    if (kIsWeb &&
        companyOs.isEnabledFor(
          feature: CompanyOsFeature.portal,
          actorId: user.uid,
        )) {
      items.add(
        NavigationItem(
          icon: Icons.business_center_outlined,
          activeIcon: Icons.business_center,
          label: 'مركز تشغيل الشركة',
          englishLabel: 'Company Operations Hub',
          path: '/company-os',
          domain: NavDomain.approvals,
        ),
      );
    }
    if (companyOs.isEnabledFor(
      feature: CompanyOsFeature.itOperations,
      actorId: user.uid,
    )) {
      items.add(
        NavigationItem(
          icon: Icons.support_agent_outlined,
          activeIcon: Icons.support_agent,
          label: 'عمليات IT',
          englishLabel: 'IT Operations',
          path: '/company-os/it',
          domain: NavDomain.people,
        ),
      );
    }
    const operationsRoles = {
      EmployeeRole.manager,
      EmployeeRole.hrAdmin,
      EmployeeRole.superAdmin,
      'admin',
      'finance',
      'it_manager',
    };
    if (operationsRoles.contains(EmployeeRole.normalize(user.role)) &&
        companyOs.isEnabledFor(
          feature: CompanyOsFeature.operations,
          actorId: user.uid,
        )) {
      items.add(
        NavigationItem(
          icon: Icons.monitor_heart_outlined,
          activeIcon: Icons.monitor_heart,
          label: 'عمليات الشركة',
          englishLabel: 'Company Operations',
          path: '/company-os/operations',
          domain: NavDomain.performance,
        ),
      );
    }

    final isManagementRole =
        role == EmployeeRole.manager ||
        role == EmployeeRole.hrAdmin ||
        role == EmployeeRole.hrManager ||
        role == EmployeeRole.superAdmin;
    final useDesktopWebShell =
        kIsWeb && MediaQuery.sizeOf(context).width >= 980;
    if (useDesktopWebShell) {
      final desktopItems = isManagementRole
          ? items
              .where(
                (item) =>
                    !item.path.startsWith('/employee/') ||
                    item.path == '/employee/profile' ||
                    item.path == '/employee/dashboard' ||
                    item.path == '/employee/requests',
              )
              .toList()
          : items;
      return _withNotificationOperations(
        WebManagementShell(
          user: effectiveUser,
          items: desktopItems,
          matchedLocation: matchedLocation,
          canGoBack:
              _webRouteHistory.isNotEmpty ||
              matchedLocation != homeRouteForRole(role),
          onBack: () => _navigateBackOnWeb(context, role),
          onSignOut: () async {
            await authService.signOut();
            if (context.mounted) context.go('/login');
          },
          child: widget.child,
        ),
      );
    }

    // Mobile bottom nav: fixed four role tabs + grouped More sheet.
    final bottomItems = mobileTabsForRole(role);
    final allItems = items;
    final hasOverflow = allItems.any((item) => !bottomItems.contains(item));
    final overflowItems = hasOverflow
        ? allItems.where((item) => !bottomItems.contains(item)).toList()
        : <NavigationItem>[];

    // Shell-route tabs are intentionally navigated with `go`, so the platform
    // stack alone cannot restore the prior in-app tab. Keep a short local
    // history and consume Android/iOS back gestures before the OS can close
    // the app. Detail/form routes may still add their own dirty-form guard.
    return _withNotificationOperations(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _navigateBackOnWeb(context, role);
        },
        child: Scaffold(
          body: widget.child,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: ZaWolfColors.surface01,
              border: const Border(
                top: BorderSide(color: ZaWolfColors.surface03, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 24,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DsSpacing.sm,
                  horizontal: DsSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ...bottomItems.map((item) {
                      return Expanded(
                        child: _BottomTab(
                          item: item,
                          selected:
                              matchedLocation == item.path ||
                              matchedLocation.startsWith('${item.path}/'),
                          unreadCount: _unreadBadgeFor(item, user, role),
                          showPendingBadge: item.path.endsWith('/requests'),
                          onTap: () {
                            if (matchedLocation != item.path) {
                              context.go(item.path);
                            }
                          },
                        ),
                      );
                    }),
                    if (hasOverflow)
                      Expanded(
                        child: _BottomTab(
                          item: NavigationItem(
                            icon: Icons.menu,
                            activeIcon: Icons.menu_open,
                            label: 'المزيد',
                            englishLabel: 'More',
                            path: '__more__',
                          ),
                          selected: overflowItems.any(
                            (extra) => extra.path == matchedLocation,
                          ),
                          unreadCount: 0,
                          showPendingBadge: false,
                          onTap: () => _showGroupedMoreSheet(
                            context: context,
                            theme: theme,
                            items: overflowItems,
                            matchedLocation: matchedLocation,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _unreadBadgeFor(NavigationItem item, UserModel user, String role) {
    final unread = _notificationUnreadCount ?? user.unreadNotifications;
    if (unread <= 0) return 0;
    final isProfileAnchor =
        (role == EmployeeRole.employee || role == EmployeeRole.teamLeader) &&
        item.path == '/employee/profile';
    final isDashboardAnchor =
        (role == EmployeeRole.manager && item.path == '/manager/dashboard') ||
        ((role == EmployeeRole.hrAdmin ||
                role == EmployeeRole.hrManager ||
                role == EmployeeRole.superAdmin) &&
            item.path == '/hr/dashboard');
    return (isProfileAnchor || isDashboardAnchor) ? unread : 0;
  }

  void _recordWebRoute(String route) {
    if (route == _lastWebRoute) return;
    if (_webBackNavigationInProgress) {
      _webBackNavigationInProgress = false;
    } else if (_lastWebRoute != null) {
      _webRouteHistory.add(_lastWebRoute!);
      if (_webRouteHistory.length > 30) {
        _webRouteHistory.removeAt(0);
      }
    }
    _lastWebRoute = route;
  }

  void _navigateBackOnWeb(BuildContext context, String role) {
    final decision = GuardedBackNavigation.decide(
      hasPreviousRoute: _webRouteHistory.isNotEmpty,
      isHomeRoute:
          GoRouterState.of(context).matchedLocation == homeRouteForRole(role),
    );
    if (decision == GuardedBackDecision.navigatePrevious) {
      final target = _webRouteHistory.removeLast();
      _webBackNavigationInProgress = true;
      context.go(target);
      return;
    }

    final fallback = homeRouteForRole(role);
    if (decision == GuardedBackDecision.navigateHome) {
      _webBackNavigationInProgress = true;
      context.go(fallback);
    }
  }

  void _showGroupedMoreSheet({
    required BuildContext context,
    required ThemeData theme,
    required List<NavigationItem> items,
    required String matchedLocation,
  }) {
    final groups = groupNavItems(items);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: ZaWolfColors.surface01,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface03,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'إغلاق',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                      Text(
                        'قائمة الخدمات والأنظمة',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final group in groups)
                            _DomainCard(
                              domainLabel: group.domain.arabicLabel,
                              englishLabel: group.domain.englishLabel,
                              icon: group.domain.icon,
                              children: group.items,
                              matchedLocation: matchedLocation,
                              onNavigate: (path) {
                                Navigator.pop(sheetContext);
                                if (matchedLocation != path) context.go(path);
                              },
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ZaWolfColors.surface03),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'إغلاق القائمة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DomainCard extends StatelessWidget {
  final String domainLabel;
  final String englishLabel;
  final IconData icon;
  final List<NavigationItem> children;
  final String matchedLocation;
  final ValueChanged<String> onNavigate;

  const _DomainCard({
    required this.domainLabel,
    required this.englishLabel,
    required this.icon,
    required this.children,
    required this.matchedLocation,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final anyActive = children.any((item) => item.path == matchedLocation);
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.md),
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: anyActive
              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.35)
              : ZaWolfColors.surface03,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: anyActive
                    ? ZaWolfColors.primaryCyan
                    : ZaWolfColors.textSecondary,
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      domainLabel,
                      style: TextStyle(
                        color: anyActive
                            ? Colors.white
                            : ZaWolfColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: DsType.body,
                      ),
                    ),
                    Text(
                      englishLabel,
                      style: const TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: DsType.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              for (final item in children)
                ActionChip(
                  label: Text(item.label),
                  labelStyle: TextStyle(
                    color: item.path == matchedLocation
                        ? ZaWolfColors.primaryCyan
                        : ZaWolfColors.textSecondary,
                    fontSize: DsType.caption,
                  ),
                  backgroundColor: item.path == matchedLocation
                      ? ZaWolfColors.primaryCyan.withValues(alpha: 0.12)
                      : ZaWolfColors.surface02,
                  side: BorderSide(
                    color: item.path == matchedLocation
                        ? ZaWolfColors.primaryCyan.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                  onPressed: () => onNavigate(item.path),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  final NavigationItem item;
  final bool selected;
  final int unreadCount;
  final bool showPendingBadge;
  final VoidCallback onTap;

  const _BottomTab({
    required this.item,
    required this.selected,
    required this.unreadCount,
    required this.showPendingBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = selected
        ? ZaWolfColors.primaryCyan
        : ZaWolfColors.textSecondary;

    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 42,
      height: 34,
      decoration: BoxDecoration(
        color: selected
            ? ZaWolfColors.primaryCyan.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: Icon(
        selected ? item.activeIcon : item.icon,
        color: accentColor,
        size: 22,
      ),
    );

    if (showPendingBadge) {
      iconWidget = ValueListenableBuilder<int>(
        valueListenable: PendingRequestsService.instance.pendingCount,
        builder: (context, pendingCount, child) {
          if (pendingCount > 0) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                child!,
                Positioned(
                  top: -3,
                  left: -3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: ZaWolfColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            );
          }
          return child!;
        },
        child: iconWidget,
      );
    }

    if (unreadCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -3,
            left: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZaWolfColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              item.label,
              style: theme.textTheme.bodySmall!.copyWith(
                color: accentColor,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
