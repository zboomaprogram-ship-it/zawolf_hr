import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/leave_service.dart';
import '../../services/complaint_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/advance_service.dart';
import '../../models/permission_model.dart';
import '../../models/leave_model.dart';
import '../../models/advance_model.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../shared/requests_log_screen.dart';

class EmployeeRequestsScreen extends StatefulWidget {
  const EmployeeRequestsScreen({super.key});

  @override
  State<EmployeeRequestsScreen> createState() => _EmployeeRequestsScreenState();
}

class _EmployeeRequestsScreenState extends State<EmployeeRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyPermission = GlobalKey<FormState>();
  final _formKeyLeave = GlobalKey<FormState>();
  final _formKeyComplaint = GlobalKey<FormState>();

  // Permission form fields
  String _permissionType = 'early_leave'; // early_leave | late_arrival
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _permissionDurationHours = 2;
  final _permissionReasonController = TextEditingController();

  // Leave form fields
  String _leaveType = 'annual'; // annual | sick | casual | day_off
  DateTime _leaveStart = DateTime.now().add(const Duration(days: 1));
  DateTime _leaveEnd = DateTime.now().add(const Duration(days: 2));
  final _leaveReasonController = TextEditingController();
  String? _attachmentUrl;

  // Advance form fields
  final _formKeyAdvance = GlobalKey<FormState>();
  final _advanceAmountController = TextEditingController();
  final _advanceReasonController = TextEditingController();

  final _complaintTitleController = TextEditingController();
  final _complaintBodyController = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _permissionReasonController.dispose();
    _leaveReasonController.dispose();
    _advanceAmountController.dispose();
    _advanceReasonController.dispose();
    _complaintTitleController.dispose();
    _complaintBodyController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectLeaveDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _leaveStart, end: _leaveEnd),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _leaveStart = picked.start;
        _leaveEnd = picked.end;
      });
    }
  }

  // Submission handlers
  Future<void> _submitPermission(UserModel employee) async {
    if (!_formKeyPermission.currentState!.validate()) return;

    setState(() => _loading = true);
    final service = PermissionService();

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final monthKey = DateFormat('yyyy-MM').format(now);

      final expectedTimeStr =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      final balance = employee.permissionBalance;
      final bool exceededLimit =
          balance.usedThisMonth >= 2 ||
          (balance.usedHoursThisMonth + _permissionDurationHours) > 5.0;

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
        isExceedingQuota: exceededLimit,
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
        _tabController.animateTo(1); // switch to history tab
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل الإرسال: ${e.toString().replaceAll('Exception: ', '')}',
            ),
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

    try {
      final days = _leaveEnd.difference(_leaveStart).inDays + 1;

      final req = LeaveModel(
        leaveId: '',
        userId: employee.uid,
        employeeId: employee.employeeId,
        employeeName: employee.displayName,
        department: employee.department,
        locationId: employee.locationId,
        managerId: employee.managerId ?? '',
        leaveType: _leaveType,
        startDate: _leaveStart,
        endDate: _leaveEnd,
        numberOfDays: days,
        reason: _leaveReasonController.text.trim(),
        attachmentUrl: _attachmentUrl,
        status: 'pending',
      );

      await service.submitLeaveRequest(req, employee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم تقديم طلب الإجازة بنجاح'),
          ),
        );
        _leaveReasonController.clear();
        setState(() => _attachmentUrl = null);
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التقديم: ${e.toString().replaceAll('Exception: ', '')}',
            ),
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
      final monthKey = DateFormat('yyyy-MM').format(now);

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
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التقديم: ${e.toString().replaceAll('Exception: ', '')}',
            ),
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
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل إرسال الشكوى: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Cancel Request Action
  Future<void> _cancelRequest(String collectionPath, String docId) async {
    final actorId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .update({'status': 'cancelled'});
      await AuditLogService.instance.record(
        actorId: actorId,
        action: 'request_cancelled',
        targetCollection: collectionPath,
        targetId: docId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الإلغاء: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة الطلبات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.history_toggle_off,
                color: ZaWolfColors.primaryCyan,
              ),
              tooltip: 'سجل الطلبات المقبولة والمرفوضة',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestsLogScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'تقديم طلب جديد'),
              Tab(text: 'سجل طلباتي'),
            ],
            labelColor: ZaWolfColors.primaryCyan,
            unselectedLabelColor: ZaWolfColors.textSecondary,
            indicatorColor: ZaWolfColors.primaryCyan,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Submit Form Console
            _buildSubmitConsole(user, theme),

            // Tab 2: Requests History
            _buildHistoryConsole(user, theme),
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
          // Sub Segment Tabs
          Text(
            'اختر نوع الطلب / Select Request Type',
            style: theme.textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: const [
                    Tab(icon: Icon(Icons.access_time), text: 'إذن شخصي'),
                    Tab(icon: Icon(Icons.calendar_month), text: 'إجازة رسمية'),
                    Tab(icon: Icon(Icons.payments), text: 'سلفة مالية'),
                    Tab(icon: Icon(Icons.report_problem), text: 'شكوى'),
                  ],
                  labelColor: ZaWolfColors.primaryCyan,
                  unselectedLabelColor: ZaWolfColors.textSecondary,
                  indicatorColor: ZaWolfColors.primaryCyan,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 480,
                  child: TabBarView(
                    children: [
                      // Sub-tab 1: Permission form
                      _buildPermissionForm(user, theme),

                      // Sub-tab 2: Leave form
                      _buildLeaveForm(user, theme),

                      // Sub-tab 3: Advance form
                      _buildAdvanceForm(user, theme),

                      // Sub-tab 4: Complaint form
                      _buildComplaintForm(user, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionForm(UserModel user, ThemeData theme) {
    final balance = user.permissionBalance;
    final bool exceededLimit =
        balance.usedThisMonth >= 2 ||
        (balance.usedHoursThisMonth + _permissionDurationHours) > 5.0;

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
                          'الأذونات المستخدمة هذا الشهر: ${balance.usedThisMonth}/2 أذونات',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'إجمالي الساعات المستخدمة: ${balance.usedHoursThisMonth.toInt()}/5 ساعات',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: ZaWolfColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chips selection for type
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text('مغادرة مبكرة (Early Leave)'),
                    ),
                    selected: _permissionType == 'early_leave',
                    onSelected: (val) {
                      if (val) setState(() => _permissionType = 'early_leave');
                    },
                    selectedColor: ZaWolfColors.permissionTeal,
                    checkmarkColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text('تأخير حضور (Late Arrival)'),
                    ),
                    selected: _permissionType == 'late_arrival',
                    onSelected: (val) {
                      if (val) setState(() => _permissionType = 'late_arrival');
                    },
                    selectedColor: ZaWolfColors.permissionTeal,
                    checkmarkColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Late arrival warning if selected
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
                        'ملاحظة: يجب تقديم إذن تأخير الحضور قبل موعد بداية العمل الرسمي لتفادي الرفض التلقائي.',
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

            // Time Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _permissionType == 'early_leave'
                      ? 'وقت المغادرة المتوقع:'
                      : 'وقت الحضور المتوقع:',
                  style: theme.textTheme.bodyMedium,
                ),
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
                ),
              ],
            ),
            const Divider(color: ZaWolfColors.surface02),

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
            Slider(
              value: _permissionDurationHours.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: ZaWolfColors.permissionTeal,
              onChanged: (val) {
                setState(() {
                  _permissionDurationHours = val.toInt();
                });
              },
            ),

            // Reason field
            WolfInputField(
              controller: _permissionReasonController,
              labelText: 'سبب الإذن',
              englishLabel: 'Reason',
              hintText: 'اكتب سبب طلب الإذن بالتفصيل...',
              maxLines: 2,
              validator: (val) =>
                  val == null || val.isEmpty ? 'يرجى كتابة السبب' : null,
            ),
            const SizedBox(height: 20),

            if (exceededLimit) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ZaWolfColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⚠️ تنبيه: لقد تجاوزت الحد الشهري المسموح به. تقديم الإذن يستلزم موافقة إضافية وقد يؤثر على الراتب.',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: ZaWolfColors.error,
                    fontSize: 10,
                  ),
                ),
              ),
            ],

            WolfButton(
              onPressed: () => _submitPermission(user),
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

    return Form(
      key: _formKeyLeave,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leave type selection row
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('سنوية')),
                    selected: _leaveType == 'annual',
                    onSelected: (val) {
                      if (val) setState(() => _leaveType = 'annual');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('مرضية')),
                    selected: _leaveType == 'sick',
                    onSelected: (val) {
                      if (val) setState(() => _leaveType = 'sick');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('عارضة')),
                    selected: _leaveType == 'casual',
                    onSelected: (val) {
                      if (val) setState(() => _leaveType = 'casual');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('يوم إجازة')),
                    selected: _leaveType == 'day_off',
                    onSelected: (val) {
                      if (val) setState(() => _leaveType = 'day_off');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('عمل من المنزل')),
                    selected: _leaveType == 'wfh',
                    onSelected: (val) {
                      if (val) setState(() => _leaveType = 'wfh');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Picker Range
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفترة المحددة: $requestedDays أيام',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'من ${DateFormat('yyyy-MM-dd').format(_leaveStart)} إلى ${DateFormat('yyyy-MM-dd').format(_leaveEnd)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.date_range,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  label: const Text(
                    'تغيير التواريخ',
                    style: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  onPressed: () => _selectLeaveDateRange(context),
                ),
              ],
            ),
            const Divider(color: ZaWolfColors.surface02),

            // Reason
            WolfInputField(
              controller: _leaveReasonController,
              labelText: 'سبب الإجازة',
              englishLabel: 'Reason',
              hintText: 'اكتب تفاصيل الإجازة والسبب...',
              maxLines: 2,
              validator: (val) =>
                  val == null || val.isEmpty ? 'يرجى كتابة السبب' : null,
            ),
            const SizedBox(height: 12),

            // Attachment URL input
            WolfInputField(
              labelText: 'رابط المرفق (جوجل درايف / الخ) - اختياري',
              englishLabel: 'Attachment Link (Optional)',
              hintText: 'https://...',
              textDirection: TextDirection.ltr,
              onChanged: (val) {
                setState(() {
                  _attachmentUrl = val.trim();
                });
              },
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
                if (amt > user.baseMonthlySalary) {
                  return 'المبلغ يتجاوز الراتب الأساسي';
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
            WolfInputField(
              controller: _complaintTitleController,
              labelText: 'عنوان الشكوى',
              englishLabel: 'Complaint Title',
              hintText: 'اكتب عنواناً واضحاً للشكوى...',
              validator: (val) =>
                  val == null || val.trim().length < 3 ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 16),
            WolfInputField(
              controller: _complaintBodyController,
              labelText: 'تفاصيل الشكوى',
              englishLabel: 'Details',
              hintText: 'اكتب تفاصيل الشكوى بوضوح...',
              maxLines: 4,
              validator: (val) => val == null || val.trim().length < 10
                  ? 'يرجى كتابة تفاصيل كافية'
                  : null,
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

  Widget _buildHistoryConsole(UserModel user, ThemeData theme) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'الإجازات'),
              Tab(text: 'الأذونات'),
              Tab(text: 'السلف'),
              Tab(text: 'الشكاوى'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات سلفة سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = AdvanceModel.fromFirestore(doc);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZaWolfColors.surface02),
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
                  if (req.status == 'pending') ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed: () =>
                          _cancelRequest('advances', req.advanceId),
                      text: 'إلغاء الطلب',
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

  Widget _buildComplaintsHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد شكاوى سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final complaint = ComplaintModel.fromFirestore(docs[index]);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZaWolfColors.surface02),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          complaint.title,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(complaint.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(complaint.body, style: theme.textTheme.bodyMedium),
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
      stream: FirebaseFirestore.instance
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إجازة سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = LeaveModel.fromFirestore(doc);

            final startStr = DateFormat('yyyy-MM-dd').format(req.startDate);
            final endStr = DateFormat('yyyy-MM-dd').format(req.endDate);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZaWolfColors.surface02),
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
                  if (req.reason != null && req.reason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'السبب: ${req.reason}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (req.attachmentUrl != null &&
                      req.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.link,
                          color: ZaWolfColors.primaryCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            req.attachmentUrl!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ZaWolfColors.primaryCyan,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (req.reviewerComment != null &&
                      req.reviewerComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تعليق المدير: ${req.reviewerComment}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                  ],
                  if (req.status == 'pending') ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed: () => _cancelRequest('leaves', req.leaveId),
                      text: 'إلغاء الطلب',
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

  Widget _buildPermissionsHistory(String userId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('permissions')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إذن سابقة.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = PermissionModel.fromFirestore(doc);
            final hours = req.durationMinutes / 60;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZaWolfColors.surface02),
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
                            req.permissionType == 'early_leave'
                                ? 'إذن مغادرة مبكرة'
                                : 'إذن تأخير حضور',
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusBadge(req.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اليوم: ${req.requestDate} · الوقت: ${req.expectedTime} (${hours.toInt()} س)',
                    style: theme.textTheme.bodyMedium,
                  ),
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
                      'تعليق المراجع: ${req.reviewerComment}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                  ],
                  if (req.status == 'pending_hr' ||
                      req.status == 'pending_manager') ...[
                    const SizedBox(height: 12),
                    WolfButton(
                      onPressed: () =>
                          _cancelRequest('permissions', req.permissionId),
                      text: 'إلغاء الطلب',
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

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, color: ZaWolfColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: ZaWolfColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = ZaWolfColors.success;
        text = 'مقبول';
        break;
      case 'rejected':
        color = ZaWolfColors.error;
        text = 'مرفوض';
        break;
      case 'invalid_late':
        color = ZaWolfColors.error;
        text = 'غير مقبول (متأخر)';
        break;
      case 'pending_hr':
        color = ZaWolfColors.warning;
        text = 'بانتظار HR';
        break;
      case 'pending_manager':
        color = ZaWolfColors.warning;
        text = 'بانتظار المدير';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'ملغي';
        break;
      case 'reviewed':
        color = ZaWolfColors.success;
        text = 'تمت المراجعة';
        break;
      case 'closed':
        color = Colors.grey;
        text = 'مغلقة';
        break;
      case 'pending':
      default:
        color = ZaWolfColors.warning;
        text = 'معلق';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getLeaveTypeLabel(String type) {
    switch (type) {
      case 'annual':
        return 'سنوية';
      case 'sick':
        return 'مرضية';
      case 'casual':
        return 'عارضة';
      case 'day_off':
        return 'يوم إجازة';
      default:
        return type;
    }
  }
}
