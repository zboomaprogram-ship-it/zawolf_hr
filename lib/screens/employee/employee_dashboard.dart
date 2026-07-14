import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/automatic_attendance_service.dart';
import '../../services/company_day_off_service.dart';
import '../../services/geofence_service.dart';
import '../../models/attendance_model.dart';
import '../../models/attendance_policy.dart';
import '../../models/company_day_off_status.dart';
import '../../models/user_model.dart';
import 'checkin_confirm_modal.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
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
  AttendancePolicyConfig _policyConfig = const AttendancePolicyConfig();
  DateTime? _checkoutAllowedFrom;

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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService>(context).currentUser;
    final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
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
        AutomaticAttendanceService.instance.configureFor(user).catchError((_) {});
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
      final status = await CompanyDayOffService().getDayOffStatus(
        DateTime.now(),
      );
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
    final service = AttendanceService();
    try {
      final results = await Future.wait([
        service.policyConfigForDisplay(),
        service.checkoutAllowedFromForDisplay(user),
      ]);
      if (!mounted) return;
      setState(() {
        _policyConfig = results[0] as AttendancePolicyConfig;
        _checkoutAllowedFrom = results[1] as DateTime;
        _now = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _policyConfig = const AttendancePolicyConfig();
        _checkoutAllowedFrom = null;
        _now = DateTime.now();
      });
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
    try {
      await attendanceService.handleCheckInOrCheckOut(
        employee,
        expectedAction: expectedAction,
      );
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
        final confirmationTime = isCheckOut
            ? log.checkOutTime
            : log.checkInTime;
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
          builder: (context) => CheckInConfirmModal(
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
          builder: (context) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text(
              'خطأ في تسجيل الحضور ⚠️',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              message,
              style: const TextStyle(color: ZaWolfColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'حسناً',
                  style: TextStyle(color: ZaWolfColors.primaryCyan),
                ),
              ),
            ],
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

  String _friendlyAttendanceError(Object error) {
    final raw = error.toString().replaceAll('Exception: ', '');
    if (raw.contains('TimeoutException') ||
        raw.contains('Future not completed')) {
      return 'تعذر تحديد موقعك خلال الوقت المحدد. فعّل GPS، افتح الإنترنت، وانتقل لمكان أقرب لإشارة الموقع ثم أعد المحاولة.';
    }
    if (raw.contains('permission-denied')) {
      return 'لا توجد صلاحية كافية لتنفيذ العملية. حدّث التطبيق وتأكد من نشر قواعد Firebase الأخيرة، أو تواصل مع الإدارة.';
    }
    return raw;
  }

  String _formatGateTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/wolf_head_geometric.png', height: 28),
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
          final attendanceError = snapshot.hasError
              ? 'تعذر تحميل سجل الحضور الآن. يمكنك السحب للتحديث أو المحاولة مرة أخرى.'
              : null;
          final logs = snapshot.data ?? [];
          final todayLog = logs.firstWhere(
            (log) => log.date == todayStr,
            orElse: () => AttendanceModel(
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
          final checkInOpenAt = AttendancePolicy.parseTimeOnDate(
            _now,
            _policyConfig.checkInOpenTime,
          );
          final checkoutAllowedFrom =
              _checkoutAllowedFrom ??
              AttendancePolicy.parseTimeOnDate(
                _now,
                user.workSchedule.endTime ?? _policyConfig.defaultEndTime,
              );
          final latestCheckoutAt = AttendancePolicy.parseTimeOnDate(
            _now,
            _policyConfig.latestCheckoutTime,
          );
          final checkInNotOpenYet =
              !hasCheckedIn && _now.isBefore(checkInOpenAt);
          final checkoutNotOpenYet =
              hasCheckedIn &&
              !hasCheckedOut &&
              _now.isBefore(checkoutAllowedFrom);
          final checkoutExpired =
              hasCheckedIn && !hasCheckedOut && _now.isAfter(latestCheckoutAt);
          final bool checkInDisabledForDayOff =
              !hasTodayRecord && _dayOffStatus.isDayOff;
          final bool actionDisabled =
              _actionLoading ||
              hasCheckedOut ||
              checkInDisabledForDayOff ||
              checkInNotOpenYet ||
              checkoutNotOpenYet ||
              checkoutExpired;
          final expectedAction = hasCheckedIn
              ? AttendanceActionIntent.checkOut
              : AttendanceActionIntent.checkIn;
          final actionTitle = hasCheckedOut
              ? 'اكتمل اليوم'
              : checkInDisabledForDayOff
              ? 'عطلة اليوم'
              : checkInNotOpenYet
              ? 'يفتح ${_formatGateTime(checkInOpenAt)}'
              : checkoutExpired
              ? 'انتهى اليوم'
              : checkoutNotOpenYet
              ? 'يفتح ${_formatGateTime(checkoutAllowedFrom)}'
              : hasCheckedIn
              ? 'تسجيل انصراف'
              : 'تسجيل حضور';
          final actionSubtitle = hasCheckedOut
              ? 'COMPLETED'
              : checkInDisabledForDayOff
              ? 'DAY OFF'
              : checkInNotOpenYet
              ? 'CHECK IN LATER'
              : checkoutExpired
              ? 'CHECKOUT CLOSED'
              : checkoutNotOpenYet
              ? 'CHECK OUT AT ${_formatGateTime(checkoutAllowedFrom)}'
              : hasCheckedIn
              ? 'CHECK OUT'
              : 'CHECK IN';
          final actionIcon = hasCheckedOut
              ? Icons.lock_clock
              : checkInDisabledForDayOff
              ? Icons.event_busy
              : checkInNotOpenYet || checkoutNotOpenYet || checkoutExpired
              ? Icons.schedule
              : hasCheckedIn
              ? Icons.logout
              : Icons.fingerprint;

          // Quick stats calculation
          final workedDays = logs.where((l) => l.checkInTime != null).length;
          final lates = logs.where((l) => l.isLate).length;
          final absents = logs
              .where((l) => l.status == 'absent')
              .length; // normally we mark defaults, let's keep it simple

          double disciplineScore = 100.0 - (lates * 5.0) - (absents * 10.0);
          if (disciplineScore < 0.0) disciplineScore = 0.0;

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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface01,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZaWolfColors.surface03),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _checkingLocation
                              ? null
                              : _checkCurrentGeofence,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_geofenceResult?.isWithinZone == true
                                          ? ZaWolfColors.success
                                          : ZaWolfColors.error)
                                      .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (_geofenceResult?.isWithinZone == true
                                            ? ZaWolfColors.success
                                            : ZaWolfColors.error)
                                        .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_checkingLocation)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ZaWolfColors.primaryCyan,
                                    ),
                                  )
                                else
                                  Icon(
                                    _geofenceResult?.isWithinZone == true
                                        ? Icons.location_on
                                        : Icons.location_off,
                                    size: 16,
                                    color: _geofenceResult?.isWithinZone == true
                                        ? ZaWolfColors.success
                                        : ZaWolfColors.error,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  _checkingLocation
                                      ? 'جاري التحديد'
                                      : _geofenceResult?.isWithinZone == true
                                      ? 'داخل النطاق'
                                      : 'خارج النطاق',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            _geofenceResult?.isWithinZone ==
                                                true
                                            ? ZaWolfColors.success
                                            : ZaWolfColors.error,
                                        fontWeight: FontWeight.w700,
                                      ) ??
                                      TextStyle(
                                        color:
                                            _geofenceResult?.isWithinZone ==
                                                true
                                            ? ZaWolfColors.success
                                            : ZaWolfColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'مرحباً، ${user.displayName}',
                                style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontSize: 22,
                                    ) ??
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                              Text(
                                '${user.position} · ${user.department}',
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_locationError != null) ...[
                    WolfCard(
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _checkingLocation
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

                  // Circular Pulsing Action Button
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Decorative glowing rings
                        if (!actionDisabled)
                          _buildRadarRing(
                            hasCheckedIn
                                ? ZaWolfColors.error
                                : ZaWolfColors.success,
                          ),

                        // Main check-in button container
                        GestureDetector(
                          onTap: actionDisabled
                              ? null
                              : () => _handleCheckInCheckOut(
                                  user,
                                  expectedAction,
                                ),
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              gradient: actionDisabled && !hasCheckedIn
                                  ? const LinearGradient(
                                      colors: [
                                        ZaWolfColors.surface03,
                                        ZaWolfColors.surface01,
                                      ],
                                    )
                                  : hasCheckedOut
                                  ? const LinearGradient(
                                      colors: [
                                        ZaWolfColors.surface03,
                                        ZaWolfColors.surface01,
                                      ],
                                    )
                                  : hasCheckedIn
                                  ? const LinearGradient(
                                      colors: [
                                        ZaWolfColors.error,
                                        Color(0xFFC62828),
                                      ],
                                    )
                                  : ZaWolfColors.primaryGradient,
                              boxShadow: actionDisabled
                                  ? []
                                  : [
                                      BoxShadow(
                                        color:
                                            (hasCheckedIn
                                                    ? ZaWolfColors.error
                                                    : ZaWolfColors.primaryCyan)
                                                .withValues(alpha: 0.35),
                                        blurRadius: 30,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                            ),
                            child: _actionLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        actionIcon,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        actionTitle,
                                        style:
                                            theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ) ??
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        actionSubtitle,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.white70,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ) ??
                                            const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_checkingDayOff || checkInDisabledForDayOff) ...[
                    WolfCard(
                      child: Row(
                        children: [
                          Icon(
                            _checkingDayOff
                                ? Icons.sync
                                : Icons.event_busy_outlined,
                            color: _checkingDayOff
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
                                    color: _checkingDayOff
                                        ? ZaWolfColors.textSecondary
                                        : ZaWolfColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ) ??
                                  TextStyle(
                                    color: _checkingDayOff
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

                  // Location and Lateness Badge Card
                  if (hasCheckedIn)
                    WolfCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (todayLog.checkInTime case final checkInTime?)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'حضور اليوم: ${DateFormat('hh:mm a').format(checkInTime)}',
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ) ??
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                if (todayLog.checkOutTime
                                    case final checkOutTime?)
                                  Text(
                                    'انصراف اليوم: ${DateFormat('hh:mm a').format(checkOutTime)}',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ) ??
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  )
                                else
                                  Text(
                                    'قيد العمل في فرع (${todayLog.locationName})',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            )
                          else
                            Text(
                              'لم يتم تسجيل وقت حضور صالح لهذا اليوم.',
                              style:
                                  theme.textTheme.bodyMedium?.copyWith(
                                    color: ZaWolfColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ) ??
                                  const TextStyle(
                                    color: ZaWolfColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: todayLog.isLate
                                  ? ZaWolfColors.warning.withValues(alpha: 0.2)
                                  : ZaWolfColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              todayLog.isLate
                                  ? '${todayLog.salaryDeductionLabel} · ${todayLog.salaryDeductionAmount.toStringAsFixed(2)} ${todayLog.salaryCurrency}'
                                  : 'في الموعد',
                              style: TextStyle(
                                color: todayLog.isLate
                                    ? ZaWolfColors.warning
                                    : ZaWolfColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  // Quick Action Buttons Row
                  Row(
                    children: [
                      _buildQuickAction(
                        theme: theme,
                        icon: Icons.access_time,
                        label: 'طلب إذن',
                        subtitle: 'Permission',
                        color: ZaWolfColors.permissionTeal,
                        onTap: () => context.go('/employee/requests'),
                      ),
                      const SizedBox(width: 12),
                      _buildQuickAction(
                        theme: theme,
                        icon: Icons.calendar_month,
                        label: 'طلب إجازة',
                        subtitle: 'Official Leave',
                        color: ZaWolfColors.primaryCyan,
                        onTap: () => context.go('/employee/requests'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Quick Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        theme: theme,
                        value: '$workedDays ي',
                        label: 'أيام الحضور',
                        englishLabel: 'Presence',
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        theme: theme,
                        value: '${disciplineScore.toInt()}%',
                        label: 'الانضباط',
                        englishLabel: 'Discipline',
                        color: disciplineScore >= 85
                            ? ZaWolfColors.success
                            : ZaWolfColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Recent Activity Feed
                  Text(
                    'النشاط الأخير (هذا الشهر)',
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (logs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            color: ZaWolfColors.textMuted,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد سجلات حضور هذا الشهر.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: logs.length > 5 ? 5 : logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final dateParsed = DateTime.parse(log.date);
                        final formatDay = DateFormat(
                          'EEEE dd MMM',
                          'ar',
                        ).format(dateParsed);
                        final checkInTime = log.checkInTime;
                        final checkOutTime = log.checkOutTime;
                        final checkInText = checkInTime == null
                            ? 'لم يسجل حضور'
                            : 'حضور: ${DateFormat('hh:mm a').format(checkInTime)}';
                        final checkOutText = checkOutTime == null
                            ? null
                            : 'انصراف: ${DateFormat('hh:mm a').format(checkOutTime)}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface01,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ZaWolfColors.surface03),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatDay,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ) ??
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    checkInText,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (checkOutText != null)
                                    Text(
                                      checkOutText,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    log.status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusLabel(log.status),
                                  style: TextStyle(
                                    color: _getStatusColor(log.status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadarRing(Color color) {
    return Container(
      width: 176,
      height: 176,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
    );
  }

  Widget _buildQuickAction({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface01,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
              ),
              Text(
                subtitle.toUpperCase(),
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: ZaWolfColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ) ??
                    const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String value,
    required String label,
    required String englishLabel,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface01,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZaWolfColors.surface03),
        ),
        child: Column(
          children: [
            Text(
              value,
              style:
                  theme.textTheme.titleLarge?.copyWith(
                    color: color ?? ZaWolfColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                  ) ??
                  TextStyle(
                    color: color ?? ZaWolfColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ) ??
                  const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            Text(
              englishLabel.toUpperCase(),
              style:
                  theme.textTheme.bodySmall?.copyWith(
                    color: ZaWolfColors.textMuted,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ) ??
                  const TextStyle(
                    color: ZaWolfColors.textMuted,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return ZaWolfColors.success;
      case 'late':
        return ZaWolfColors.warning;
      case 'on-leave':
        return ZaWolfColors.primaryBlue;
      case 'absent':
        return ZaWolfColors.error;
      default:
        return ZaWolfColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'on-leave':
        return 'إجازة';
      case 'absent':
        return 'غائب';
      default:
        return status;
    }
  }
}
