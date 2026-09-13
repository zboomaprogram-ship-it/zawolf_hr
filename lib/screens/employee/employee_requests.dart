import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/meeting_requests/data/meeting_repository_impl.dart';
import '../../features/meeting_requests/presentation/meeting_requests_list_screen.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../utils/user_facing_error.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../components/request_approval_timeline.dart';
import '../../design_system/components/confirmation_sheet.dart';
import '../../design_system/components/feedback_states.dart';
import '../../design_system/components/filter_bar.dart';
import '../../design_system/components/skeletons.dart';
import '../../design_system/components/status_pill.dart';
import '../../design_system/tokens.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/leave_service.dart';
import '../../services/complaint_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/advance_service.dart';
import '../../services/resignation_service.dart';
import '../../services/administrative_request_service.dart';
import '../../services/attendance_correction_request_service.dart';
import '../../services/governed_drive_attachment_service.dart';
import '../../services/task_service.dart';
import '../../models/attendance_model.dart';
import '../../models/attendance_policy.dart';
import '../../models/permission_model.dart';
import '../../models/permission_type_policy.dart';
import '../../models/leave_model.dart';
import '../../models/leave_type_policy.dart';
import '../../models/leave_entitlement_policy.dart';
import '../../models/advance_model.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../models/resignation_model.dart';
import '../../models/administrative_request_model.dart';
import '../../models/task_model.dart';
import '../shared/requests_log_screen.dart';
import '../../utils/payroll_cycle.dart';
import '../../utils/permission_cycle_accounting.dart';
import '../../core/feature_flags/company_os_feature_flags.dart';
import 'widgets/virtual_office_game_widget.dart';

enum _RequestAttachmentSource { gallery, files }

class EmployeeRequestsScreen extends StatefulWidget {
  const EmployeeRequestsScreen({
    super.key,
    this.initialView = 1,
    this.initialHistoryFilter = 'all',
    this.initialHistoryTab = 0,
    this.initialRequestId,
  });

  /// 1 is the request form and 2 is the employee-owned request history.
  final int initialView;
  final String initialHistoryFilter;
  final int initialHistoryTab;
  final String? initialRequestId;

  @override
  State<EmployeeRequestsScreen> createState() => _EmployeeRequestsScreenState();
}

class _EmployeeRequestsScreenState extends State<EmployeeRequestsScreen> {
  final _formKeyPermission = GlobalKey<FormState>();
  final _formKeyLeave = GlobalKey<FormState>();
  final _formKeyComplaint = GlobalKey<FormState>();
  final _formKeyResignation = GlobalKey<FormState>();
  final _formKeyAdministrative = GlobalKey<FormState>();
  final _formKeyAttendanceCorrection = GlobalKey<FormState>();

  // Permission form fields
  String _permissionType = PermissionTypePolicy.earlyLeave;
  DateTime _permissionDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _permissionDurationHours = 2;
  bool _isDeductiblePermission = false;
  final _permissionReasonController = TextEditingController();

  // Leave form fields
  String _leaveType = LeaveTypePolicy.normal;
  DateTime _leaveStart = DateTime.now().add(const Duration(days: 2));
  DateTime _leaveEnd = DateTime.now().add(const Duration(days: 2));
  bool _leaveMultipleDays = false;
  bool _convertSickToAnnual = false;
  int? _leaveWorkingDays;
  final _leaveReasonController = TextEditingController();
  final _workHandoverController = TextEditingController();
  final _leaveAttachmentController = TextEditingController();
  String? _attachmentUrl;

  // Advance form fields
  final _formKeyAdvance = GlobalKey<FormState>();
  final _advanceAmountController = TextEditingController();
  final _advanceReasonController = TextEditingController();

  final _complaintTitleController = TextEditingController();
  final _complaintBodyController = TextEditingController();
  final _complaintAttachmentController = TextEditingController();
  bool _submitComplaintAnonymously = false;
  String? _complaintAttachmentUrl;
  final _resignationReasonController = TextEditingController();
  DateTime _resignationDate = DateTime.now().add(const Duration(days: 30));
  String _administrativeCategory = AdministrativeRequestCategory.personalData;
  final _administrativeNotesController = TextEditingController();
  final _administrativeAttachmentController = TextEditingController();
  String? _administrativeAttachmentUrl;
  final _fieldMissionSiteController = TextEditingController();
  final _fieldMissionReasonController = TextEditingController();
  final _formKeyFieldMission = GlobalKey<FormState>();
  DateTime _fieldMissionDate = DateTime.now();
  TimeOfDay _fieldMissionStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fieldMissionEnd = const TimeOfDay(hour: 17, minute: 0);
  // A field mission is an approved absence from the office. HR can explicitly
  // turn either requirement back on when the mission policy needs it.
  bool _fieldMissionRequiresReturn = false;
  bool _fieldMissionRequiresCheckout = false;
  final _attendanceCorrectionReasonController = TextEditingController();
  AttendanceModel? _selectedCorrectionAttendance;
  TimeOfDay? _requestedCorrectionTime;

  bool _loading = false;
  // The request centre intentionally keeps creation and history in one
  // surface.  This replaces the old two-tab design while retaining the
  // existing forms and history streams during the gradual migration.
  // Sending a request must always be the quickest path. The virtual office is
  // an optional discovery experience, never a gate in front of a HR request.
  int _requestCentreView = 1;
  int _requestTypeIndex = 0;
  String _historyStatusFilter = 'all';
  final Map<String, Stream<dynamic>> _streamCache = {};

  @override
  void initState() {
    super.initState();
    _requestCentreView =
        (widget.initialView == 2 || widget.initialRequestId != null) ? 2 : 1;
    _historyStatusFilter =
        widget.initialRequestId != null ? 'all' : widget.initialHistoryFilter;
  }

