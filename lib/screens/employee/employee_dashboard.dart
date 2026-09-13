import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/employee_request_history_section.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/attendance_gateway_service.dart';
import '../../services/offline_attendance_queue_service.dart';
import '../../services/automatic_attendance_service.dart';
import '../../services/company_day_off_service.dart';
import '../../services/attendance_period_summary_service.dart';
import '../../services/performance_badge_service.dart';
import '../../components/badge_celebration_dialog.dart';
import '../../components/performance_badges_widget.dart';
import '../../services/geofence_service.dart';
import '../../models/attendance_model.dart';
import '../../models/company_day_off_status.dart';
import '../../models/user_model.dart';
import '../../utils/payroll_cycle.dart';
import '../../features/attendance_checkin/attendance_checkin.dart';
import '../../features/attendance_checkin/presentation/attendance_failure_diagnostic.dart';
import '../../services/audit_log_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../navigation/developer_tools_entry.dart';
import '../../features/web_attendance_access/data/web_attendance_access_repository_impl.dart';
import '../../design_system/components/app_logo.dart';
import '../../design_system/components/stat_card.dart';
import '../../design_system/tokens.dart';
import 'checkin_confirm_modal.dart';
import 'employee_attendance_gate_cubit.dart';
import 'widgets/checkin_radar_button.dart';
import 'widgets/checkin_action_state.dart';
import 'widgets/employee_dashboard_header.dart';
import 'widgets/employee_priority_strip.dart';
import 'widgets/employee_quick_action.dart';
import 'widgets/month_activity_section.dart';
import 'widgets/employee_web_dashboard_view.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with WidgetsBindingObserver {
  static const _pilotEmployeeScopeId = String.fromEnvironment(
    'ATTENDANCE_CHECKIN_PILOT_USER_ID',
    defaultValue: '',
  );

  GeofenceResult? _geofenceResult;
  bool _checkingLocation = false;
  String? _locationError;
  bool _actionLoading = false;
  CompanyDayOffStatus _dayOffStatus = const CompanyDayOffStatus.workDay();
  bool _checkingDayOff = false;
  Stream<List<AttendanceModel>> _attendanceStream = const Stream.empty();
  String? _attendanceStreamUserId;
  String? _attendanceStreamMonthKey;
  String? _preparedUserId;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  AttendanceCheckInPilot? _checkInPilot;
  int _pendingRequestsCount = 0;
  String? _pendingRequestCategory;
  bool _developerAttendanceAccess = false;
  String? _developerAttendanceAccessUserId;
  bool _webAttendanceAccess = false;
  String? _webAttendanceAccessUserId;
  AttendancePeriodSummary? _periodSummary;
  String? _periodSummaryScope;
  String? _periodSummaryLoadingScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AttendanceService().syncPendingOfflineAttendance();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final previousDay = DateUtils.dateOnly(_now);
      final current = DateTime.now();
      setState(() => _now = current);
      final user = context.read<AuthService>().currentUser;
      if (user != null && DateUtils.dateOnly(current) != previousDay) {
        unawaited(_checkCompanyDayOff());
        unawaited(_refreshAttendanceGate(user));
        unawaited(_loadPeriodSummary(user, force: true));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    final pilot = _checkInPilot;
    if (pilot != null) unawaited(pilot.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final user = context.read<AuthService>().currentUser;
    setState(() => _now = DateTime.now());
    if (user != null) {
      unawaited(_checkCompanyDayOff());
      unawaited(_refreshAttendanceGate(user));
      unawaited(_loadPeriodSummary(user, force: true));
    }
  }

  bool _isCheckInPilotEnabledFor(UserModel employee) =>
      _pilotEmployeeScopeId.isNotEmpty && _pilotEmployeeScopeId == employee.uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService>(context).currentUser;
    final currentMonthKey = PayrollCycle.keyFor(DateTime.now());
    if (user == null) {
      if (_attendanceStreamUserId != null) {
        _attendanceStream = const Stream.empty();
        _attendanceStreamUserId = null;
        _attendanceStreamMonthKey = null;
        _preparedUserId = null;
        _developerAttendanceAccess = false;
        _developerAttendanceAccessUserId = null;
        _webAttendanceAccess = false;
        _webAttendanceAccessUserId = null;
        _periodSummary = null;
        _periodSummaryScope = null;
        _periodSummaryLoadingScope = null;
      }
      return;
    }

    if (_attendanceStreamUserId != user.uid ||
        _attendanceStreamMonthKey != currentMonthKey) {
      _attendanceStream = AttendanceService().watchMonthlyAttendance(
        user.uid,
        currentMonthKey,
      );
      _attendanceStreamUserId = user.uid;
      _attendanceStreamMonthKey = currentMonthKey;
    }

    if (_preparedUserId != user.uid) {
      _preparedUserId = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _preparedUserId != user.uid) return;
        if (!kIsWeb) {
          _checkCurrentGeofence();
          // This only registers Android's branch boundary after the employee
          // has explicitly granted Always Location. It never prompts here.
          AutomaticAttendanceService.instance
              .configureFor(user)
              .catchError((_) {});
        }
        _checkCompanyDayOff();
        _refreshAttendanceGate(user);
        _loadPeriodSummary(user);
        if (_isCheckInPilotEnabledFor(user)) {
          _checkInPilot ??= AttendanceCheckInPilot.create();
          _checkInPilot!.cubit.synchronizePending(user.uid).whenComplete(() {
            if (mounted) setState(() {});
          });
        }
      });
    }

    if (_developerAttendanceAccessUserId != user.uid) {
      _developerAttendanceAccessUserId = user.uid;
      unawaited(_loadDeveloperAttendanceAccess(user.uid));
    }
    if (_webAttendanceAccessUserId != user.uid) {
      _webAttendanceAccessUserId = user.uid;
      unawaited(_loadWebAttendanceAccess(user.uid));
    }
  }

  Future<void> _loadDeveloperAttendanceAccess(String userId) async {
    final enabled = await DeveloperToolsAccess.isAvailableForCurrentUser();
    if (!mounted || _developerAttendanceAccessUserId != userId) return;
    setState(() => _developerAttendanceAccess = enabled);
  }

  Future<void> _loadWebAttendanceAccess(String userId) async {
    try {
      final grant = await createWebAttendanceAccessRepository().myActiveGrant();
      if (!mounted || _webAttendanceAccessUserId != userId) return;
      setState(() => _webAttendanceAccess = grant != null);
    } catch (_) {
      if (!mounted || _webAttendanceAccessUserId != userId) return;
      setState(() => _webAttendanceAccess = false);
    }
  }

  Future<void> _checkCurrentGeofence() async {
    if (kIsWeb || !mounted) return;
    setState(() {
      _checkingLocation = true;
      _locationError = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) {
      setState(() => _checkingLocation = false);
      return;
    }

    try {
      final policy = await AttendanceService().policyConfigForDisplay();
      final res = await GeofenceService().validateCheckIn(
        user,
        strictLocationOnly: !policy.requiresBiometric,
      );
      if (mounted) {
        setState(() {
          _geofenceResult = res;
          _checkingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString().replaceAll('Exception: ', '');
          _checkingLocation = false;
        });
      }
    }
  }

  Future<void> _checkCompanyDayOff() async {
    if (!mounted) return;
    setState(() {
      _checkingDayOff = true;
    });

    try {
      final now = DateTime.now();
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final workDays = user?.workSchedule.workDays;
      final status =
          workDays != null &&
                  workDays.isNotEmpty &&
                  !workDays.contains(now.weekday)
              ? const CompanyDayOffStatus(
                isDayOff: true,
                reason: 'ليس ضمن جدول عملك',
              )
              : await CompanyDayOffService().getDayOffStatus(now);
      if (mounted) {
        setState(() {
          _dayOffStatus = status;
          _checkingDayOff = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dayOffStatus = const CompanyDayOffStatus.workDay();
          _checkingDayOff = false;
        });
      }
    }
  }

  Future<void> _refreshAttendanceGate(UserModel user) async {
    try {
      await context.read<EmployeeAttendanceGateCubit>().load(user);
    } catch (_) {}
    if (mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  Future<void> _loadPeriodSummary(UserModel user, {bool force = false}) async {
    final cycle = PayrollCycle.forDate(_now);
    final scope =
        '${user.uid}:${cycle.key}:${DateFormat('yyyy-MM-dd').format(_now)}';
    if (!force && _periodSummaryScope == scope) return;
    if (_periodSummaryLoadingScope == scope) return;
    _periodSummaryLoadingScope = scope;
    try {
      final summary = await AttendancePeriodSummaryService().loadForUser(
        user: user,
        start: cycle.start,
        end: _now,
        now: _now,
      );
      if (mounted && _periodSummaryLoadingScope == scope) {
        _periodSummaryScope = scope;
        setState(() => _periodSummary = summary);
      }
    } catch (_) {
      // Stored attendance remains visible while the richer leave/day-off
      // reconciliation reloads on the next foreground refresh.
    } finally {
      if (_periodSummaryLoadingScope == scope) {
        _periodSummaryLoadingScope = null;
      }
    }
  }

  Future<void> _handleCheckInCheckOut(
    UserModel employee,
    AttendanceActionIntent expectedAction,
  ) async {
    setState(() {
      _actionLoading = true;
    });

    final attendanceService = AttendanceService();
    final useCheckInPilot =
        expectedAction == AttendanceActionIntent.checkIn &&
        _isCheckInPilotEnabledFor(employee);
    try {
      if (useCheckInPilot) {
        _checkInPilot ??= AttendanceCheckInPilot.create();
      }
      final attendanceResult = await attendanceService.handleCheckInOrCheckOut(
        employee,
        expectedAction: expectedAction,
        reliableCheckInSubmitter:
            useCheckInPilot
                ? (verifiedAction) => _submitReliableCheckIn(verifiedAction)
                : null,
      );
      if (useCheckInPilot &&
          _checkInPilot!.cubit.state.status != CheckInViewStatus.saved) {
        if (mounted) _showReliableCheckInFeedback();
        return;
      }
      // The gateway has accepted the action (or the durable offline queue has
      // retained it) at this point. Location, day-off, and gate probes are
      // dashboard decoration: waiting for them kept the checkout button in a
      // loading state after a successful checkout, especially on slow GPS.
      // The attendance stream remains the source of the dashboard state.
      if (mounted) setState(() => _now = DateTime.now());
      unawaited(_refreshAttendanceAfterAction(employee));
      unawaited(_showAttendanceConfirmation(attendanceResult));
    } catch (e) {
      final diagnostic = AttendanceFailureDiagnostic.fromError(e);
      final failureMessage = _friendlyAttendanceError(e);
      unawaited(
        AuditLogService.instance.record(
          actorId: employee.uid,
          action: 'attendance_action_failed',
          targetCollection: 'attendance',
          targetId:
              '${employee.uid}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
          metadata: {
            'employeeName': employee.displayName,
            'employeeId': employee.employeeId,
            'intendedAction': expectedAction.name,
            'errorCode': diagnostic.code,
            'diagnosticTitle': diagnostic.title,
            'diagnosticMessage': failureMessage,
            'rawError': e.toString(),
          },
        ),
      );
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (dialogContext) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  backgroundColor: ZaWolfColors.surface01,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: ZaWolfColors.surface03),
                  ),
                  title: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: ZaWolfColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          diagnostic.title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        failureMessage,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                          height: 1.6,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.surface02,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ZaWolfColors.surface03),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: ZaWolfColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'رمز التشخيص: ${diagnostic.code}',
                                style: const TextStyle(
                                  color: ZaWolfColors.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.start,
                  actions: [
                    if (diagnostic.actionType ==
                            AttendanceFailureActionType.openLocationSettings &&
                        !kIsWeb)
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await Geolocator.openLocationSettings();
                        },
                        icon: const Icon(
                          Icons.location_on,
                          size: 16,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        label: const Text(
                          'فتح إعدادات الموقع',
                          style: TextStyle(color: ZaWolfColors.primaryCyan),
                        ),
                      ),
                    if (diagnostic.actionType ==
                            AttendanceFailureActionType.openAppSettings &&
                        !kIsWeb)
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await Geolocator.openAppSettings();
                        },
                        icon: const Icon(
                          Icons.settings,
                          size: 16,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        label: const Text(
                          'فتح إعدادات التطبيق',
                          style: TextStyle(color: ZaWolfColors.primaryCyan),
                        ),
                      ),
                    if (diagnostic.actionType ==
                        AttendanceFailureActionType.retry)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _handleCheckInCheckOut(employee, expectedAction);
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(color: ZaWolfColors.primaryCyan),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'حسنًا',
                        style: TextStyle(color: ZaWolfColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAttendanceAfterAction(UserModel employee) async {
    // None of these probes affect whether the completed action is shown.
    // Isolate failures so a temporary geolocation or policy outage cannot
    // reintroduce a stuck action button.
    await Future.wait([
      _refreshAttendanceGate(employee),
      _checkCurrentGeofence(),
      _checkCompanyDayOff(),
    ]);
  }

  Future<void> _showAttendanceConfirmation(
    AttendanceActionResult result,
  ) async {
    if (!mounted) return;

    if (!result.confirmedOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الحركة بأمان وبانتظار تأكيد الخادم. ستتم إعادة المحاولة تلقائياً.',
          ),
        ),
      );
      return;
    }

    // The gateway/pilot receipt is authoritative. Do not wait for Firestore's
    // eventually-consistent client cache to decide whether this was check-in
    // or checkout: doing so could label a completed checkout as check-in, or
    // claim an online submission was offline.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CheckInConfirmModal(
            isCheckOut: result.action == AttendanceActionIntent.checkOut,
            time: result.eventTime,
            locationName: result.locationName,
            status: result.status,
            lateMinutes: result.lateMinutes,
          ),
    );
  }

  Future<bool> _submitReliableCheckIn(
    OfflineAttendanceAction verifiedAction,
  ) async {
    final pilot = _checkInPilot;
    if (pilot == null) return false;
    final payload = Map<String, Object?>.from(verifiedAction.toJson());
    await pilot.cubit.submit(
      CheckInAction(
        actionId: verifiedAction.attendanceId,
        employeeScopeId: verifiedAction.userId,
        dateKey: verifiedAction.date,
        capturedAt: verifiedAction.eventTime,
        payload: payload,
      ),
    );
    return pilot.cubit.state.status == CheckInViewStatus.saved;
  }

  void _showReliableCheckInFeedback() {
    final pilot = _checkInPilot;
    if (pilot == null) return;
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text(
              'حالة تسجيل الحضور',
              style: TextStyle(color: Colors.white),
            ),
            content: CheckInStatusFeedback(
              state: pilot.cubit.state,
              failureMessage: pilot.cubit.safeFailureMessage(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
    );
  }

  Future<void> _retryReliableCheckIn(String employeeScopeId) async {
    final pilot = _checkInPilot;
    if (pilot == null) return;

    await pilot.cubit.synchronizePending(employeeScopeId);
    if (mounted) setState(() {});
  }

  String _friendlyAttendanceError(Object error) {
    if (error is AttendanceGatewayException) {
      return error.userMessage;
    }
    final diagnostic = AttendanceFailureDiagnostic.fromError(error);
    if (diagnostic.code == 'ERR_ATTENDANCE_UNKNOWN') {
      return 'لم يتم حفظ تسجيل الحضور لهذه المحاولة، ولن يُسجَّل حضور مكرر. تأكد من تشغيل الإنترنت والموقع الدقيق ثم أعد المحاولة. إذا تكرر الأمر، يراجع HR حالة الحساب.';
    }
    return diagnostic.message;
  }

  bool _checkedCelebrations = false;

  void _checkUnseenCelebrationBadges(UserModel user) {
    if (_checkedCelebrations) return;
    _checkedCelebrations = true;
    final awarded = PerformanceBadgeService.instance.watchAwardedBadgeIds(
      user.uid,
    );
    awarded.first.then((ids) {
      if (!mounted) return;
      final unseen =
          ids
              .where((id) => !user.seenCelebrationBadgeIds.contains(id))
              .toList();
      if (unseen.isNotEmpty) {
        final badgeId = unseen.first;
        final def = performanceBadgeCatalog.firstWhere(
          (b) => b.id == badgeId,
          orElse:
              () => PerformanceBadgeDefinition(
                id: badgeId,
                title: performanceBadgeTitle(badgeId),
                description: 'تهانينا! حصلت على شارة تميز جديدة من الشركة 🏆',
                icon: Icons.emoji_events_rounded,
                color: ZaWolfColors.perfGold,
              ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            BadgeCelebrationDialog.show(
              context,
              userId: user.uid,
              userName: user.displayName,
              department: user.department,
              badgeId: def.id,
              badgeTitle: def.title,
              badgeDescription: def.description,
              iconData: def.icon,
              color: def.color,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final attendanceService = AttendanceService();

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return BlocProvider(
      create: (_) => EmployeeAttendanceGateCubit()..load(user),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () => context.push('/notifications'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (user.unreadNotifications > 0)
                    PositionedDirectional(
                      top: -5,
                      start: -8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: ZaWolfColors.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.unreadNotifications > 99
                              ? '99+'
                              : '${user.unreadNotifications}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 28),
              const SizedBox(width: 8),
              Text(
                'ZaWolf HR',
                style:
                    theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<List<AttendanceModel>>(
          stream: _attendanceStream,
          builder: (context, snapshot) {
            final attendanceError =
                snapshot.hasError
                    ? 'تعذر تحميل سجل الحضور الآن. يمكنك السحب للتحديث أو المحاولة مرة أخرى.'
                    : null;
            final logs = snapshot.data ?? [];
            final todayLog = logs.firstWhere(
              (log) => log.date == todayStr,
              orElse:
                  () => AttendanceModel(
                    attendanceId: '',
                    userId: '',
                    employeeId: '',
                    employeeName: '',
                    locationId: '',
                    locationName: '',
                    date: '',
                    checkInLocation: const GeoPoint(0, 0),
                    status: 'absent',
                  ),
            );

            final bool hasTodayRecord = todayLog.attendanceId.isNotEmpty;
            final bool hasCheckedIn = todayLog.checkInTime != null;
            final bool hasCheckedOut =
                hasCheckedIn && todayLog.checkOutTime != null;
            final pilotState =
                _isCheckInPilotEnabledFor(user)
                    ? _checkInPilot?.cubit.state
                    : null;
            final pilotAwaitingConfirmation =
                pilotState?.status == CheckInViewStatus.pendingSync ||
                pilotState?.status == CheckInViewStatus.requiresStatusCheck ||
                pilotState?.status == CheckInViewStatus.submitting;
            final gateState =
                context.watch<EmployeeAttendanceGateCubit>().state;
            final gate = computeCheckInAction(
              CheckInGateInputs(
                now: _now,
                hasTodayRecord: hasTodayRecord,
                hasCheckedIn: hasCheckedIn,
                hasCheckedOut: hasCheckedOut,
                policyConfig: gateState.policyConfig,
                scheduleStartTime: user.workSchedule.startTime,
                scheduleEndTime: user.workSchedule.endTime,
                checkoutAllowedFromOverride: gateState.checkoutAllowedFrom,
                checkoutEnabled: gateState.checkoutEnabled,
                dayOffStatus: _dayOffStatus,
                actionLoading: _actionLoading,
                pilotAwaitingConfirmation: pilotAwaitingConfirmation,
              ),
            );

            // Quick stats calculation for current payroll cycle up to today
            final cycle = PayrollCycle.forDate(_now);
            final summaryScope =
                '${user.uid}:${cycle.key}:${DateFormat('yyyy-MM-dd').format(_now)}';
            final periodSummary =
                _periodSummaryScope == summaryScope && _periodSummary != null
                    ? _periodSummary!
                    : const AttendancePeriodSummary([]);

            final workedDays = periodSummary.presentDays;
            // Keep this percentage consistent with خصوماتي: a late label
            // alone is not a payroll deduction until HR has approved it.
            final disciplineScore = periodSummary.disciplinePercentage;

            // Check for unseen celebration badges
            _checkUnseenCelebrationBadges(user);

            if (kIsWeb && MediaQuery.sizeOf(context).width >= 980) {
              return EmployeeWebDashboardView(
                user: user,
                logs: logs,
                todayLog: todayLog,
                disciplineScore: disciplineScore,
                workedDays: workedDays,
                pendingRequestsCount: _pendingRequestsCount,
                onRefresh: () async {
                  await attendanceService.syncPendingOfflineAttendance();
                  await Future.wait([
                    _checkCurrentGeofence(),
                    _checkCompanyDayOff(),
                    _loadPeriodSummary(user, force: true),
                  ]);
                },
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await attendanceService.syncPendingOfflineAttendance();
                await Future.wait([
                  _checkCurrentGeofence(),
                  _checkCompanyDayOff(),
                  _loadPeriodSummary(user, force: true),
                ]);
              },
              color: ZaWolfColors.primaryCyan,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (attendanceError != null) ...[
                      WolfCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: ZaWolfColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                attendanceError,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ZaWolfColors.textSecondary,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    EmployeeDashboardHeader(
                      user: user,
                      geofenceResult: _geofenceResult,
                      checkingLocation: _checkingLocation,
                      onRetryGeofence: _checkCurrentGeofence,
                    ),
                    const SizedBox(height: 12),

                    // My status today, first content per the dashboard anatomy
                    MyStatusCard(todayLog: todayLog),
                    const SizedBox(height: 12),

                    // Priority strip: my pending requests + tasks due today
                    EmployeePriorityStrip(
                      userId: user.uid,
                      pendingRequestsCount: _pendingRequestsCount,
                      pendingRequestCategory: _pendingRequestCategory,
                    ),
                    const SizedBox(height: 16),

                    if (_locationError != null) ...[
                      WolfCard(
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed:
                                  _checkingLocation
                                      ? null
                                      : _checkCurrentGeofence,
                              icon: const Icon(Icons.refresh),
                              label: const Text('تحديث'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _locationError!,
                                style: const TextStyle(
                                  color: ZaWolfColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.location_disabled_outlined,
                              color: ZaWolfColors.warning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (kIsWeb && !_webAttendanceAccess) ...[
                      WolfCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.primaryCyan.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                color: ZaWolfColors.primaryCyan,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تسجيل الحضور عبر تطبيق الجوال',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'تسجيل الحضور والانصراف متاح حصراً عبر تطبيق الهاتف لضمان التحقق الجغرافي والبيومتري.',
                                    style: TextStyle(
                                      color: ZaWolfColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (user.excludeFromAttendanceReports &&
                        !_developerAttendanceAccess) ...[
                      WolfCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: ZaWolfColors.warning,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'غير مطبق عليك تسجيل الحضور/الانصراف (مستثنى من التقرير اليومي بقرار إداري). يمكنك استخدام جميع خدمات التطبيق والطلبات والمحادثات بشكل طبيعي.',
                                style: TextStyle(
                                  color: ZaWolfColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // Circular Pulsing Action Button
                      CheckInRadarButton(
                        title: gate.title,
                        subtitle: gate.subtitle,
                        icon: gate.icon,
                        disabled: gate.disabled,
                        loading: _actionLoading,
                        active: hasCheckedIn,
                        onTap:
                            () => _handleCheckInCheckOut(
                              user,
                              gate.expectedAction,
                            ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (pilotAwaitingConfirmation) ...[
                      CheckInStatusFeedback(
                        state: pilotState!,
                        failureMessage:
                            _checkInPilot!.cubit.safeFailureMessage(),
                        onRetry: () {
                          unawaited(_retryReliableCheckIn(user.uid));
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_checkingDayOff ||
                        (!hasTodayRecord && _dayOffStatus.isDayOff)) ...[
                      WolfCard(
                        child: Row(
                          children: [
                            Icon(
                              _checkingDayOff
                                  ? Icons.sync
                                  : Icons.event_busy_outlined,
                              color:
                                  _checkingDayOff
                                      ? ZaWolfColors.primaryCyan
                                      : ZaWolfColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _checkingDayOff
                                    ? 'جاري التحقق من أيام العطلات...'
                                    : 'تسجيل الحضور متوقف اليوم: ${_dayOffStatus.reason}',
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          _checkingDayOff
                                              ? ZaWolfColors.textSecondary
                                              : ZaWolfColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ) ??
                                    TextStyle(
                                      color:
                                          _checkingDayOff
                                              ? ZaWolfColors.textSecondary
                                              : ZaWolfColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Location error panel if any
                    if (_locationError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: ZaWolfColors.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _locationError!,
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                      color: ZaWolfColors.error,
                                    ) ??
                                    const TextStyle(color: ZaWolfColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Keep the original compact dashboard rhythm: three
                    // actions per row on normal phones. The previous
                    // two-column layout made the navigation cards needlessly
                    // tall and inconsistent with the established design.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 320 ? 2 : 3;
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: DsSpacing.md,
                          mainAxisSpacing: DsSpacing.md,
                          childAspectRatio: 1.05,
                          children: [
                            EmployeeQuickAction(
                              icon: Icons.add_circle_outline,
                              label: 'طلب جديد',
                              subtitle: 'New Request',
                              color: ZaWolfColors.permissionTeal,
                              onTap: () => context.go('/employee/requests'),
                            ),
                            EmployeeQuickAction(
                              icon: Icons.task_alt_outlined,
                              label: 'مهامي',
                              subtitle: 'My Tasks',
                              color: ZaWolfColors.wolfGreen,
                              onTap: () => context.go('/employee/tasks'),
                            ),
                            EmployeeQuickAction(
                              icon: Icons.payments_outlined,
                              label: 'راتبي',
                              subtitle: 'Payroll',
                              color: ZaWolfColors.warning,
                              onTap: () => context.go('/employee/payroll'),
                            ),
                            EmployeeQuickAction(
                              icon: Icons.business_center_outlined,
                              label: 'الطلبات والدعم',
                              subtitle: 'Requests & Support',
                              color: ZaWolfColors.primaryCyan,
                              onTap: () => context.go('/employee/requests'),
                            ),
                            EmployeeQuickAction(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'شات القسم',
                              subtitle: 'Department Chat',
                              color: ZaWolfColors.dayoffPurple,
                              onTap: () => context.go('/conversations'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: DsSpacing.xl),

                    // Quick Stats Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          StatCard(
                            icon: Icons.how_to_reg_outlined,
                            value: '$workedDays',
                            label: 'أيام الحضور هذا الشهر',
                          ),
                          StatCard(
                            icon: Icons.workspace_premium_outlined,
                            value: '${disciplineScore.toInt()}%',
                            label: 'الانضباط',
                            trendLabel: disciplineScore >= 85 ? null : 'تحسين',
                            trendUp: disciplineScore >= 85,
                            onTap: () => context.go('/employee/deductions'),
                          ),
                        ];
                        if (constraints.maxWidth < 340) {
                          return Column(
                            children: [
                              cards.first,
                              const SizedBox(height: DsSpacing.md),
                              cards.last,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: cards.first),
                            const SizedBox(width: DsSpacing.md),
                            Expanded(child: cards.last),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: DsSpacing.xl),

                    EmployeeRequestHistorySection(
                      userId: user.uid,
                      onPendingCount: (pendingCount) {
                        if (mounted && pendingCount != _pendingRequestsCount) {
                          setState(() => _pendingRequestsCount = pendingCount);
                        }
                      },
                      onPendingCategory: (category) {
                        if (mounted && category != _pendingRequestCategory) {
                          setState(() => _pendingRequestCategory = category);
                        }
                      },
                    ),
                    const SizedBox(height: DsSpacing.xl),

                    MonthActivitySection(
                      logs: logs,
                      absentDates: periodSummary.days
                          .where((day) => day.isAbsent)
                          .map((day) => day.date)
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
