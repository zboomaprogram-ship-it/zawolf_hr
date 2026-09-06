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
import '../../features/attendance_checkin/presentation/attendance_outcome_mapper.dart';
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

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
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

  @override
  void initState() {
    super.initState();
    AttendanceService().syncPendingOfflineAttendance();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    final pilot = _checkInPilot;
    if (pilot != null) unawaited(pilot.close());
    super.dispose();
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
        _checkCurrentGeofence();
        _checkCompanyDayOff();
        _refreshAttendanceGate(user);
        // This only registers Android's branch boundary after the employee
        // has explicitly granted Always Location. It never prompts here.
        AutomaticAttendanceService.instance
            .configureFor(user)
            .catchError((_) {});
        if (_isCheckInPilotEnabledFor(user)) {
          _checkInPilot ??= AttendanceCheckInPilot.create();
          _checkInPilot!.cubit.synchronizePending(user.uid).whenComplete(() {
            if (mounted) setState(() {});
          });
        }
      });
    }
  }

  Future<void> _checkCurrentGeofence() async {
    if (!mounted) return;
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
      await attendanceService.handleCheckInOrCheckOut(
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
      await Future.wait([
        _checkCurrentGeofence(),
        _checkCompanyDayOff(),
        _refreshAttendanceGate(employee),
      ]);

      final log = await attendanceService.loadTodayAttendanceForDisplay(
        employee.uid,
      );

      if (log != null && mounted) {
        final isCheckOut = log.checkOutTime != null;
        final confirmationTime =
            isCheckOut ? log.checkOutTime : log.checkInTime;
        if (confirmationTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم حفظ الحركة محلياً وستتم مزامنتها عند توفر الإنترنت.',
              ),
            ),
          );
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => CheckInConfirmModal(
                isCheckOut: isCheckOut,
                time: confirmationTime,
                locationName: log.locationName,
                status: log.status,
                lateMinutes: log.lateMinutes,
              ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الحركة محلياً وستتم مزامنتها عند توفر الإنترنت.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = _friendlyAttendanceError(e);
        showDialog(
          context: context,
          builder:
              (dialogContext) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  backgroundColor: ZaWolfColors.surface01,
                  title: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: ZaWolfColors.warning,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لم يكتمل تسجيل الحضور',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    message,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      height: 1.7,
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.start,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'حسنًا',
                        style: TextStyle(color: ZaWolfColors.primaryCyan),
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
    final raw = error.toString().replaceAll('Exception: ', '').trim();
    if (kDebugMode) debugPrint('Attendance action failure detail: $error');

    if (raw.contains('INTERNAL ASSERTION') ||
        raw.contains('Unexpected state') ||
        raw.contains('firebase-firestore') ||
        raw.contains('ASSERTION') ||
        raw.contains('gstatic') ||
        raw.contains('b815') ||
        raw.contains('ca9') ||
        raw.contains('__PRIVATE__') ||
        raw.contains('WatchChangeAggregator')) {
      return 'تم تحديث اتصال شبكة البيانات تلقائياً. يمكنك إجراء المحاولة الآن أو إعادة تنشيط الصفحة.';
    }

    if (raw.contains('resource-exhausted') ||
        raw.contains('resource_exhausted') ||
        raw.contains('quota') ||
        raw.contains('RESOURCE_EXHAUSTED')) {
      return 'تم حفظ حضورك محلياً على الجهاز بنجاح لتجاوز الحد اليومي لقواعد البيانات، وستتم المزامنة تلقائياً عند تجديد الحد.';
    }

    if (raw.contains('cloud_firestore/unavailable') ||
        raw.contains('service is currently unavailable') ||
        raw.contains('deadline-exceeded') ||
        raw.contains('aborted') ||
        raw.contains('network') ||
        raw.contains('SocketException')) {
      return 'خدمة الحضور مشغولة مؤقتاً أو يتعذر الاتصال بالشبكة. أعدنا المحاولة تلقائياً، وسيحفظ النظام حضورك للمزامنة فور توفر الإنترنت.';
    }

    if (raw.contains('TimeoutException') ||
        raw.contains('Future not completed') ||
        raw.contains('timeout')) {
      return 'استغرقت عملية تحديد الموقع وقتاً أطول من المعتاد. يرجى التأكد من تشغيل الـ GPS والإنترنت، والانتقال لمكان مكشوف ثم أعد المحاولة.';
    }

    if (raw.contains('permission-denied') ||
        raw.contains('SecurityException')) {
      return 'تعذر حفظ الحضور بسبب إعداد أمان الحساب أو ربط الجهاز. لم يتم تسجيل العملية. أعد فتح التطبيق مرة واحدة؛ وإذا تكرر الخطأ، يراجع HR حالة الحساب وجهاز الحضور من شاشة الموظف.';
    }

    if (raw.contains('Mock GPS') ||
        raw.contains('mock') ||
        raw.contains('تزييف')) {
      return 'تم الكشف عن استخدام تطبيق لتزييف الموقع الجغرافي (Mock GPS). لا يمكن تسجيل الحضور أثناء تفعيل التزييف.';
    }

    if (raw.contains('خارج نطاق') ||
        raw.contains('outside_geofence') ||
        raw.contains('outside')) {
      return 'أنت حالياً خارج نطاق التغطية الجغرافية لفرع العمل الخاص بك. يرجى الاقتراب من الفرع أو التأكد من تفعيل خدمة الموقع الدقيق (GPS).';
    }

    if (raw.contains('location') &&
        (raw.contains('empty') ||
            raw.contains('null') ||
            raw.contains('missing') ||
            raw.contains('تعيين'))) {
      return 'لم يتم تعيين موقع أو فرع عمل لحسابك بعد. يرجى التواصل مع إدارة الموارد البشرية لربط حسابك بفرع العمل الخاص بك.';
    }

    if (raw.contains('دقة') || raw.contains('accuracy')) {
      return 'إشارة موقع GPS ضعيفة جداً. يرجى التواجد في مكان مكشوف والتأكد من تفعيل إذن الموقع الدقيق (High Accuracy) ثم إعادة المحاولة.';
    }

    const outcomes = AttendanceOutcomeMapper();
    if (raw.contains('مسجل') ||
        raw.contains('مكرر') ||
        raw.contains('already_recorded')) {
      return outcomes.messageFor('already_recorded');
    }
    if (raw.contains('انصراف') && raw.contains('مفع')) {
      return outcomes.messageFor('checkout_disabled');
    }
    if (raw.contains('مزامنة')) return outcomes.messageFor('pending_sync');

    return 'لم يتم حفظ تسجيل الحضور لهذه المحاولة، ولم يُسجَّل حضور مكرر. '
        'تأكد من تشغيل الإنترنت والموقع الدقيق، ثم أغلق التطبيق وافتحه وأعد المحاولة. '
        'إذا تكرر الأمر، يراجع HR حالة الحساب وموقع الحضور والجهاز المسجل من شاشة الموظف.';
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
                color: const Color(0xFFFFD700),
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
            final periodSummary = AttendancePeriodSummaryService.buildSummary(
              user: user,
              start: cycle.start,
              end: _now,
              now: _now,
              attendanceByDate: {for (final l in logs) l.date: l},
              approvedLeaves: const [],
              companyDaysOff: const {},
            );

            final workedDays = periodSummary.presentDays;
            // Keep this percentage consistent with خصوماتي: a late label
            // alone is not a payroll deduction until HR has approved it.
            final disciplineScore = periodSummary.disciplinePercentage;

            // Check for unseen celebration badges
            _checkUnseenCelebrationBadges(user);

            return RefreshIndicator(
              onRefresh: () async {
                await attendanceService.syncPendingOfflineAttendance();
                await Future.wait([
                  _checkCurrentGeofence(),
                  _checkCompanyDayOff(),
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

                    if (user.excludeFromAttendanceReports) ...[
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
                                  color: Colors.white,
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

                    // A real grid keeps the same usable tile size on narrow
                    // iPhones and Android phones instead of squeezing three
                    // fixed Row children into every screen width.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 640 ? 3 : 2;
                        final compact = constraints.maxWidth < 380;
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: DsSpacing.md,
                          mainAxisSpacing: DsSpacing.md,
                          childAspectRatio: compact ? 1.08 : 1.3,
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
                              color: Colors.purpleAccent,
                              onTap: () {
                                final dept =
                                    user.department.isNotEmpty
                                        ? user.department
                                        : 'general';
                                context.go('/conversations/department/$dept');
                              },
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
                    ),
                    const SizedBox(height: DsSpacing.xl),

                    MonthActivitySection(logs: logs),
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