  @override
  void didUpdateWidget(covariant EmployeeRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.initialView == 2 || widget.initialRequestId != null) &&
        (oldWidget.initialHistoryFilter != widget.initialHistoryFilter ||
            oldWidget.initialHistoryTab != widget.initialHistoryTab ||
            oldWidget.initialRequestId != widget.initialRequestId ||
            oldWidget.initialView != widget.initialView)) {
      setState(() {
        _requestCentreView = 2;
        _historyStatusFilter =
            widget.initialRequestId != null ? 'all' : widget.initialHistoryFilter;
      });
    }
  }

  bool _isHighlightedRequest(String? docId, [String? modelId]) {
    final target = widget.initialRequestId?.trim();
    if (target == null || target.isEmpty) return false;
    return (docId != null && docId.trim() == target) ||
        (modelId != null && modelId.trim() == target);
  }

  Stream<T> _cachedStream<T>(String key, Stream<T> Function() create) {
    return _streamCache.putIfAbsent(key, create) as Stream<T>;
  }

  @override
  void dispose() {
    _permissionReasonController.dispose();
    _leaveReasonController.dispose();
    _workHandoverController.dispose();
    _leaveAttachmentController.dispose();
    _advanceAmountController.dispose();
    _advanceReasonController.dispose();
    _complaintTitleController.dispose();
    _complaintBodyController.dispose();
    _complaintAttachmentController.dispose();
    _resignationReasonController.dispose();
    _administrativeNotesController.dispose();
    _administrativeAttachmentController.dispose();
    _fieldMissionSiteController.dispose();
    _fieldMissionReasonController.dispose();
    _attendanceCorrectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'اختر وقت المغادرة',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: Colors.black,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _attachmentContentType(String? extension) => switch ((extension ?? '')
      .toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };

  Future<String?> _uploadRequestAttachment() async {
    final source = await showModalBottomSheet<_RequestAttachmentSource>(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('صورة من المعرض'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        _RequestAttachmentSource.gallery,
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('ملف من الجهاز'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        _RequestAttachmentSource.files,
                      ),
                ),
              ],
            ),
          ),
    );
    if (source == null) return null;

    String? name;
    String? extension;
    List<int>? bytes;
    if (source == _RequestAttachmentSource.gallery) {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      name = image?.name;
      extension = name?.split('.').last;
      bytes = await image?.readAsBytes();
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      final file = result?.files.singleOrNull;
      name = file?.name;
      extension = file?.extension;
      bytes = file?.bytes;
    }
    if (name == null || bytes == null || !mounted) return null;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('اختر ملفاً صالحاً بحجم لا يتجاوز 10 ميغابايت');
    }
    return (await GovernedDriveAttachmentService().upload(
      fileName: name,
      contentType: _attachmentContentType(extension),
      bytes: bytes,
    )).opaqueUri;
  }

  Future<void> _pickAndStoreAttachment({
    required TextEditingController controller,
    required ValueChanged<String?> onStored,
  }) async {
    try {
      setState(() => _loading = true);
      final uri = await _uploadRequestAttachment();
      if (uri == null || !mounted) return;
      onStored(uri);
      controller.text = '📎 تم حفظ المرفق في ملفات الشركة';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ المرفق في Google Drive.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay _workTime(String? value, TimeOfDay fallback) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _resolvedPermissionTime(UserModel employee) {
    final start = _workTime(
      employee.workSchedule.startTime,
      const TimeOfDay(hour: 9, minute: 0),
    );
    final end = _workTime(
      employee.workSchedule.endTime,
      const TimeOfDay(hour: 17, minute: 0),
    );
    final minutes = PermissionTypePolicy.resolveExpectedMinutes(
      permissionType: _permissionType,
      durationMinutes: _permissionDurationHours * 60,
      workStartMinutes: start.hour * 60 + start.minute,
      workEndMinutes: end.hour * 60 + end.minute,
      selectedMinutes: _selectedTime.hour * 60 + _selectedTime.minute,
    );
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  String? _permissionTimeError(UserModel employee) {
    if (_permissionType != PermissionTypePolicy.midShiftExit) return null;
    final workStart = _workTime(
      employee.workSchedule.startTime,
      const TimeOfDay(hour: 9, minute: 0),
    );
    final workEnd = _workTime(
      employee.workSchedule.endTime,
      const TimeOfDay(hour: 17, minute: 0),
    );
    final startMinutes = workStart.hour * 60 + workStart.minute;
    final endMinutes = workEnd.hour * 60 + workEnd.minute;
    final departureMinutes = _selectedTime.hour * 60 + _selectedTime.minute;
    final returnMinutes = departureMinutes + _permissionDurationHours * 60;
    if (departureMinutes < startMinutes || departureMinutes >= endMinutes) {
      return 'وقت المغادرة يجب أن يكون داخل ساعات عملك.';
    }
    if (returnMinutes > endMinutes) {
      return 'وقت العودة يتجاوز موعد الانصراف. اختر وقتاً أبكر أو مدة أقل.';
    }
    return null;
  }

  Future<void> _selectPermissionDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _permissionDate.isBefore(today) ? today : _permissionDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: Colors.black,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && picked != _permissionDate) {
      setState(() => _permissionDate = picked);
    }
  }

  Future<void> _selectLeaveDateRange(
    BuildContext context,
    String leaveType,
    UserModel user,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstAllowed =
        leaveType == LeaveTypePolicy.normal
            ? today.add(const Duration(days: 2))
            : today;
    final initialStart =
        _leaveStart.isBefore(firstAllowed) ? firstAllowed : _leaveStart;
    final initialEnd =
        _leaveEnd.isBefore(initialStart) ? initialStart : _leaveEnd;
    if (!_leaveMultipleDays) {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialStart,
        firstDate: firstAllowed,
        lastDate: today.add(const Duration(days: 365)),
        locale: const Locale('ar'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: ZaWolfColors.primaryCyan,
                onPrimary: Colors.black,
                surface: ZaWolfColors.surface01,
                onSurface: Colors.white,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (picked != null) {
        setState(() {
          _leaveStart = picked;
          _leaveEnd = picked;
        });
        await _refreshLeaveWorkingDays(user);
      }
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: firstAllowed,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: Colors.black,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _leaveStart = picked.start;
        _leaveEnd = picked.end;
      });
      await _refreshLeaveWorkingDays(user);
    }
  }

  Future<void> _refreshLeaveWorkingDays(UserModel user) async {
    final start = DateFormat('yyyy-MM-dd').format(_leaveStart);
    final end = DateFormat('yyyy-MM-dd').format(_leaveEnd);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('companyDayOffs')
              .where('date', isGreaterThanOrEqualTo: start)
              .where('date', isLessThanOrEqualTo: end)
              .get();
      final dayOffKeys =
          snapshot.docs
              .where((doc) => doc.data()['isActive'] == true)
              .map((doc) => '${doc.data()['date'] ?? doc.id}')
              .toSet();
      final days = LeaveService.countChargeableDays(
        start: _leaveStart,
        end: _leaveEnd,
        schedule: user.workSchedule,
        companyDayOffKeys: dayOffKeys,
      );
      if (mounted) setState(() => _leaveWorkingDays = days);
    } catch (_) {
      // The submission service repeats this calculation authoritatively.
      if (mounted) setState(() => _leaveWorkingDays = null);
    }
  }

  void _setLeaveType(String type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstAllowed =
        type == LeaveTypePolicy.normal
            ? today.add(const Duration(days: 2))
            : today;
    setState(() {
      _leaveType = type;
      if (_leaveStart.isBefore(firstAllowed)) {
        _leaveStart = firstAllowed;
      }
      // A type change returns to a single-day request. This prevents a birth
      // leave from inheriting a previously selected multi-day range.
      _leaveEnd = _leaveStart;
      _leaveMultipleDays = false;
      _leaveWorkingDays = null;
    });
  }

  // Submission handlers
  Future<void> _submitPermission(
    UserModel employee,
    PermissionCycleUsage cycleUsage,
  ) async {
    if (!_formKeyPermission.currentState!.validate()) return;
    final timingError = _permissionTimeError(employee);
    if (timingError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text(timingError),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final service = PermissionService();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_permissionDate);
      final monthKey = PayrollCycle.keyFor(_permissionDate);

      final expectedTime = _resolvedPermissionTime(employee);
      final expectedTimeStr =
          '${expectedTime.hour.toString().padLeft(2, '0')}:${expectedTime.minute.toString().padLeft(2, '0')}';

      final quotaExhausted = PermissionTypePolicy.isRegularQuotaExhausted(
        usedCount: cycleUsage.usedCount,
        usedHours: cycleUsage.usedHours,
      );

      final req = PermissionModel(
        permissionId: '',
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        department: employee.department,
        locationId: employee.locationId,
        managerId: employee.managerId ?? '',
        permissionType: _permissionType,
        requestDate: dateStr,
        expectedTime: expectedTimeStr,
        durationMinutes: _permissionDurationHours * 60,
        reason: _permissionReasonController.text.trim(),
        status: 'pending',
        isExceedingQuota: quotaExhausted,
        isDeductible: _isDeductiblePermission || quotaExhausted,
        isSubmittedAfterWorkStart: false,
        monthKey: monthKey,
      );

      await service.submitPermission(req, employee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال طلب الإذن بنجاح'),
          ),
        );
        _permissionReasonController.clear();
        setState(() {
          _permissionDate = DateTime.now();
          _isDeductiblePermission = false;
        });
        setState(() => _requestCentreView = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل الإرسال: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAdministrativeRequest(UserModel employee) async {
    if (!_formKeyAdministrative.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = AdministrativeRequestService();
      if (_administrativeCategory ==
          AdministrativeRequestCategory.fieldMission) {
        String time(TimeOfDay value) =>
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        await service.submitFieldMission(
          employee: employee,
          date: _fieldMissionDate,
          startTime: time(_fieldMissionStart),
          endTime: time(_fieldMissionEnd),
          siteName: _fieldMissionSiteController.text,
          reason: _administrativeNotesController.text,
          requiresReturnToOffice: _fieldMissionRequiresReturn,
          requiresCheckout: _fieldMissionRequiresCheckout,
        );
      } else {
        await service.submit(
          employee: employee,
          category: _administrativeCategory,
          notes: _administrativeNotesController.text,
          attachmentUrl: _administrativeAttachmentUrl,
        );
      }
      _administrativeNotesController.clear();
      _administrativeAttachmentController.clear();
      _administrativeAttachmentUrl = null;
      _fieldMissionSiteController.clear();
      _fieldMissionReasonController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال الطلب الإداري بنجاح'),
          ),
        );
        setState(() => _requestCentreView = 1);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('تعذر الإرسال: ${userFacingError(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitFieldMissionDirect(UserModel employee) async {
    if (!_formKeyFieldMission.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = AdministrativeRequestService();
      String time(TimeOfDay value) =>
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      await service.submitFieldMission(
        employee: employee,
        date: _fieldMissionDate,
        startTime: time(_fieldMissionStart),
        endTime: time(_fieldMissionEnd),
        siteName: _fieldMissionSiteController.text,
        reason: _fieldMissionReasonController.text,
        requiresReturnToOffice: _fieldMissionRequiresReturn,
        requiresCheckout: _fieldMissionRequiresCheckout,
      );
      _fieldMissionReasonController.clear();
      _fieldMissionSiteController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال طلب المهمة الميدانية بنجاح'),
          ),
        );
        setState(() => _requestCentreView = 1);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('تعذر الإرسال: ${userFacingError(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAttendanceCorrection(UserModel employee) async {
    if (!_formKeyAttendanceCorrection.currentState!.validate()) return;
    final attendance = _selectedCorrectionAttendance;
    final selectedTime = _requestedCorrectionTime;
    if (attendance == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر يوم الحضور والوقت الصحيح.')),
      );
      return;
    }

    final day = attendance.checkInTime!;
    setState(() => _loading = true);
    try {
      await AttendanceCorrectionRequestService().submit(
        employee: employee,
        attendance: attendance,
        requestedCheckInTime: DateTime(
          day.year,
          day.month,
          day.day,
          selectedTime.hour,
          selectedTime.minute,
        ),
        reason: _attendanceCorrectionReasonController.text,
      );
      _attendanceCorrectionReasonController.clear();
      setState(() {
        _selectedCorrectionAttendance = null;
        _requestedCorrectionTime = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال طلب تصحيح الوقت إلى HR.'),
          ),
        );
        setState(() => _requestCentreView = 1);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(userFacingError(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLeave(UserModel employee) async {
    if (!_formKeyLeave.currentState!.validate()) return;

    setState(() => _loading = true);
    final service = LeaveService();
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final days = _leaveEnd.difference(_leaveStart).inDays + 1;
      final leaveType =
          LeaveEntitlementPolicy.isOnProbation(
                employee.hiringDate,
                onDate: _leaveStart,
              )
              ? LeaveTypePolicy.unpaid
              : _leaveType;

      final req = LeaveModel(
        leaveId: '',
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        department: employee.department,
        locationId: employee.locationId,
        managerId: employee.managerId ?? '',
        leaveType: leaveType,
        startDate: _leaveStart,
        endDate: _leaveEnd,
        numberOfDays: days,
        reason: _leaveReasonController.text.trim(),
        attachmentUrl: _attachmentUrl,
        convertToAnnual: _convertSickToAnnual,
        workHandoverTo: _workHandoverController.text.trim(),
        status: 'pending',
      );

      await service.submitLeaveRequest(req, employee);
      await authService.fetchUserData(employee.uid, showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم تقديم طلب الإجازة بنجاح'),
          ),
        );
        _leaveReasonController.clear();
        _workHandoverController.clear();
        _leaveAttachmentController.clear();
        final today = DateTime.now();
        final nextStart = DateTime(
          today.year,
          today.month,
          today.day,
        ).add(Duration(days: leaveType == LeaveTypePolicy.normal ? 2 : 0));
        setState(() {
          _attachmentUrl = null;
          _convertSickToAnnual = false;
          _leaveStart = nextStart;
          _leaveEnd = nextStart;
        });
        setState(() => _requestCentreView = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل التقديم: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAdvance(UserModel employee) async {
    if (!_formKeyAdvance.currentState!.validate()) return;

    setState(() => _loading = true);
    final service = AdvanceService();

    try {
      final now = DateTime.now();
      final monthKey = PayrollCycle.keyFor(now);

      final req = AdvanceModel(
        advanceId: '',
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        department: employee.department,
        locationId: employee.locationId,
        managerId: employee.managerId ?? '',
        amount: double.parse(_advanceAmountController.text),
        reason: _advanceReasonController.text.trim(),
        status: 'pending',
        monthKey: monthKey,
      );

      await service.submitAdvanceRequest(req, employee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم تقديم طلب السلفة بنجاح'),
          ),
        );
        _advanceAmountController.clear();
        _advanceReasonController.clear();
        setState(() => _requestCentreView = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل التقديم: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitComplaint(UserModel employee) async {
    if (!_formKeyComplaint.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ComplaintService().submitComplaint(
        employee: employee,
        title: _complaintTitleController.text,
        body: _complaintBodyController.text,
        attachmentUrl: _complaintAttachmentUrl,
        isAnonymous: _submitComplaintAnonymously,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم إرسال الشكوى بنجاح'),
          ),
        );
        _complaintTitleController.clear();
        _complaintBodyController.clear();
        _complaintAttachmentController.clear();
        setState(() {
          _submitComplaintAnonymously = false;
          _complaintAttachmentUrl = null;
        });
        setState(() => _requestCentreView = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل إرسال الشكوى: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitResignation(UserModel employee) async {
    if (!_formKeyResignation.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ResignationService().submit(
        employee: employee,
        reason: _resignationReasonController.text,
        resignationDate: _resignationDate,
      );
      if (!mounted) return;
      _resignationReasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الاستقالة بنجاح')),
      );
      setState(() => _requestCentreView = 1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text('فشل الإرسال: ${userFacingError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmCancel(
    String collectionPath,
    String docId, {
    String? message,
  }) async {
    final confirmed = await showConfirmationSheet(
      context,
      title: 'حذف الطلب',
      message:
          message ??
          'سيتم إلغاء الطلب وحذفه من قائمة الطلبات النشطة. يبقى سجل داخلي لحماية حقوقك.',
      confirmLabel: 'حذف الطلب',
    );
    if (!confirmed || !mounted) return false;
    return _cancelRequest(collectionPath, docId);
  }

  Future<bool> _cancelRequest(String collectionPath, String docId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final actorId = authService.currentUser?.uid ?? '';
    try {
      if (collectionPath == 'permissions') {
        await PermissionService().cancelPermission(docId, actorId);
      } else if (collectionPath == 'leaves') {
        await LeaveService().cancelLeave(docId, actorId);
        await authService.fetchUserData(actorId, showLoading: false);
      } else if (collectionPath == 'attendanceCorrectionRequests') {
        await AttendanceCorrectionRequestService().cancelRequest(
          docId,
          actorId,
        );
      } else if (collectionPath == 'advances') {
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(docId)
            .update({'status': 'cancelled'});
      } else {
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(docId)
            .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': actorId,
            });
      }
      await AuditLogService.instance.record(
        actorId: actorId,
        action: 'request_cancelled',
        targetCollection: collectionPath,
        targetId: docId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطلب من القائمة النشطة')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل الإلغاء: ${userFacingError(e)}'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _editLeaveRequest(LeaveModel request) async {
    final cancelled = await _cancelRequest('leaves', request.leaveId);
    if (!cancelled) return;
    if (!mounted) return;
    setState(() {
      _requestTypeIndex = 1;
      _leaveType = request.leaveType;
      _leaveStart = request.startDate;
      _leaveEnd = request.endDate;
      _leaveReasonController.text = request.reason ?? '';
      _workHandoverController.text = request.workHandoverTo;
      _attachmentUrl = request.attachmentUrl;
      _leaveAttachmentController.text = request.attachmentUrl ?? '';
    });
    setState(() => _requestCentreView = 1);
  }

  Future<void> _editPermissionRequest(PermissionModel request) async {
    final cancelled = await _cancelRequest('permissions', request.permissionId);
    if (!cancelled) return;
    if (!mounted) return;
    final time = request.expectedTime.split(':');
    setState(() {
      _requestTypeIndex = 0;
      _permissionType = request.permissionType;
      _permissionDate = DateTime.parse(request.requestDate);
      _selectedTime = TimeOfDay(
        hour: int.parse(time[0]),
        minute: int.parse(time[1]),
      );
      _permissionDurationHours = (request.durationMinutes / 60).round();
      _isDeductiblePermission = request.isDeductible;
      _permissionReasonController.text = request.reason;
    });
    setState(() => _requestCentreView = 1);
  }

  Future<void> _editAdvanceRequest(AdvanceModel request) async {
    final cancelled = await _cancelRequest('advances', request.advanceId);
    if (!cancelled || !mounted) return;
    setState(() {
      _requestTypeIndex = 2;
      _advanceAmountController.text = request.amount.toStringAsFixed(2);
      _advanceReasonController.text = request.reason ?? '';
      _requestCentreView = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'المقر الافتراضي ومركز الخدمات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _requestCentreView == 2 ? 'تقديم طلب جديد' : 'سجل طلباتي',
            icon: Icon(
              _requestCentreView == 2
                  ? Icons.add_circle_outline_rounded
                  : Icons.history_outlined,
            ),
            onPressed:
                () => setState(() {
                  _requestCentreView = _requestCentreView == 2 ? 1 : 2;
                }),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_requestCentreView == 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _requestCentreView = 1),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('إرسال طلب مباشر'),
                  )
                else if (_requestCentreView == 2)
                  TextButton.icon(
                    onPressed: () => setState(() => _requestCentreView = 1),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('تقديم طلب جديد'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _requestCentreView = 0),
                    icon: const Icon(Icons.sports_esports_outlined),
                    label: const Text('استكشف المقر الافتراضي'),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                _requestCentreView == 0
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream:
                            FirebaseFirestore.instance
                                .collection('attendance')
                                .doc(
                                  '${user.uid}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                                )
                                .snapshots(),
                        builder:
                            (
                              context,
                              attendanceSnapshot,
                            ) => StreamBuilder<List<EmployeeTaskModel>>(
                              stream: TaskService().watchMyTasks(user.uid),
                              builder: (context, taskSnapshot) {
                                final weekStart = DateTime.now().subtract(
                                  Duration(days: DateTime.now().weekday - 1),
                                );
                                final completedThisWeek =
                                    (taskSnapshot.data ??
                                            const <EmployeeTaskModel>[])
                                        .where(
                                          (task) =>
                                              task.status == TaskStatus.done &&
                                              task.completedAt != null &&
                                              !task.completedAt!.isBefore(
                                                weekStart,
                                              ),
                                        )
                                        .length;
                                return VirtualOfficeGameWidget(
                                  user: user,
                                  attendedToday:
                                      attendanceSnapshot.data?.exists ?? false,
                                  completedTasksThisWeek: completedThisWeek,
                                  onHotspotTapped:
                                      (hotspot) => _handleHotspotAction(
                                        user,
                                        theme,
                                        hotspot,
                                      ),
                                );
                              },
                            ),
                      ),
                    )
                    : _requestCentreView == 2
                    ? _buildHistoryConsole(user, theme)
                    : _buildSubmitConsole(user, theme),
          ),
        ],
      ),
      ),
    );
  }

  void _handleHotspotAction(
    UserModel user,
    ThemeData theme,
    OfficeDepartmentHotspot hotspot,
  ) {
    switch (hotspot) {
      case OfficeDepartmentHotspot.companyGate:
        _showGateClockInModal(user, theme);
        break;
      case OfficeDepartmentHotspot.hrOffice:
        _showHROfficeModal(user, theme);
        break;
      case OfficeDepartmentHotspot.itDesk:
        _showITDeskModal(user, theme);
        break;
      case OfficeDepartmentHotspot.financeOffice:
        _showFinanceOfficeModal(user, theme);
        break;
      case OfficeDepartmentHotspot.managerOffice:
        _showManagerOfficeModal(user, theme);
        break;
      case OfficeDepartmentHotspot.archiveDept:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RequestsLogScreen()),
        );
        break;
      case OfficeDepartmentHotspot.chatRoom:
        final dept = user.department.isNotEmpty ? user.department : 'general';
        context.push('/conversations/department/$dept');
        break;
    }
  }

  void _openDirectRequest(int requestTypeIndex) {
    setState(() {
      _requestTypeIndex = requestTypeIndex;
      _requestCentreView = 1;
    });
  }

  void _openOperationalRequest(String category) {
    final actorId = context.read<AuthService>().currentUser?.uid ?? '';
    final enabled = context.read<CompanyOsFeatureFlags>().isEnabledFor(
      feature: CompanyOsFeature.requests,
      actorId: actorId,
    );
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'طلبات الخدمات التقنية والمالية غير مفعّلة لحسابك الآن.',
          ),
        ),
      );
      return;
    }
    setState(() => _requestCentreView = 1);
    context.push('/employee/requests/operational/new?category=$category');
  }

  void _showGateClockInModal(UserModel user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sensor_door,
                  size: 48,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  '🚪 بوابة الشركة الرئيسية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكنك تسجيل الحضور (Check-In) عند وصولك للبوابة الرئيسية.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                WolfButton(
                  text: 'تسجيل الحضور الآن (Clock In)',
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/attendance');
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showHROfficeModal(UserModel user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 42,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '📄 مكتب الموارد البشرية (HR)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLeaveBalanceSummary(user, theme),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(
                          Icons.calendar_month,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        title: const Text(
                          'طلب إجازة (Leave Request)',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openDirectRequest(1);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.access_time,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        title: const Text(
                          'طلب استئذان (Time Permission)',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openDirectRequest(0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.fingerprint,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        title: const Text(
                          'تصحيح بصمة / حضور',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openDirectRequest(7);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.receipt_long,
                          color: Colors.amberAccent,
                        ),
                        title: const Text(
                          'تفاصيل الخصومات وسجل الحضور',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/employee/deductions');
                        },
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showITDeskModal(UserModel user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.computer,
                  size: 42,
                  color: Colors.purpleAccent,
                ),
                const SizedBox(height: 8),
                const Text(
                  '💻 مكتب الدعم التقني والتشغيل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.support_agent,
                    color: Colors.purpleAccent,
                  ),
                  title: const Text(
                    'طلب دعم تقني / اشتراك برامج',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openOperationalRequest('technical');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.devices,
                    color: Colors.purpleAccent,
                  ),
                  title: const Text(
                    'طلب عهدة / أجهزة ومعدات',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openOperationalRequest('assets');
                  },
                ),
                if (kIsWeb)
                  ListTile(
                    leading: const Icon(
                      Icons.folder_shared,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text(
                      'بوابة مستندات الشركة (Google Workspace)',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'متاحة عبر المتصفح ومساحة العمل الرسمية',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/workspace');
                    },
                  ),
              ],
            ),
          ),
    );
  }

  void _showFinanceOfficeModal(UserModel user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 42,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 8),
                const Text(
                  '💰 المكتب المالي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.payments,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    'طلب سلفة مالية (Salary Advance)',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openDirectRequest(2);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.description,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    'تقديم اعتراض / تسوية خصم',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openDirectRequest(3);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showManagerOfficeModal(UserModel user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_center_outlined,
                  size: 42,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 8),
                const Text(
                  '👔 مكتب الإدارة والمهمات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.alt_route,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'طلب مهمة ميدانية (Field Mission)',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openDirectRequest(6);
                  },
                ),
                if ([
                  'manager',
                  'team_leader',
                  'hr',
                  'hr_admin',
                  'hr_manager',
                  'super_admin',
                ].contains(user.role))
                  ListTile(
                    leading: const Icon(
                      Icons.forum_outlined,
                      color: Colors.cyanAccent,
                    ),
                    title: const Text(
                      'قناة المديرين',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'محادثة الإدارة والمنسقين',
                      style: TextStyle(color: Colors.white60),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/conversations/managers');
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.meeting_room_outlined,
                    color: ZaWolfColors.error,
                  ),
                  title: const Text(
                    'تقديم استقالة (Resignation Notice)',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openDirectRequest(4);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSubmitConsole(UserModel user, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'طلب جديد',
            style: theme.textTheme.headlineSmall!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اختر النوع ثم أكمل البيانات المطلوبة',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildRequestTypeSelector(theme),
          const SizedBox(height: 16),
          _buildLeaveBalanceSummary(user, theme),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_requestTypeIndex),
              child: switch (_requestTypeIndex) {
                0 => _buildPermissionForm(user, theme),
                1 => _buildLeaveForm(user, theme),
                2 => _buildAdvanceForm(user, theme),
                3 => _buildComplaintForm(user, theme),
                4 => _buildResignationForm(user, theme),
                5 => _buildAdministrativeRequestForm(user, theme),
                6 => _buildFieldMissionForm(user, theme),
                _ => _buildAttendanceCorrectionForm(user, theme),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTypeSelector(ThemeData theme) {
    final actorId = context.read<AuthService>().currentUser?.uid ?? '';
    final operationalEnabled = context
        .read<CompanyOsFeatureFlags>()
        .isEnabledFor(feature: CompanyOsFeature.requests, actorId: actorId);
    final types = <({String label, IconData icon, Color color, String? route})>[
      (
        label: 'إذن',
        icon: Icons.schedule_outlined,
        color: ZaWolfColors.permissionTeal,
        route: null,
      ),
      (
        label: 'إجازة',
        icon: Icons.event_available_outlined,
        color: ZaWolfColors.dayoffPurple,
        route: null,
      ),
      (
        label: 'سلفة',
        icon: Icons.account_balance_wallet_outlined,
        color: ZaWolfColors.warning,
        route: null,
      ),
      (
        label: 'شكوى',
        icon: Icons.feedback_outlined,
        color: ZaWolfColors.error,
        route: null,
      ),
      (
        label: 'استقالة',
        icon: Icons.meeting_room_outlined,
        color: ZaWolfColors.error,
        route: null,
      ),
      (
        label: 'خدمات الموظف والشؤون الإدارية',
        icon: Icons.assignment_outlined,
        color: ZaWolfColors.primaryBlue,
        route: null,
      ),
      (
        label: 'مهمة ميدانية',
        icon: Icons.explore_outlined,
        color: ZaWolfColors.primaryCyan,
        route: null,
      ),
      (
        label: 'تصحيح حضور',
        icon: Icons.edit_calendar_outlined,
        color: ZaWolfColors.success,
        route: null,
      ),
      (
        label: 'طلب اجتماع',
        icon: Icons.groups_2_outlined,
        color: ZaWolfColors.primaryCyan,
        route: '/employee/meeting-request',
      ),
      if (operationalEnabled)
        (
          label: 'خدمات تقنية وتشغيلية',
          icon: Icons.computer_outlined,
          color: ZaWolfColors.primaryCyan,
          route: '/employee/requests/operational/new?category=technical',
        ),
      if (operationalEnabled)
        (
          label: 'مصروفات ومدفوعات الشركة',
          icon: Icons.payments_outlined,
          color: ZaWolfColors.warning,
          route: '/employee/requests/operational/new?category=financial',
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(types.length, (index) {
            final type = types[index];
            final selected = _requestTypeIndex == index;
            return SizedBox(
              width: itemWidth,
              child: SizedBox(
                height: 76,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (type.route case final route?) {
                        context.push(route);
                        return;
                      }
                      setState(() => _requestTypeIndex = index);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? type.color.withValues(alpha: 0.14)
                                : ZaWolfColors.surface01,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? type.color : ZaWolfColors.surface03,
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            type.icon,
                            color:
                                selected
                                    ? type.color
                                    : ZaWolfColors.textSecondary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color:
                                    selected
                                        ? Colors.white
                                        : ZaWolfColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: type.color,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLeaveBalanceSummary(UserModel user, ThemeData theme) {
    final balance = user.leaveBalance;
    final isOnProbation = LeaveEntitlementPolicy.isOnProbation(user.hiringDate);
    final eligibleFrom = LeaveEntitlementPolicy.eligibleFrom(user.hiringDate);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رصيد الإجازات المتبقي',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _balanceItem(
                'الرصيد الكلي',
                balance.daysOff,
                ZaWolfColors.dayoffPurple,
              ),
              _balanceItem('العارضة', balance.casual, ZaWolfColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'العارضة لها 7 أيام كحد ابتدائي وتُخصم أيضاً من الرصيد الكلي.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (user.hiringDate == null || isOnProbation) ...[
            const SizedBox(height: 10),
            Text(
              user.hiringDate == null
                  ? 'يلزم تسجيل تاريخ التعيين لدى HR قبل احتساب الإجازات السنوية.'
                  : 'فترة التجربة مستمرة حتى ${DateFormat('yyyy/MM/dd').format(eligibleFrom!)}. الإجازة العادية خلال هذه الفترة تُعامل كإجازة بدون راتب.',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: ZaWolfColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceItem(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionForm(UserModel user, ThemeData theme) {
    final cycle = PayrollCycle.forDate(_permissionDate);
    return StreamBuilder<PermissionCycleUsage>(
      stream: _cachedStream<PermissionCycleUsage>(
        'permission-usage:${user.uid}:${cycle.key}',
        () => PermissionService().watchCycleUsage(
          userId: user.uid,
          cycleKey: cycle.key,
        ),
      ),
      // The legacy user counter can be polluted by an approval from an older
      // cycle. Permission documents for this cycle are the source of truth.
      initialData: PermissionCycleUsage.zero,
      builder:
          (context, snapshot) => _buildPermissionFormForCycle(
            user,
            theme,
            cycle,
            snapshot.data ?? PermissionCycleUsage.zero,
          ),
    );
  }

  Widget _buildPermissionFormForCycle(
    UserModel user,
    ThemeData theme,
    PayrollCycle cycle,
    PermissionCycleUsage usage,
  ) {
    final quotaExhausted = PermissionTypePolicy.isRegularQuotaExhausted(
      usedCount: usage.usedCount,
      usedHours: usage.usedHours,
    );
    final deductibleSelected = quotaExhausted || _isDeductiblePermission;

    return Form(
      key: _formKeyPermission,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Info Alert
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZaWolfColors.permissionTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ZaWolfColors.permissionTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: ZaWolfColors.permissionTeal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دورة الأذونات: ${cycle.arabicRangeLabel}',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'عدد الأذونات المستخدمة:',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: ZaWolfColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${usage.usedCount} / 2 أذونات',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: ZaWolfColors.permissionTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إجمالي الساعات المستخدمة:',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: ZaWolfColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${usage.usedHours.toStringAsFixed(1)} / 5 ساعات',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chips selection for type
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Center(child: Text('مغادرة مبكرة')),
                  selected: _permissionType == 'early_leave',
                  onSelected: (val) {
                    if (val) setState(() => _permissionType = 'early_leave');
                  },
                  selectedColor: ZaWolfColors.permissionTeal,
                  checkmarkColor: Colors.white,
                ),
                ChoiceChip(
                  label: const Center(child: Text('مغادرة والعودة')),
                  selected:
                      _permissionType == PermissionTypePolicy.midShiftExit,
                  onSelected: (val) {
                    if (val) {
                      setState(
                        () =>
                            _permissionType = PermissionTypePolicy.midShiftExit,
                      );
                    }
                  },
                  selectedColor: ZaWolfColors.permissionTeal,
                  checkmarkColor: Colors.white,
                ),
                ChoiceChip(
                  label: const Center(child: Text('تأخير حضور')),
                  selected: _permissionType == 'late_arrival',
                  onSelected: (val) {
                    if (val) setState(() => _permissionType = 'late_arrival');
                  },
                  selectedColor: ZaWolfColors.permissionTeal,
                  checkmarkColor: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (quotaExhausted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZaWolfColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ZaWolfColors.warning.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChoiceChip(
                      label: const Text('إذن استقطاعي'),
                      selected: deductibleSelected,
                      onSelected:
                          (_) => setState(() => _isDeductiblePermission = true),
                      selectedColor: ZaWolfColors.warning,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _permissionDurationHours <= 2
                          ? 'خصم ربع يوم من الراتب بعد موافقة HR.'
                          : 'خصم نصف يوم من الراتب بعد موافقة HR.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Late arrival policy if selected
            if (_permissionType == 'late_arrival') ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZaWolfColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: ZaWolfColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يجب تقديم إذن التأخير قبل بداية الدوام الرسمية وقبل تسجيل الحضور الفعلي.',
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: ZaWolfColors.warning,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تاريخ الإذن:', style: theme.textTheme.bodyMedium),
                TextButton.icon(
                  onPressed: () => _selectPermissionDate(context),
                  icon: const Icon(
                    Icons.calendar_month,
                    color: ZaWolfColors.permissionTeal,
                  ),
                  label: Text(
                    DateFormat('yyyy/MM/dd').format(_permissionDate),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ZaWolfColors.permissionTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: ZaWolfColors.surface02),

            // Permission time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _permissionType == PermissionTypePolicy.lateArrival
                      ? 'وقت الحضور المتوقع:'
                      : 'وقت المغادرة المتوقع:',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_permissionType == PermissionTypePolicy.midShiftExit)
                  TextButton.icon(
                    icon: const Icon(
                      Icons.alarm,
                      color: ZaWolfColors.permissionTeal,
                    ),
                    label: Text(
                      _selectedTime.format(context),
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: ZaWolfColors.permissionTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _selectTime(context),
                  )
                else
                  Text(
                    _resolvedPermissionTime(user).format(context),
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: ZaWolfColors.permissionTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (_permissionType != PermissionTypePolicy.midShiftExit)
              Text(
                'يتم حساب الوقت تلقائياً من جدول عملك والمدة المختارة.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
                textDirection: TextDirection.rtl,
              ),
            const Divider(color: ZaWolfColors.surface02),
            if (_permissionType == PermissionTypePolicy.midShiftExit) ...[
              Builder(
                builder: (context) {
                  final departureMinutes =
                      _selectedTime.hour * 60 + _selectedTime.minute;
                  final returnMinutes =
                      departureMinutes + (_permissionDurationHours * 60);
                  final returnTime = TimeOfDay(
                    hour: (returnMinutes ~/ 60) % 24,
                    minute: returnMinutes % 60,
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'وقت العودة المتوقع:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        returnTime.format(context),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ZaWolfColors.permissionTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(color: ZaWolfColors.surface02),
            ],

            // Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المدة الزمنية المطلوبة:'),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.permissionTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_permissionDurationHours ساعة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                PermissionTypePolicy.maximumDurationHours,
                (index) {
                  final hours = index + 1;
                  return ChoiceChip(
                    label: Text('$hours ساعة'),
                    selected: _permissionDurationHours == hours,
                    selectedColor: ZaWolfColors.permissionTeal,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _permissionDurationHours = hours);
                      }
                    },
                  );
                },
              ),
            ),

            // Reason field
            WolfInputField(
              controller: _permissionReasonController,
              labelText: 'سبب الإذن',
              englishLabel: 'Reason',
              hintText: 'اكتب سبب طلب الإذن بالتفصيل...',
              maxLines: 2,
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'يرجى كتابة السبب'
                          : null,
            ),
            const SizedBox(height: 20),

            if (quotaExhausted) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ZaWolfColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تم استهلاك رصيد الأذونات العادية. هذا الطلب استقطاعي ويتطلب موافقة HR، وبحد أقصى نصف يوم.',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: ZaWolfColors.error,
                    fontSize: 10,
                  ),
                ),
              ),
            ],

            WolfButton(
              onPressed: () => _submitPermission(user, usage),
              text: 'تقديم طلب الإذن',
              secondaryText: 'SUBMIT PERMISSION',
              variant: WolfButtonVariant.teal,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveForm(UserModel user, ThemeData theme) {
    final requestedDays = _leaveEnd.difference(_leaveStart).inDays + 1;
    final isOnProbation = LeaveEntitlementPolicy.isOnProbation(
      user.hiringDate,
      onDate: _leaveStart,
    );
    final selectedLeaveType =
        isOnProbation ? LeaveTypePolicy.unpaid : _leaveType;

    return Form(
      key: _formKeyLeave,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leave type selection row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isOnProbation) ...[
                  ChoiceChip(
                    label: const Center(child: Text('مرضية')),
                    selected: selectedLeaveType == 'sick',
                    onSelected: (val) {
                      if (val) _setLeaveType(LeaveTypePolicy.sick);
                    },
                  ),
                  ChoiceChip(
                    label: const Center(child: Text('عارضة')),
                    selected: selectedLeaveType == 'casual',
                    onSelected: (val) {
                      if (val) _setLeaveType(LeaveTypePolicy.casual);
                    },
                  ),
                  ChoiceChip(
                    label: const Center(child: Text('إجازة مولود')),
                    selected: selectedLeaveType == LeaveTypePolicy.paternity,
                    onSelected: (val) {
                      if (val) _setLeaveType(LeaveTypePolicy.paternity);
                    },
                  ),
                  ChoiceChip(
                    label: const Center(child: Text('إجازة عادية')),
                    selected: selectedLeaveType == 'day_off',
                    onSelected: (val) {
                      if (val) _setLeaveType(LeaveTypePolicy.normal);
                    },
                  ),
                ],
                ChoiceChip(
                  label: const Center(child: Text('بدون راتب')),
                  selected: selectedLeaveType == LeaveTypePolicy.unpaid,
                  onSelected: (val) {
                    if (val && !isOnProbation) {
                      _setLeaveType(LeaveTypePolicy.unpaid);
                    }
                  },
                ),
                if (!isOnProbation) ...[
                  ChoiceChip(
                    label: const Center(child: Text('امتحان')),
                    selected: selectedLeaveType == LeaveTypePolicy.exam,
                    onSelected: (val) {
                      if (val) {
                        _setLeaveType(LeaveTypePolicy.exam);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Center(child: Text('عمل عن بعد')),
                    selected: selectedLeaveType == LeaveTypePolicy.remote,
                    onSelected: (val) {
                      if (val) {
                        _setLeaveType(LeaveTypePolicy.remote);
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (selectedLeaveType == LeaveTypePolicy.sick &&
                user.leaveBalance.daysOff >= requestedDays)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _convertSickToAnnual,
                onChanged:
                    (value) =>
                        setState(() => _convertSickToAnnual = value ?? false),
                title: const Text(
                  'تحويل الإجازة المرضية إلى إجازة سنوية مخصومة من الرصيد',
                ),
                subtitle: const Text('سيُخصم الرصيد فقط بعد اعتماد الطلب.'),
              ),
            Text(
              isOnProbation
                  ? 'خلال أول 6 أشهر تكون الإجازة بدون راتب. تظل أذونات الوقت متاحة بصورة طبيعية.'
                  : LeaveTypePolicy.description(selectedLeaveType),
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'يمكنك إرسال أكثر من طلب إجازة لأيام مختلفة، ما دامت التواريخ غير متداخلة والرصيد كافياً.',
                style: theme.textTheme.bodySmall,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 12),

            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _leaveMultipleDays,
              title: const Text('إجازة متعددة الأيام'),
              subtitle: const Text(
                'فعّل هذا الخيار فقط إذا كانت الإجازة تمتد لأكثر من يوم واحد.',
              ),
              onChanged: (enabled) {
                setState(() {
                  _leaveMultipleDays = enabled;
                  if (!enabled) _leaveEnd = _leaveStart;
                });
                _refreshLeaveWorkingDays(user);
              },
            ),
            const SizedBox(height: 4),
            // A single day is intentional by default; selecting a range is
            // an explicit extra action so mobile users do not add a day by
            // accident.
            LayoutBuilder(
              builder: (context, constraints) {
                final dateDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _leaveMultipleDays
                          ? 'الفترة المحددة: $requestedDays أيام تقويمية'
                          : 'اليوم المحدد: يوم واحد',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _leaveMultipleDays
                          ? 'من ${DateFormat('yyyy-MM-dd').format(_leaveStart)} إلى ${DateFormat('yyyy-MM-dd').format(_leaveEnd)}'
                          : DateFormat(
                            'EEEE yyyy-MM-dd',
                            'ar',
                          ).format(_leaveStart),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
                final dateButton = TextButton.icon(
                  icon: const Icon(
                    Icons.date_range,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  label: Text(
                    _leaveMultipleDays ? 'اختيار الفترة' : 'اختيار اليوم',
                    style: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  onPressed:
                      () => _selectLeaveDateRange(
                        context,
                        selectedLeaveType,
                        user,
                      ),
                );

                if (constraints.maxWidth < 430) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateDetails,
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: dateButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: dateDetails),
                    const SizedBox(width: 8),
                    dateButton,
                  ],
                );
              },
            ),
            if (_leaveWorkingDays != null) ...[
              const SizedBox(height: 8),
              Text(
                'أيام العمل التي ستُحتسب: $_leaveWorkingDays (لا تشمل الجمعة أو عطلات الشركة).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZaWolfColors.primaryCyan,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
            const Divider(color: ZaWolfColors.surface02),

            // Reason
            WolfInputField(
              controller: _leaveReasonController,
              labelText: 'سبب الإجازة',
              englishLabel: 'Reason',
              hintText: 'اكتب تفاصيل الإجازة والسبب...',
              maxLines: 2,
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'يرجى كتابة السبب'
                          : null,
            ),
            const SizedBox(height: 12),

            WolfInputField(
              controller: _workHandoverController,
              labelText: 'من سيقوم بمهامك أثناء الإجازة؟',
              englishLabel: 'Work Handover',
              hintText: 'اكتب اسم الموظف البديل أو الفريق المسؤول',
              maxLines: 2,
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'يرجى تحديد من سيقوم بالعمل أثناء الإجازة'
                          : null,
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                _attachmentUrl == null
                    ? (selectedLeaveType == LeaveTypePolicy.exam
                        ? 'إرفاق جدول الامتحان أو إثبات الدخول (مطلوب)'
                        : 'إرفاق مستند للإجازة (اختياري)')
                    : 'تم إرفاق مستند في ملفات الشركة',
              ),
              onPressed:
                  _loading
                      ? null
                      : () => _pickAndStoreAttachment(
                        controller: _leaveAttachmentController,
                        onStored: (uri) => setState(() => _attachmentUrl = uri),
                      ),
            ),
            const SizedBox(height: 16),

            WolfButton(
              onPressed: () => _submitLeave(user),
              text: 'تقديم طلب إجازة',
              secondaryText: 'SUBMIT LEAVE REQUEST',
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanceForm(UserModel user, ThemeData theme) {
    final now = DateTime.now();
    final maximum = user.baseMonthlySalary * .5;
    final tenureEligible =
        user.hiringDate != null &&
        now.difference(user.hiringDate!).inDays >= 90;
    final dateEligible = now.day >= 15;
    return Form(
      key: _formKeyAdvance,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZaWolfColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ZaWolfColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'سيتم خصم مبلغ السلفة من راتب الشهر الحالي بعد موافقة الإدارة.',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: ZaWolfColors.warning,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'الحد الأقصى: ${maximum.toStringAsFixed(0)} ${user.salaryCurrency} · ${tenureEligible ? 'مدة الخدمة مكتملة' : 'لم تكتمل 3 أشهر خدمة'} · ${dateEligible ? 'متاح هذا الشهر' : 'متاح بدءاً من يوم 15'}',
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    tenureEligible && dateEligible
                        ? ZaWolfColors.success
                        : ZaWolfColors.warning,
              ),
            ),
            const SizedBox(height: 10),
            WolfInputField(
              controller: _advanceAmountController,
              labelText: 'المبلغ المطلوب (${user.salaryCurrency})',
              englishLabel: 'Amount',
              hintText: 'مثال: 500',
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'المبلغ مطلوب';
                final amt = double.tryParse(val);
                if (amt == null || amt <= 0) return 'مبلغ غير صحيح';
                if (amt > maximum) {
                  return 'الحد الأقصى المتاح ${maximum.toStringAsFixed(0)} ${user.salaryCurrency}.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            WolfInputField(
              controller: _advanceReasonController,
              labelText: 'سبب طلب السلفة (اختياري)',
              englishLabel: 'Reason',
              hintText: 'تفاصيل إضافية...',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            WolfButton(
              onPressed: () => _submitAdvance(user),
              text: 'تقديم طلب سلفة',
              secondaryText: 'SUBMIT ADVANCE REQUEST',
              variant: WolfButtonVariant.primary,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintForm(UserModel user, ThemeData theme) {
    return Form(
      key: _formKeyComplaint,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZaWolfColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ZaWolfColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'سيتم إرسال الشكوى إلى HR والإدارة العليا للمراجعة.',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: ZaWolfColors.warning,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color:
                    _submitComplaintAnonymously
                        ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                        : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _submitComplaintAnonymously
                          ? ZaWolfColors.primaryCyan.withValues(alpha: 0.55)
                          : ZaWolfColors.surface02,
                ),
              ),
              child: SwitchListTile.adaptive(
                value: _submitComplaintAnonymously,
                activeTrackColor: ZaWolfColors.primaryCyan,
                onChanged:
                    _loading
                        ? null
                        : (value) {
                          setState(() => _submitComplaintAnonymously = value);
                        },
                secondary: Icon(
                  _submitComplaintAnonymously
                      ? Icons.visibility_off_outlined
                      : Icons.badge_outlined,
                  color:
                      _submitComplaintAnonymously
                          ? ZaWolfColors.primaryCyan
                          : ZaWolfColors.textSecondary,
                ),
                title: const Text(
                  'إرسال الشكوى كمجهول',
                  textDirection: TextDirection.rtl,
                ),
                subtitle: const Text(
                  'لن يظهر اسمك أو كودك أو قسمك للمراجعين داخل التطبيق.',
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(height: 16),
            WolfInputField(
              controller: _complaintTitleController,
              labelText: 'عنوان الشكوى',
              englishLabel: 'Complaint Title',
              hintText: 'اكتب عنواناً واضحاً للشكوى...',
              validator:
                  (val) =>
                      val == null || val.trim().length < 3
                          ? 'العنوان مطلوب'
                          : null,
            ),
            const SizedBox(height: 16),
            WolfInputField(
              controller: _complaintBodyController,
              labelText: 'تفاصيل الشكوى',
              englishLabel: 'Details',
              hintText: 'اكتب تفاصيل الشكوى بوضوح...',
              maxLines: 4,
              validator:
                  (val) =>
                      val == null || val.trim().length < 10
                          ? 'يرجى كتابة تفاصيل كافية'
                          : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                _complaintAttachmentUrl == null
                    ? 'إرفاق ملف للشكوى (اختياري)'
                    : 'تم إرفاق ملف في ملفات الشركة',
              ),
              onPressed:
                  _loading
                      ? null
                      : () => _pickAndStoreAttachment(
                        controller: _complaintAttachmentController,
                        onStored:
                            (uri) =>
                                setState(() => _complaintAttachmentUrl = uri),
                      ),
            ),
            const SizedBox(height: 20),
            WolfButton(
              onPressed: () => _submitComplaint(user),
              text: 'إرسال الشكوى',
              secondaryText: 'SUBMIT COMPLAINT',
              variant: WolfButtonVariant.danger,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCorrectionForm(UserModel user, ThemeData theme) {
    final service = AttendanceCorrectionRequestService();
    return Form(
      key: _formKeyAttendanceCorrection,
      child: StreamBuilder<List<AttendanceModel>>(
        stream: _cachedStream(
          'correction-eligible|${user.uid}',
          () => service.correctionEligibleAttendance(user.uid),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final records = snapshot.data ?? const <AttendanceModel>[];
          if (records.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'لا توجد أيام تأخير أو خصم متاحة لطلب تصحيح وقتها.',
                textAlign: TextAlign.center,
              ),
            );
          }
          final selected =
              records.any(
                    (item) =>
                        item.attendanceId ==
                        _selectedCorrectionAttendance?.attendanceId,
                  )
                  ? _selectedCorrectionAttendance
                  : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'طلب تصحيح وقت الحضور',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اختر يوماً تأخرت فيه أو نتج عنه خصم. يراجع HR الطلب قبل تعديل السجل وإعادة حساب الخصم.',
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<AttendanceModel>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'يوم الحضور',
                  prefixIcon: Icon(Icons.event_note_outlined),
                ),
                items:
                    records
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item.date} · ${item.checkInTime == null ? '--:--' : DateFormat('hh:mm a', 'ar').format(item.checkInTime!)}',
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCorrectionAttendance = value;
                    _requestedCorrectionTime =
                        value?.checkInTime == null
                            ? null
                            : TimeOfDay.fromDateTime(value!.checkInTime!);
                  });
                },
                validator:
                    (value) => value == null ? 'اختر سجل الحضور المطلوب' : null,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed:
                    selected == null
                        ? null
                        : () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _requestedCorrectionTime ??
                                TimeOfDay.fromDateTime(selected.checkInTime!),
                          );
                          if (picked != null && mounted) {
                            setState(() => _requestedCorrectionTime = picked);
                          }
                        },
                icon: const Icon(Icons.access_time),
                label: Text(
                  _requestedCorrectionTime == null
                      ? 'اختر وقت الوصول الصحيح'
                      : 'الوقت الصحيح: ${_requestedCorrectionTime!.format(context)}',
                ),
              ),
              const SizedBox(height: 14),
              WolfInputField(
                controller: _attendanceCorrectionReasonController,
                labelText: 'سبب التصحيح',
                englishLabel: 'Reason',
                hintText: 'مثال: وصلت مبكراً وتعذر تسجيل الحضور',
                maxLines: 3,
                validator:
                    (value) =>
                        (value?.trim().length ?? 0) < 5
                            ? 'اكتب سبباً واضحاً'
                            : null,
              ),
              const SizedBox(height: 20),
              WolfButton(
                onPressed: () => _submitAttendanceCorrection(user),
                text: 'إرسال إلى HR',
                secondaryText: 'SUBMIT CORRECTION',
                loading: _loading,
              ),
            ],
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHistoryConsole(UserModel user, ThemeData theme) {
    return DefaultTabController(
      key: ValueKey('history-${widget.initialHistoryTab}'),
      length: 8,
      initialIndex: widget.initialHistoryTab.clamp(0, 7),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilterBar(
              selectedId: _historyStatusFilter,
              onSelected: (id) => setState(() => _historyStatusFilter = id),
              chips: const [
                FilterChipItem(id: 'all', label: 'الكل'),
                FilterChipItem(id: 'pending', label: 'قيد المراجعة'),
                FilterChipItem(id: 'approved', label: 'مقبول'),
                FilterChipItem(id: 'rejected', label: 'مرفوض'),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'الإجازات'),
              Tab(text: 'الأذونات'),
              Tab(text: 'السلف'),
              Tab(text: 'الشكاوى'),
              Tab(text: 'الاستقالة'),
              Tab(text: 'إدارية'),
              Tab(text: 'تصحيح الحضور'),
              Tab(text: 'الاجتماعات'),
            ],
            labelColor: ZaWolfColors.primaryCyan,
            unselectedLabelColor: ZaWolfColors.textSecondary,
            indicatorColor: ZaWolfColors.primaryCyan,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLeavesHistory(user.uid, theme),
                _buildPermissionsHistory(user.uid, theme),
                _buildAdvancesHistory(user.uid, theme),
                _buildComplaintsHistory(user.uid, theme),
                _buildResignationsHistory(user.uid, theme),
                _buildAdministrativeHistory(user.uid, theme),
                _buildAttendanceCorrectionHistory(user.uid, theme),
                MeetingRequestsListScreen(
                  repository: MeetingRepositoryImpl(),
                  approvalQueue: false,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentIndicator(String value, ThemeData theme) {
    final governedDriveAttachment = value.startsWith('drive-request://');
    return Row(
      children: [
        Icon(
          governedDriveAttachment ? Icons.cloud_done_outlined : Icons.link,
          color: ZaWolfColors.primaryCyan,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            governedDriveAttachment
                ? 'مرفق محفوظ بأمان في ملفات الشركة'
                : value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ZaWolfColors.primaryCyan,
              decoration:
                  governedDriveAttachment ? null : TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection:
                governedDriveAttachment ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCorrectionHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream(
        'correction-history|$userId',
        () => AttendanceCorrectionRequestService().requestsForEmployee(userId),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs = [...?snapshot.data?.docs];
        docs.sort((a, b) {
          final aHighlight = _isHighlightedRequest(a.id);
          final bHighlight = _isHighlightedRequest(b.id);
          if (aHighlight && !bHighlight) return -1;
          if (!aHighlight && bHighlight) return 1;
          final left = a.data()['submittedAt'] as Timestamp?;
          final right = b.data()['submittedAt'] as Timestamp?;
          return (right?.millisecondsSinceEpoch ?? 0).compareTo(
            left?.millisecondsSinceEpoch ?? 0,
          );
        });
        docs.removeWhere(
          (doc) =>
              !_isHighlightedRequest(doc.id) &&
              !_matchesHistoryFilter(
                doc.data()['status'] as String? ?? 'pending_hr',
              ),
        );
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات تصحيح وقت.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isTarget = _isHighlightedRequest(docs[index].id);
            final status = data['status'] as String? ?? 'pending_hr';
            final statusText = switch (status) {
              'approved' => 'مقبول',
              'rejected' => 'مرفوض',
              'cancelled' => 'ملغي',
              _ => 'بانتظار HR',
            };
            final statusColor = switch (status) {
              'approved' => ZaWolfColors.success,
              'rejected' => ZaWolfColors.error,
              'cancelled' => ZaWolfColors.textSecondary,
              _ => ZaWolfColors.warning,
            };
            final original = data['originalCheckInTime'] as Timestamp?;
            final requested = data['requestedCheckInTime'] as Timestamp?;
            return Card(
              color: isTarget ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface03,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_calendar_outlined,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'تصحيح حضور ${data['attendanceDate'] ?? ''}',
                                style: theme.textTheme.titleMedium,
                              ),
                              if (isTarget) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: ZaWolfColors.primaryCyan),
                                  ),
                                  child: const Text(
                                    'الطلب المحدد',
                                    style: TextStyle(
                                      color: ZaWolfColors.primaryCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المسجل: ${original == null ? '--:--' : DateFormat('hh:mm a', 'ar').format(original.toDate())}'
                      '  ←  المطلوب: ${requested == null ? '--:--' : DateFormat('hh:mm a', 'ar').format(requested.toDate())}',
                    ),
                    Text('السبب: ${data['reason'] ?? ''}'),
                    if ((data['reviewerComment'] as String? ?? '').isNotEmpty)
                      Text('رد HR: ${data['reviewerComment']}'),
                    if (status == 'pending_hr') ...[
                      const SizedBox(height: 12),
                      WolfButton(
                        onPressed:
                            () => _confirmCancel(
                              'attendanceCorrectionRequests',
                              docs[index].id,
                            ),
                        text: 'حذف الطلب',
                        secondaryText: 'CANCEL REQUEST',
                        variant: WolfButtonVariant.outline,
                        height: 40,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdministrativeRequestForm(UserModel user, ThemeData theme) {
    return Form(
      key: _formKeyAdministrative,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _administrativeCategory,
            decoration: const InputDecoration(labelText: 'نوع الطلب الإداري'),
            dropdownColor: ZaWolfColors.surface01,
            items:
                AdministrativeRequestCategory.values
                    .where(
                      (value) =>
                          value != AdministrativeRequestCategory.fieldMission,
                    )
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          AdministrativeRequestCategory.arabicLabel(value),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _administrativeCategory = value);
              }
            },
          ),
          const SizedBox(height: 14),
          if (_administrativeCategory ==
              AdministrativeRequestCategory.fieldMission) ...[
            TextFormField(
              controller: _fieldMissionSiteController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'مكان المهمة الميدانية',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? 'مكان المهمة مطلوب'
                          : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('تاريخ المهمة'),
              subtitle: Text(
                DateFormat('yyyy/MM/dd').format(_fieldMissionDate),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fieldMissionDate,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _fieldMissionDate = picked);
                }
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'البداية: ${_fieldMissionStart.format(context)}',
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _fieldMissionStart,
                      );
                      if (picked != null && mounted) {
                        setState(() => _fieldMissionStart = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.timer_off_outlined),
                    label: Text('النهاية: ${_fieldMissionEnd.format(context)}'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _fieldMissionEnd,
                      );
                      if (picked != null && mounted) {
                        setState(() => _fieldMissionEnd = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _fieldMissionRequiresReturn,
              title: const Text('العودة إلى المكتب بعد المهمة'),
              onChanged:
                  (value) =>
                      setState(() => _fieldMissionRequiresReturn = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _fieldMissionRequiresCheckout,
              title: const Text('يتطلب تسجيل الانصراف'),
              onChanged:
                  (value) =>
                      setState(() => _fieldMissionRequiresCheckout = value),
            ),
          ],
          TextFormField(
            controller: _administrativeNotesController,
            minLines: 4,
            maxLines: 7,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الطلب',
              hintText: 'اكتب المطلوب والسبب والتفاصيل...',
            ),
            validator:
                (value) =>
                    (value?.trim().isEmpty ?? true)
                        ? 'تفاصيل الطلب مطلوبة'
                        : null,
          ),
          if (_administrativeCategory !=
              AdministrativeRequestCategory.fieldMission) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                _administrativeAttachmentUrl == null
                    ? 'إرفاق ملف داعم (اختياري)'
                    : 'تم إرفاق ملف في ملفات الشركة',
              ),
              onPressed:
                  _loading
                      ? null
                      : () => _pickAndStoreAttachment(
                        controller: _administrativeAttachmentController,
                        onStored:
                            (uri) => setState(
                              () => _administrativeAttachmentUrl = uri,
                            ),
                      ),
            ),
          ],
          const SizedBox(height: 20),
          WolfButton(
            onPressed: () => _submitAdministrativeRequest(user),
            text:
                _administrativeCategory ==
                        AdministrativeRequestCategory.fieldMission
                    ? 'إرسال طلب المهمة الميدانية'
                    : 'إرسال الطلب الإداري',
            secondaryText:
                _administrativeCategory ==
                        AdministrativeRequestCategory.fieldMission
                    ? 'SUBMIT FIELD MISSION'
                    : 'SUBMIT ADMIN REQUEST',
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldMissionForm(UserModel user, ThemeData theme) {
    return Form(
      key: _formKeyFieldMission,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.explore_outlined,
                  color: ZaWolfColors.primaryCyan,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب مهمة ميدانية',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مأمورية عمل خارج مقر الشركة لمتابعة المهام والمشاريع',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _fieldMissionSiteController,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              labelText: 'مكان المهمة الميدانية',
              hintText: 'مثال: موقع العميل، فرع الشركة، جهة حكومية...',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator:
                (value) =>
                    (value?.trim().isEmpty ?? true)
                        ? 'مكان المهمة مطلوب'
                        : null,
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('تاريخ المهمة'),
            subtitle: Text(DateFormat('yyyy/MM/dd').format(_fieldMissionDate)),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _fieldMissionDate,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null && mounted) {
                setState(() => _fieldMissionDate = picked);
              }
            },
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('البداية: ${_fieldMissionStart.format(context)}'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _fieldMissionStart,
                    );
                    if (picked != null && mounted) {
                      setState(() => _fieldMissionStart = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.timer_off_outlined),
                  label: Text('النهاية: ${_fieldMissionEnd.format(context)}'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _fieldMissionEnd,
                    );
                    if (picked != null && mounted) {
                      setState(() => _fieldMissionEnd = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _fieldMissionRequiresReturn,
            title: const Text('العودة إلى المكتب بعد المهمة'),
            onChanged:
                (value) => setState(() => _fieldMissionRequiresReturn = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _fieldMissionRequiresCheckout,
            title: const Text('يتطلب تسجيل الانصراف'),
            onChanged:
                (value) =>
                    setState(() => _fieldMissionRequiresCheckout = value),
          ),
          TextFormField(
            controller: _fieldMissionReasonController,
            minLines: 3,
            maxLines: 5,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              labelText: 'تفاصيل وسبب المهمة الميدانية',
              hintText: 'اكتب الغرض من المأمورية والمهام المطلوب إنجازها...',
            ),
            validator:
                (value) =>
                    (value?.trim().isEmpty ?? true)
                        ? 'تفاصيل وسبب المهمة مطلوبة'
                        : null,
          ),
          const SizedBox(height: 20),
          WolfButton(
            onPressed: () => _submitFieldMissionDirect(user),
            text: 'إرسال طلب المهمة الميدانية',
            secondaryText: 'SUBMIT FIELD MISSION',
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildAdministrativeHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream(
        'administrative-history|$userId',
        () => AdministrativeRequestService().watchMine(userId),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs = snapshot.data?.docs ?? const [];
        final filteredDocs =
            docs
                .where(
                  (doc) =>
                      _isHighlightedRequest(doc.id, AdministrativeRequestModel.fromFirestore(doc).id) ||
                      _matchesHistoryFilter(
                        doc.data()['status'] as String? ?? '',
                      ),
                )
                .toList();
        if (widget.initialRequestId != null) {
          filteredDocs.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.id, AdministrativeRequestModel.fromFirestore(a).id);
            final bHighlight = _isHighlightedRequest(b.id, AdministrativeRequestModel.fromFirestore(b).id);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (filteredDocs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إدارية سابقة.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final request = AdministrativeRequestModel.fromFirestore(doc);
            final isTarget = _isHighlightedRequest(doc.id, request.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface03,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        color: ZaWolfColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              request.categoryLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTarget) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: ZaWolfColors.primaryCyan),
                                ),
                                child: const Text(
                                  'الطلب المحدد',
                                  style: TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(request.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تاريخ الإرسال: ${DateFormat('yyyy/MM/dd · HH:mm').format(request.submittedAt)}',
                  ),
                  Text(request.notes),
                  if (request.category ==
                      AdministrativeRequestCategory.fieldMission) ...[
                    const SizedBox(height: 6),
                    Text(
                      'المكان: ${request.siteName ?? '-'} · ${request.missionDate ?? '-'}',
                    ),
                    Text(
                      '${request.startTime ?? '-'} - ${request.endTime ?? '-'}',
                    ),
                  ],
                  if ((request.attachmentUrl ?? '').isNotEmpty)
                    _buildAttachmentIndicator(request.attachmentUrl!, theme),
                  RequestApprovalTimeline(data: doc.data(), compact: true),
                  if (request.category == 'company_os') ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          () => context.push(
                            '/employee/requests/operational/${request.id}',
                          ),
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('عرض مسار الطلب'),
                    ),
                  ],
                  if (request.status.startsWith('pending_')) ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed:
                          () => _confirmCancel(
                            'administrativeRequests',
                            request.id,
                          ),
                      text: 'حذف الطلب',
                      secondaryText: 'CANCEL REQUEST',
                      variant: WolfButtonVariant.outline,
                      height: 40,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResignationForm(UserModel user, ThemeData theme) {
    return Form(
      key: _formKeyResignation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZaWolfColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ZaWolfColors.error.withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              'يُرسل الطلب إلى قائد الفريق ثم المديرين بالترتيب، وبعدهم HR للقرار النهائي.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تاريخ الاستقالة'),
            subtitle: Text(DateFormat('yyyy/MM/dd').format(_resignationDate)),
            trailing: const Icon(
              Icons.calendar_month,
              color: ZaWolfColors.primaryCyan,
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _resignationDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null && mounted) {
                setState(() => _resignationDate = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _resignationReasonController,
            minLines: 4,
            maxLines: 7,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              labelText: 'سبب الاستقالة',
              hintText: 'اكتب سبب الاستقالة بوضوح...',
            ),
            validator:
                (value) =>
                    (value?.trim().isEmpty ?? true)
                        ? 'سبب الاستقالة مطلوب'
                        : null,
          ),
          const SizedBox(height: 20),
          WolfButton(
            onPressed: () => _submitResignation(user),
            text: 'إرسال طلب الاستقالة',
            secondaryText: 'SUBMIT RESIGNATION',
            variant: WolfButtonVariant.danger,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildResignationsHistory(String userId, ThemeData theme) {
    return StreamBuilder<List<ResignationModel>>(
      stream: _cachedStream(
        'resignation-history|$userId',
        () => ResignationService().watchMine(userId),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final requests =
            (snapshot.data ?? const <ResignationModel>[])
                .where((request) =>
                    _isHighlightedRequest(request.resignationId) ||
                    _matchesHistoryFilter(request.status))
                .toList();
        if (widget.initialRequestId != null) {
          requests.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.resignationId);
            final bHighlight = _isHighlightedRequest(b.resignationId);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (requests.isEmpty) {
          return _buildEmptyState('لا توجد طلبات استقالة سابقة.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final isTarget = _isHighlightedRequest(request.resignationId);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface03,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        color: ZaWolfColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              'طلب استقالة',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTarget) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: ZaWolfColors.primaryCyan),
                                ),
                                child: const Text(
                                  'الطلب المحدد',
                                  style: TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(request.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'التاريخ: ${DateFormat('yyyy/MM/dd').format(request.resignationDate)}',
                  ),
                  const SizedBox(height: 6),
                  Text('السبب: ${request.reason}'),
                  if ((request.reviewerComment ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'رد الإدارة: ${request.reviewerComment}',
                      style: const TextStyle(color: ZaWolfColors.warning),
                    ),
                  ],
                  if (request.status.startsWith('pending_')) ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed:
                          () => _confirmCancel(
                            'resignations',
                            request.resignationId,
                          ),
                      text: 'حذف الطلب',
                      secondaryText: 'CANCEL REQUEST',
                      variant: WolfButtonVariant.outline,
                      height: 40,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdvancesHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'advance-history|$userId',
        () =>
            FirebaseFirestore.instance
                .collection('advances')
                .where('userId', isEqualTo: userId)
                .orderBy('submittedAt', descending: true)
                .limit(25)
                .snapshots(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs =
            (snapshot.data?.docs ?? [])
                .where(
                  (doc) =>
                      _isHighlightedRequest(doc.id, AdvanceModel.fromFirestore(doc).advanceId) ||
                      _matchesHistoryFilter(
                        AdvanceModel.fromFirestore(doc).status,
                      ),
                )
                .toList();
        if (widget.initialRequestId != null) {
          docs.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.id, AdvanceModel.fromFirestore(a).advanceId);
            final bHighlight = _isHighlightedRequest(b.id, AdvanceModel.fromFirestore(b).advanceId);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات سلفة سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = AdvanceModel.fromFirestore(doc);
            final isTarget = _isHighlightedRequest(doc.id, req.advanceId);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments,
                            color: ZaWolfColors.primaryCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'سلفة: ${req.amount} جنيه',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isTarget) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ZaWolfColors.primaryCyan),
                              ),
                              child: const Text(
                                'الطلب المحدد',
                                style: TextStyle(
                                  color: ZaWolfColors.primaryCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      _buildStatusBadge(req.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (req.reason != null && req.reason!.isNotEmpty) ...[
                    Text(
                      'السبب: ${req.reason}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (req.reviewerComment != null &&
                      req.reviewerComment!.isNotEmpty) ...[
                    Text(
                      'تعليق الإدارة: ${req.reviewerComment}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  RequestApprovalTimeline(
                    data: Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>,
                    ),
                    compact: true,
                  ),
                  if (req.status.startsWith('pending')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: WolfButton(
                            onPressed:
                                () => _confirmCancel('advances', req.advanceId),
                            text: 'حذف الطلب',
                            variant: WolfButtonVariant.outline,
                            height: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: WolfButton(
                            onPressed: () => _editAdvanceRequest(req),
                            text: 'تعديل',
                            variant: WolfButtonVariant.teal,
                            height: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComplaintsHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'complaint-history|$userId',
        () =>
            FirebaseFirestore.instance
                .collection('complaints')
                .where('userId', isEqualTo: userId)
                .orderBy('submittedAt', descending: true)
                .limit(25)
                .snapshots(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs =
            (snapshot.data?.docs ?? [])
                .where(
                  (doc) =>
                      _isHighlightedRequest(doc.id, ComplaintModel.fromFirestore(doc).complaintId) ||
                      _matchesHistoryFilter(
                        ComplaintModel.fromFirestore(doc).status == 'new'
                            ? 'pending'
                            : ComplaintModel.fromFirestore(doc).status,
                      ),
                )
                .toList();
        if (widget.initialRequestId != null) {
          docs.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.id, ComplaintModel.fromFirestore(a).complaintId);
            final bHighlight = _isHighlightedRequest(b.id, ComplaintModel.fromFirestore(b).complaintId);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد شكاوى سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final complaint = ComplaintModel.fromFirestore(docs[index]);
            final isTarget = _isHighlightedRequest(docs[index].id, complaint.complaintId);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              complaint.title,
                              style: theme.textTheme.titleMedium!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTarget) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: ZaWolfColors.primaryCyan),
                                ),
                                child: const Text(
                                  'الطلب المحدد',
                                  style: TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(complaint.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (complaint.isAnonymous) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_off_outlined,
                          color: ZaWolfColors.primaryCyan,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'أرسلت هذه الشكوى كمجهول',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ZaWolfColors.primaryCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(complaint.body, style: theme.textTheme.bodyMedium),
                  if (complaint.attachmentUrl != null &&
                      complaint.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildAttachmentIndicator(complaint.attachmentUrl!, theme),
                  ],
                  if (complaint.status == 'new') ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed:
                          () => _confirmCancel(
                            'complaints',
                            complaint.complaintId,
                          ),
                      text: 'حذف الشكوى',
                      secondaryText: 'CANCEL COMPLAINT',
                      variant: WolfButtonVariant.outline,
                      height: 40,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeavesHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'leave-history|$userId',
        () =>
            FirebaseFirestore.instance
                .collection('leaves')
                .where('userId', isEqualTo: userId)
                .orderBy('submittedAt', descending: true)
                .limit(25)
                .snapshots(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs =
            (snapshot.data?.docs ?? [])
                .where(
                  (doc) =>
                      _isHighlightedRequest(doc.id, LeaveModel.fromFirestore(doc).leaveId) ||
                      _matchesHistoryFilter(
                        LeaveModel.fromFirestore(doc).status,
                      ),
                )
                .toList();
        if (widget.initialRequestId != null) {
          docs.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.id, LeaveModel.fromFirestore(a).leaveId);
            final bHighlight = _isHighlightedRequest(b.id, LeaveModel.fromFirestore(b).leaveId);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إجازة سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = LeaveModel.fromFirestore(doc);
            final isTarget = _isHighlightedRequest(doc.id, req.leaveId);

            final startStr = DateFormat('yyyy-MM-dd').format(req.startDate);
            final endStr = DateFormat('yyyy-MM-dd').format(req.endDate);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: ZaWolfColors.primaryCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'إجازة ${_getLeaveTypeLabel(req.leaveType)}',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isTarget) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ZaWolfColors.primaryCyan),
                              ),
                              child: const Text(
                                'الطلب المحدد',
                                style: TextStyle(
                                  color: ZaWolfColors.primaryCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      _buildStatusBadge(req.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الفترة: من $startStr إلى $endStr (${req.numberOfDays} أيام)',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (req.submittedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'تاريخ التقديم: ${DateFormat('yyyy/MM/dd · hh:mm a').format(req.submittedAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (req.reason != null && req.reason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'السبب: ${req.reason}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (req.workHandoverTo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تسليم المهام إلى: ${req.workHandoverTo}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.primaryCyan,
                      ),
                    ),
                  ],
                  if (req.attachmentUrl != null &&
                      req.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAttachmentIndicator(req.attachmentUrl!, theme),
                  ],
                  if (req.reviewerComment != null &&
                      req.reviewerComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'سبب الرفض: ${req.reviewerComment}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                    if (req.reviewerName != null &&
                        req.reviewerName!.isNotEmpty)
                      Text(
                        'تم الرفض بواسطة: ${req.reviewerName}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                  RequestApprovalTimeline(
                    data: Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>,
                    ),
                    compact: true,
                  ),
                  if (req.status.startsWith('pending')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: WolfButton(
                            onPressed:
                                () => _confirmCancel('leaves', req.leaveId),
                            text: 'حذف الطلب',
                            variant: WolfButtonVariant.outline,
                            height: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: WolfButton(
                            onPressed: () => _editLeaveRequest(req),
                            text: 'تعديل',
                            variant: WolfButtonVariant.teal,
                            height: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionsHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'permission-history|$userId',
        () =>
            FirebaseFirestore.instance
                .collection('permissions')
                .where('userId', isEqualTo: userId)
                .orderBy('submittedAt', descending: true)
                .limit(25)
                .snapshots(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHistoryLoading();
        }
        if (snapshot.hasError) {
          return _buildHistoryError();
        }
        final docs =
            (snapshot.data?.docs ?? [])
                .where(
                  (doc) =>
                      _isHighlightedRequest(doc.id, PermissionModel.fromFirestore(doc).permissionId) ||
                      _matchesHistoryFilter(
                        PermissionModel.fromFirestore(doc).status,
                      ),
                )
                .toList();
        if (widget.initialRequestId != null) {
          docs.sort((a, b) {
            final aHighlight = _isHighlightedRequest(a.id, PermissionModel.fromFirestore(a).permissionId);
            final bHighlight = _isHighlightedRequest(b.id, PermissionModel.fromFirestore(b).permissionId);
            if (aHighlight && !bHighlight) return -1;
            if (!aHighlight && bHighlight) return 1;
            return 0;
          });
        }
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إذن سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = PermissionModel.fromFirestore(doc);
            final isTarget = _isHighlightedRequest(doc.id, req.permissionId);
            final hours = req.durationMinutes / 60;
            final permissionPeriod = _permissionPeriod(req);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTarget
                    ? ZaWolfColors.primaryCyan.withValues(alpha: 0.08)
                    : ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTarget ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
                  width: isTarget ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: ZaWolfColors.permissionTeal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${PermissionTypePolicy.arabicLabel(req.permissionType)}${req.isDeductible ? ' - استقطاعي' : ''}',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isTarget) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ZaWolfColors.primaryCyan),
                              ),
                              child: const Text(
                                'الطلب المحدد',
                                style: TextStyle(
                                  color: ZaWolfColors.primaryCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      _buildStatusBadge(req.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اليوم: ${req.requestDate} · من ${permissionPeriod.$1} إلى ${permissionPeriod.$2} (${hours.toInt()} س)',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (req.submittedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'تاريخ التقديم: ${DateFormat('yyyy/MM/dd · hh:mm a').format(req.submittedAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (req.isDeductible) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${AttendancePolicy.arabicDeductionLabel(req.salaryDeductionCode, fallback: req.salaryDeductionLabel)} · ${req.salaryDeductionAmount.toStringAsFixed(2)} ${req.salaryCurrency}',
                      style: const TextStyle(color: ZaWolfColors.warning),
                    ),
                  ],
                  if (req.reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'السبب: ${req.reason}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (req.reviewerComment != null &&
                      req.reviewerComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'سبب الرفض: ${req.reviewerComment}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                    if (req.reviewerName != null &&
                        req.reviewerName!.isNotEmpty)
                      Text(
                        'تم الرفض بواسطة: ${req.reviewerName}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                  RequestApprovalTimeline(
                    data: Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>,
                    ),
                    compact: true,
                  ),
                  if (req.status.startsWith('pending')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: WolfButton(
                            onPressed:
                                () => _confirmCancel(
                                  'permissions',
                                  req.permissionId,
                                ),
                            text: 'حذف الطلب',
                            variant: WolfButtonVariant.outline,
                            height: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: WolfButton(
                            onPressed: () => _editPermissionRequest(req),
                            text: 'تعديل',
                            variant: WolfButtonVariant.teal,
                            height: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  (String, String) _permissionPeriod(PermissionModel request) {
    final parts = request.expectedTime.split(':');
    if (parts.length != 2) {
      return (request.expectedTime, request.expectedTime);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return (request.expectedTime, request.expectedTime);
    }
    final anchor = DateTime(2000, 1, 1, hour, minute);
    final duration = Duration(minutes: request.durationMinutes);
    final start =
        request.permissionType == PermissionTypePolicy.lateArrival
            ? anchor.subtract(duration)
            : anchor;
    final end =
        request.permissionType == PermissionTypePolicy.lateArrival
            ? anchor
            : anchor.add(duration);
    final formatter = DateFormat('HH:mm');
    return (formatter.format(start), formatter.format(end));
  }

  bool _matchesHistoryFilter(String status) {
    switch (_historyStatusFilter) {
      case 'pending':
        return status.startsWith('pending') || status == 'new';
      case 'approved':
        return status == 'approved' || status == 'reviewed';
      case 'rejected':
        return status == 'rejected' || status == 'invalid_late';
      default:
        return true;
    }
  }

  Widget _buildHistoryLoading() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SkeletonList(itemCount: 4, itemHeight: 88),
    );
  }

  Widget _buildHistoryError() {
    return const ErrorState(
      message: 'تعذر تحميل السجل الآن. تحقق من الاتصال وحاول مجدداً.',
    );
  }

  Widget _buildEmptyState(String text) {
    return EmptyState(
      title: text,
      subtitle: 'الطلبات التي ترسلها تظهر هنا وتنتقل للسجل بعد المراجعة.',
    );
  }

  Widget _buildStatusBadge(String status) {
    final (label, dsStatus) = switch (status) {
      'approved' => ('مقبول', DsStatus.approved),
      'rejected' => ('مرفوض', DsStatus.rejected),
      'invalid_late' => ('غير مقبول (متأخر)', DsStatus.rejected),
      'pending_hr' => ('بانتظار HR', DsStatus.pendingAction),
      'pending_manager' => ('بانتظار المدير', DsStatus.pendingAction),
      'pending_ceo' => ('بانتظار CEO', DsStatus.pendingAction),
      'cancelled' => ('ملغي', DsStatus.neutral),
      'reviewed' => ('تمت المراجعة', DsStatus.approved),
      'closed' => ('مغلقة', DsStatus.neutral),
      _ => ('معلق', DsStatus.pendingAction),
    };
    return StatusPill(status: dsStatus, label: label);
  }

  String _getLeaveTypeLabel(String type) {
    return LeaveTypePolicy.arabicLabel(type);
  }
}
