import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../services/permission_service.dart';
import '../../services/attendance_service.dart';
import '../../services/complaint_service.dart';
import '../../models/employee_role.dart';
import '../../models/attendance_model.dart';
import '../../models/complaint_model.dart';
import '../../models/leave_model.dart';
import '../../models/leave_type_policy.dart';
import '../../models/permission_model.dart';
import '../../models/user_model.dart';
import '../../models/advance_model.dart';
import '../../services/advance_service.dart';
import '../../services/request_approval_policy_service.dart';
import '../../services/resignation_service.dart';
import '../../services/administrative_request_service.dart';
import '../../services/attendance_correction_request_service.dart';
import '../../models/request_approval_policy.dart';
import '../../models/resignation_model.dart';
import '../../models/administrative_request_model.dart';
import '../../models/manual_deduction_model.dart';
import '../../services/manual_deduction_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/request_approval_timeline.dart';
import '../shared/requests_log_screen.dart';

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() =>
      _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LeaveService _leaveService = LeaveService();
  final PermissionService _permissionService = PermissionService();
  final AttendanceService _attendanceService = AttendanceService();
  final ComplaintService _complaintService = ComplaintService();
  final AdvanceService _advanceService = AdvanceService();
  final RequestApprovalPolicyService _approvalPolicyService =
      RequestApprovalPolicyService();
  final ResignationService _resignationService = ResignationService();
  final AdministrativeRequestService _administrativeRequestService =
      AdministrativeRequestService();
  bool _isSavingApprovalPolicy = false;
  String _salaryDeductionFilter = 'all';
  String _searchQuery = '';
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>> _streamCache =
      {};

  Future<void> _showRejectionDialog({
    required String requestId,
    required String type, // 'leave' | 'permission' | 'advance'
  }) async {
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ZaWolfColors.surface01,
          title: const Text('أدخل سبب الرفض', textDirection: TextDirection.rtl),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: commentController,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'اكتب سبب الرفض هنا... (مطلوب)',
                hintStyle: TextStyle(color: ZaWolfColors.textMuted),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يجب كتابة سبب الرفض للتوثيق.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final reviewerId = authService.currentUser!.uid;

                try {
                  if (type == 'leave') {
                    await _leaveService.rejectLeave(
                      requestId,
                      reviewerId,
                      commentController.text.trim(),
                    );
                  } else if (type == 'permission') {
                    await _permissionService.rejectPermission(
                      requestId,
                      reviewerId,
                      commentController.text.trim(),
                    );
                  } else if (type == 'advance') {
                    await _advanceService.updateAdvanceStatus(
                      advanceId: requestId,
                      status: 'rejected',
                      reviewerId: reviewerId,
                      comment: commentController.text.trim(),
                    );
                  } else if (type == 'administrative') {
                    await _administrativeRequestService.reject(
                      requestId,
                      authService.currentUser!,
                      commentController.text.trim(),
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم رفض الطلب بنجاح.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('فشل الإجراء: $e')));
                  }
                }
              },
              child: const Text(
                'رفض الطلب',
                style: TextStyle(color: ZaWolfColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showModificationDialog({
    required String requestId,
    required String collection,
    required String userId,
    required String requestTitle,
    Map<String, dynamic>? currentData,
  }) async {
    final commentController = TextEditingController();
    final reasonController = TextEditingController(
      text: (currentData?['reason'] ?? currentData?['notes'] ?? '').toString(),
    );
    final amountController = TextEditingController(
      text: (currentData?['amount'] ?? '').toString(),
    );
    final durationController = TextEditingController(
      text: (currentData?['durationMinutes'] ?? 60).toString(),
    );
    var mode = 'direct'; // 'direct' or 'request'
    DateTime startDate = (currentData?['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime endDate = (currentData?['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime resignationDate = (currentData?['resignationDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    String leaveType = (currentData?['leaveType'] as String?) ?? 'casual';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: ZaWolfColors.surface01,
              title: Text('تعديل $requestTitle', textDirection: TextDirection.rtl),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'direct',
                              label: Text('تعديل مباشر (HR/إدارة)'),
                              icon: Icon(Icons.edit),
                            ),
                            ButtonSegment(
                              value: 'request',
                              label: Text('طلب تعديل من الموظف'),
                              icon: Icon(Icons.send),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (val) => setDialogState(() => mode = val.first),
                        ),
                        const SizedBox(height: 16),
                        if (mode == 'request') ...[
                          TextFormField(
                            controller: commentController,
                            textDirection: TextDirection.rtl,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'تعليمات التعديل للموظف',
                              hintText: 'اكتب ما تطلب من الموظف تعديله في الطلب...',
                            ),
                            validator: (val) {
                              if (mode == 'request' && (val == null || val.trim().isEmpty)) {
                                return 'يرجى كتابة تعليمات التعديل.';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          if (collection == 'leaves') ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('فترة الإجازة'),
                              subtitle: Text(
                                '${DateFormat('yyyy/MM/dd').format(startDate)}  ←  ${DateFormat('yyyy/MM/dd').format(endDate)}',
                              ),
                              trailing: const Icon(Icons.calendar_today, color: ZaWolfColors.primaryCyan),
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  initialDateRange: DateTimeRange(start: startDate, end: endDate),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    startDate = picked.start;
                                    endDate = picked.end;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: leaveType,
                              decoration: const InputDecoration(labelText: 'نوع الإجازة'),
                              dropdownColor: ZaWolfColors.surface02,
                              items: const [
                                DropdownMenuItem(value: 'casual', child: Text('عارضة')),
                                DropdownMenuItem(value: 'annual', child: Text('سنوية')),
                                DropdownMenuItem(value: 'unpaid', child: Text('بدون أجر')),
                                DropdownMenuItem(value: 'sick', child: Text('مرضية')),
                              ],
                              onChanged: (val) => setDialogState(() => leaveType = val ?? 'casual'),
                            ),
                          ],
                          if (collection == 'permissions') ...[
                            TextFormField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'مدة الإذن (بالدقائق)',
                                hintText: '60, 120, 180...',
                              ),
                            ),
                          ],
                          if (collection == 'advances') ...[
                            TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'مبلغ السلفة',
                              ),
                              validator: (val) {
                                if (mode == 'direct' && (double.tryParse(val ?? '') ?? 0) <= 0) {
                                  return 'أدخل مبلغاً صحيحاً للسلفة.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (collection == 'resignations') ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('تاريخ الاستقالة'),
                              subtitle: Text(DateFormat('yyyy/MM/dd').format(resignationDate)),
                              trailing: const Icon(Icons.calendar_today, color: ZaWolfColors.primaryCyan),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: resignationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (picked != null) {
                                  setDialogState(() => resignationDate = picked);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: reasonController,
                            textDirection: TextDirection.rtl,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'السبب / الملاحظات المعدلة',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: Icon(mode == 'direct' ? Icons.check : Icons.send),
                  label: Text(mode == 'direct' ? 'حفظ التعديل المباشر' : 'إرسال للموظف'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final reviewer = authService.currentUser;
                    if (reviewer == null) return;

                    try {
                      if (mode == 'request') {
                        final comment = commentController.text.trim();
                        await _db.collection(collection).doc(requestId).update({
                          'status': 'needs_modification',
                          'reviewerComment': comment,
                          'reviewedBy': reviewer.uid,
                          'reviewerName': reviewer.displayName,
                          'reviewedAt': FieldValue.serverTimestamp(),
                        });
                        await _sendModificationNotif(
                          userId: userId,
                          title: 'مطلوب تعديل الطلب ⚠️',
                          body: 'طلبت الإدارة تعديل $requestTitle: $comment',
                          requestId: requestId,
                          collection: collection,
                        );
                      } else {
                        final patch = <String, dynamic>{
                          'adminModifiedBy': reviewer.uid,
                          'adminModifiedName': reviewer.displayName,
                          'adminModifiedAt': FieldValue.serverTimestamp(),
                        };
                        if (collection == 'leaves') {
                          final days = endDate.difference(startDate).inDays + 1;
                          patch['startDate'] = Timestamp.fromDate(startDate);
                          patch['endDate'] = Timestamp.fromDate(endDate);
                          patch['numberOfDays'] = days > 0 ? days : 1;
                          patch['leaveType'] = leaveType;
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'permissions') {
                          final mins = int.tryParse(durationController.text.trim()) ?? 60;
                          patch['durationMinutes'] = mins;
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'advances') {
                          final amt = double.tryParse(amountController.text.trim()) ?? 0;
                          patch['amount'] = amt;
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'resignations') {
                          patch['resignationDate'] = Timestamp.fromDate(resignationDate);
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'administrativeRequests') {
                          patch['notes'] = reasonController.text.trim();
                        }

                        await _db.collection(collection).doc(requestId).update(patch);
                        await _sendModificationNotif(
                          userId: userId,
                          title: 'تم تعديل بيانات طلبك ✏️',
                          body: 'قامت الإدارة بتحديث بيانات $requestTitle مباشرة.',
                          requestId: requestId,
                          collection: collection,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              mode == 'direct'
                                  ? 'تم حفظ وتحديث بيانات الطلب مباشرة بنجاح.'
                                  : 'تم إرسال إشعار طلب التعديل للموظف بنجاح.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التعديل: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendModificationNotif({
    required String userId,
    required String title,
    required String body,
    required String requestId,
    required String collection,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc();
    await notifRef.set({
      'notificationId': notifRef.id,
      'type': 'request_modification_update',
      'title': title,
      'body': body,
      'data': {
        'route': '/employee/requests',
        'requestId': requestId,
        'collection': collection,
      },
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'unreadNotifications': FieldValue.increment(1),
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final manager = authService.currentUser;
    final theme = Theme.of(context);

    if (manager == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }
    final canReviewSalaryDeductions = EmployeeRole.isHr(manager.role);
    final canReviewTimeCorrections = EmployeeRole.isHrStaff(manager.role);
    final tabs = <Tab>[
      const Tab(text: 'الإجازات'),
      const Tab(text: 'الأذونات'),
      const Tab(text: 'السلف'),
      if (canReviewSalaryDeductions) const Tab(text: 'خصومات التأخير'),
      if (canReviewSalaryDeductions) const Tab(text: 'خصومات الغياب'),
      if (canReviewSalaryDeductions) const Tab(text: 'إلغاء خصم معتمد'),
      const Tab(text: 'خصومات إدارية'),
      if (canReviewTimeCorrections) const Tab(text: 'تصحيح الحضور'),
      const Tab(text: 'مراجعة أمنية'),
      const Tab(text: 'الشكاوى'),
      const Tab(text: 'الاستقالات'),
      const Tab(text: 'إدارية'),
    ];
    final tabViews = <Widget>[
      _buildLeavesTab(manager, theme),
      _buildPermissionsTab(manager, theme),
      _buildAdvancesTab(manager, theme),
      if (canReviewSalaryDeductions)
        _buildSalaryDeductionsTab(manager, theme, reversalOnly: false, absenceOnly: false),
      if (canReviewSalaryDeductions)
        _buildSalaryDeductionsTab(manager, theme, reversalOnly: false, absenceOnly: true),
      if (canReviewSalaryDeductions)
        _buildSalaryDeductionsTab(manager, theme, reversalOnly: true),
      _buildManualDeductionsTab(manager, theme),
      if (canReviewTimeCorrections)
        _buildAttendanceCorrectionsTab(manager, theme),
      _buildSecurityReviewsTab(manager, theme),
      _buildComplaintsTab(manager, theme),
      _buildResignationsTab(manager, theme),
      _buildAdministrativeRequestsTab(manager, theme),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'طلبات الموافقة المعلقة',
            style: theme.textTheme.headlineMedium,
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.history_toggle_off,
                color: ZaWolfColors.primaryCyan,
              ),
              tooltip: 'سجل طلبات الشهر الحالي',
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
            labelColor: ZaWolfColors.primaryCyan,
            unselectedLabelColor: ZaWolfColors.textSecondary,
            indicatorColor: ZaWolfColors.primaryCyan,
            isScrollable: true,
            tabs: tabs,
          ),
        ),
        body: Column(
          children: [
            if (kIsWeb && manager.role == EmployeeRole.superAdmin)
              _buildApprovalPolicyControl(manager),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث باسم الموظف أو القسم',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
            Expanded(child: TabBarView(children: tabViews)),
          ],
        ),
      ),
    );
  }

  Widget _buildManualDeductionsTab(UserModel reviewer, ThemeData theme) {
    final service = ManualDeductionService();
    return StreamBuilder<List<ManualDeductionModel>>(
      stream: service.watchManagedDeductions(reviewer),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan));
        }
        final allItems = snapshot.data ?? [];
        final items = allItems.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.employeeName.toLowerCase().contains(_searchQuery) ||
              item.employeeId.toLowerCase().contains(_searchQuery) ||
              item.reason.toLowerCase().contains(_searchQuery);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showCreateManualDeductionDialog(reviewer),
                icon: const Icon(Icons.add),
                label: const Text('إضافة طلب خصم إداري'),
                style: FilledButton.styleFrom(
                  backgroundColor: ZaWolfColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const WolfCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد طلبات خصم إداري حالياً', textDirection: TextDirection.rtl),
                  ),
                ),
              )
            else
              ...items.map((item) => _buildManualDeductionCard(item, reviewer, theme, service)),
          ],
        );
      },
    );
  }

  Widget _buildManualDeductionCard(
    ManualDeductionModel item,
    UserModel reviewer,
    ThemeData theme,
    ManualDeductionService service,
  ) {
    final isHr = EmployeeRole.isHr(reviewer.role);
    final isSuperAdmin = reviewer.role == EmployeeRole.superAdmin;
    final isMyTeam = item.managerIds.contains(reviewer.uid) || item.managerId == reviewer.uid;

    final canApprove = isSuperAdmin ||
        (isHr && item.status == 'pending_hr') ||
        (isMyTeam && item.status == 'pending_manager');

    final statusColor = switch (item.status) {
      'approved' => ZaWolfColors.error,
      'rejected' => ZaWolfColors.success,
      'pending_manager' => ZaWolfColors.warning,
      _ => ZaWolfColors.permissionTeal,
    };

    final statusLabel = switch (item.status) {
      'approved' => 'معتمد',
      'rejected' => 'مرفوض',
      'pending_manager' => 'بانتظار موافقة المدير',
      _ => 'بانتظار اعتماد HR',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WolfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.40)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  item.employeeName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'مقدار الخصم: ${item.fractionLabel} · بتاريخ ${item.dateKey}',
              style: const TextStyle(color: ZaWolfColors.warning, fontWeight: FontWeight.w600),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Text(
              'السبب: ${item.reason}',
              style: const TextStyle(color: Colors.white70),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            Text(
              'أنشأ الطلب: ${item.createdByName} (${item.createdByRole == 'hr' ? 'HR' : 'مدير'})',
              style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            if (canApprove && (item.status == 'pending_hr' || item.status == 'pending_manager')) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await service.rejectDeduction(
                          deductionId: item.id,
                          reviewer: reviewer,
                          reason: 'تم الرفض بواسطة ${reviewer.displayName}',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم رفض طلب الخصم.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, color: ZaWolfColors.error),
                    label: const Text('رفض', style: TextStyle(color: ZaWolfColors.error)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await service.approveDeduction(
                          deductionId: item.id,
                          reviewer: reviewer,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم اعتماد خصم الراتب وإرسال الإشعارات بنجاح.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('اعتماد الخصم'),
                    style: FilledButton.styleFrom(backgroundColor: ZaWolfColors.error),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateManualDeductionDialog(UserModel reviewer) async {
    final taskService = TaskService();
    final employees = await taskService.loadAssignableEmployees(reviewer);
    if (employees.isEmpty && !EmployeeRole.isHr(reviewer.role)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد موظفون تابعون لك لإسناد الخصم.')),
        );
      }
      return;
    }

    UserModel? selectedUser = employees.isNotEmpty ? employees.first : null;
    DateTime selectedDate = DateTime.now();
    double selectedFraction = 1.0;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: ZaWolfColors.surface01,
              title: const Text('إضافة طلب خصم إداري جديد', textDirection: TextDirection.rtl),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('اختر الموظف:', style: TextStyle(color: ZaWolfColors.textMuted), textDirection: TextDirection.rtl),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<UserModel>(
                        value: selectedUser,
                        isExpanded: true,
                        dropdownColor: ZaWolfColors.surface02,
                        items: employees.map((emp) {
                          return DropdownMenuItem(
                            value: emp,
                            child: Text(
                              '${emp.displayName} (${emp.employeeId.isNotEmpty ? emp.employeeId : emp.department})',
                              textDirection: TextDirection.rtl,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedUser = val),
                        validator: (val) => val == null ? 'يرجى اختيار الموظف' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text('تاريخ الخصم:', style: TextStyle(color: ZaWolfColors.textMuted), textDirection: TextDirection.rtl),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      ),
                      const SizedBox(height: 14),
                      const Text('مقدار الخصم:', style: TextStyle(color: ZaWolfColors.textMuted), textDirection: TextDirection.rtl),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<double>(
                        value: selectedFraction,
                        dropdownColor: ZaWolfColors.surface02,
                        items: const [
                          DropdownMenuItem(value: 0.25, child: Text('ربع يوم (0.25)')),
                          DropdownMenuItem(value: 0.50, child: Text('نصف يوم (0.50)')),
                          DropdownMenuItem(value: 1.00, child: Text('يوم كامل (1.00)')),
                          DropdownMenuItem(value: 2.00, child: Text('يومان (2.00)')),
                          DropdownMenuItem(value: 3.00, child: Text('ثلاثة أيام (3.00)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedFraction = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: reasonController,
                        textDirection: TextDirection.rtl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'أدخل سبب الخصم تفصيلياً (مطلوب)',
                          hintStyle: TextStyle(color: ZaWolfColors.textMuted),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة سبب الخصم' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || selectedUser == null) return;
                    try {
                      final service = ManualDeductionService();
                      await service.createDeductionRequest(
                        creator: reviewer,
                        targetEmployee: selectedUser!,
                        date: selectedDate,
                        dayFraction: selectedFraction,
                        reason: reasonController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              EmployeeRole.isHr(reviewer.role)
                                  ? 'تم إنشاء طلب الخصم بنجاح وتحويله للمدير للموافقة.'
                                  : 'تم إنشاء طلب الخصم بنجاح وتحويله لـ HR للاعتماد.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل إنشاء طلب الخصم: $e')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: ZaWolfColors.error),
                  child: const Text('إرسال الطلب'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdministrativeRequestsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _administrativeRequestService.watchPending(reviewer),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل الطلبات الإدارية');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إدارية معلقة');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final request = AdministrativeRequestModel.fromFirestore(doc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WolfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEmployeeHeader(
                      request.employeeName,
                      request.employeeId,
                      request.department,
                      theme,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AdministrativeRequestCategory.arabicLabel(
                        request.category,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(request.notes),
                    _buildRequestDateLine(
                      label: 'تاريخ تقديم الطلب',
                      date: request.submittedAt,
                      fallback: request.submittedAt,
                    ),
                    if ((request.attachmentUrl ?? '').isNotEmpty)
                      Text(
                        request.attachmentUrl!,
                        style: const TextStyle(color: ZaWolfColors.primaryCyan),
                        textDirection: TextDirection.ltr,
                      ),
                    RequestApprovalTimeline(data: doc.data(), compact: true),
                    const SizedBox(height: 10),
                    _buildApprovalActions(
                      onApprove: () async {
                        try {
                          await _administrativeRequestService.approve(
                            request.id,
                            reviewer,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الموافقة: $error')),
                          );
                        }
                      },
                      onReject: () => _showRejectionDialog(
                        requestId: request.id,
                        type: 'administrative',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResignationsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<List<ResignationModel>>(
      stream: _resignationService.watchPending(reviewer),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر تحميل طلبات الاستقالة: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var requests = snapshot.data!;
        if (_searchQuery.isNotEmpty) {
          requests = requests.where((r) => 
            r.employeeName.toLowerCase().contains(_searchQuery) || 
            r.department.toLowerCase().contains(_searchQuery)
          ).toList();
        }
        if (requests.isEmpty) {
          return const Center(child: Text('لا توجد طلبات استقالة معلقة.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return WolfCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.employeeName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('القسم: ${request.department}'),
                  Text(
                    'تاريخ الاستقالة: ${DateFormat('yyyy/MM/dd').format(request.resignationDate)}',
                  ),
                  const SizedBox(height: 8),
                  Text('السبب: ${request.reason}'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: WolfButton(
                          onPressed: () => _resignationService.review(
                            resignationId: request.resignationId,
                            reviewer: reviewer,
                            approve: true,
                          ),
                          text: 'موافقة',
                          variant: WolfButtonVariant.teal,
                          height: 42,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: WolfButton(
                          onPressed: () => _showModificationDialog(
                            requestId: request.resignationId,
                            collection: 'resignations',
                            userId: request.userId,
                            requestTitle: 'طلب الاستقالة',
                          ),
                          text: 'طلب تعديل',
                          variant: WolfButtonVariant.purple,
                          height: 42,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: WolfButton(
                          onPressed: () =>
                              _rejectResignation(request, reviewer),
                          text: 'رفض',
                          variant: WolfButtonVariant.danger,
                          height: 42,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rejectResignation(
    ResignationModel request,
    UserModel reviewer,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سبب رفض الاستقالة'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _resignationService.review(
      resignationId: request.resignationId,
      reviewer: reviewer,
      approve: false,
      comment: reason,
    );
  }

  Widget _buildApprovalPolicyControl(UserModel superAdmin) {
    return StreamBuilder<RequestApprovalPolicy>(
      stream: _approvalPolicyService.watchPolicy(),
      initialData: const RequestApprovalPolicy(),
      builder: (context, snapshot) {
        final policy = snapshot.data ?? const RequestApprovalPolicy();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: WolfCard(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: policy.requireHrAfterManagerApproval,
              enabled: !_isSavingApprovalPolicy,
              activeColor: ZaWolfColors.primaryCyan,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'مراجعة HR بعد موافقات المديرين',
                textDirection: TextDirection.rtl,
              ),
              subtitle: const Text(
                'عند التفعيل يمر الطلب على المديرين بالترتيب، ثم يقرر HR الموافقة أو الرفض النهائي. رفض أي مدير ينهي الطلب مباشرة.',
                textDirection: TextDirection.rtl,
              ),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _isSavingApprovalPolicy = true);
                try {
                  await _approvalPolicyService.setRequireHrAfterManagerApproval(
                    value: value,
                    updatedBy: superAdmin.uid,
                  );
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر حفظ مسار الموافقات: $error'),
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setState(() => _isSavingApprovalPolicy = false);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _cachedStream(
    String key,
    Query<Map<String, dynamic>> query,
  ) {
    return _streamCache.putIfAbsent(key, query.snapshots);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleApprovalDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    UserModel reviewer,
  ) {
    var filtered = docs;
    if (EmployeeRole.isHrStaff(reviewer.role)) {
      filtered = docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'pending_hr' ||
            data['managerId'] == reviewer.uid;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data();
        final name = (data['employeeName'] ?? '').toString().toLowerCase();
        final dept = (data['department'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || dept.contains(_searchQuery);
      }).toList();
    }
    return filtered;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream(
    String collection,
    String reviewerId,
    String role, {
    String? employeeId,
  }) {
    var query = _db.collection(collection) as Query<Map<String, dynamic>>;
    final usesManagerChain =
        collection == 'leaves' || collection == 'permissions';
    if (collection == 'leaves' && employeeId == 'CEO-100') {
      query = query
          .where('status', isEqualTo: 'pending_ceo')
          .where('ceoId', isEqualTo: reviewerId);
    } else if (usesManagerChain && EmployeeRole.isHrStaff(role)) {
      query = query.where('status', whereIn: ['pending_hr', 'pending_manager']);
    } else if (usesManagerChain && EmployeeRole.canActAsApprovalManager(role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewerId);
    } else {
      query = query.where('status', isEqualTo: 'pending_hr');
    }
    return _cachedStream('pending|$collection|$reviewerId|$role', query);
  }

  Widget _buildLeavesTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream(
        'leaves',
        reviewer.uid,
        reviewer.role,
        employeeId: reviewer.employeeId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات الإجازة');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إجازة معلقة');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final leave = LeaveModel.fromFirestore(docs[index]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: WolfCard(
                hasBorderGlow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEmployeeHeader(
                      leave.employeeName,
                      leave.employeeId,
                      leave.department,
                      theme,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'نوع الإجازة: ${_translateLeaveType(leave.leaveType)}',
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    _buildRequestDateLine(
                      label: 'تاريخ تقديم الطلب',
                      date: leave.submittedAt,
                      fallback: leave.startDate,
                    ),
                    Text(
                      'الفترة: ${DateFormat('yyyy-MM-dd').format(leave.startDate)} إلى ${DateFormat('yyyy-MM-dd').format(leave.endDate)} (${leave.numberOfDays} يوم)',
                    ),
                    if (leave.reason != null && leave.reason!.isNotEmpty)
                      Text(
                        'السبب: ${leave.reason}',
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    if (leave.workHandoverTo.isNotEmpty)
                      Text(
                        'تسليم المهام إلى: ${leave.workHandoverTo}',
                        style: const TextStyle(color: ZaWolfColors.primaryCyan),
                      ),
                    if (leave.attachmentUrl != null &&
                        leave.attachmentUrl!.isNotEmpty) ...[
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
                              leave.attachmentUrl!,
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
                    RequestApprovalTimeline(
                      data: docs[index].data(),
                      compact: true,
                    ),
                    const SizedBox(height: 16),
                    _buildApprovalActions(
                      onApprove: () async {
                        try {
                          await _leaveService.approveLeave(
                            leave.leaveId,
                            reviewer.uid,
                            reviewer.role,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الموافقة: $e')),
                          );
                        }
                      },
                      onReject: () => _showRejectionDialog(
                        requestId: leave.leaveId,
                        type: 'leave',
                      ),
                      onModify: () => _showModificationDialog(
                        requestId: leave.leaveId,
                        collection: 'leaves',
                        userId: leave.userId,
                        requestTitle: 'طلب الإجازة',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      leave.status == 'pending_hr'
                          ? 'المرحلة الحالية: المراجعة النهائية لدى HR'
                          : 'المرحلة الحالية: موافقة المدير المسؤول',
                      style: const TextStyle(color: ZaWolfColors.primaryCyan),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _permissionReviewStream(
    UserModel reviewer,
  ) {
    var query = _db.collection('permissions') as Query<Map<String, dynamic>>;
    if (EmployeeRole.isHrStaff(reviewer.role)) {
      query = query.where('status', whereIn: ['pending_hr', 'pending_manager']);
    } else if (EmployeeRole.canActAsApprovalManager(reviewer.role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    } else {
      query = query.where('managerId', isEqualTo: '__no_approver__');
    }
    return query.snapshots();
  }

  Widget _buildPermissionsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _permissionReviewStream(reviewer),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات الأذونات');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إذن معلقة');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final perm = PermissionModel.fromFirestore(docs[index]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: WolfCard(
                hasBorderGlow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning Banners
                    if (perm.isSubmittedAfterWorkStart)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.error.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          '⚠️ تم تقديم طلب التأخير بعد بداية وقت العمل — لا يُعتد به وفق اللائحة (مرفوض تلقائياً)',
                          style: TextStyle(
                            color: ZaWolfColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    if (perm.isExceedingQuota)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.warning.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'إذن استقطاعي بعد استهلاك الرصيد الشهري — يتطلب موافقة HR ويُخصم من الراتب',
                          style: TextStyle(
                            color: ZaWolfColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),

                    _buildEmployeeHeader(
                      perm.employeeName,
                      perm.employeeId,
                      perm.department,
                      theme,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'نوع الإذن: ${perm.permissionType == 'late_arrival' ? 'تأخير حضور' : 'مغادرة مبكرة'}${perm.isDeductible ? ' · استقطاعي' : ''}',
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    _buildRequestDateLine(
                      label: 'تاريخ تقديم الطلب',
                      date: perm.submittedAt,
                      fallback: _parseDateKey(perm.requestDate),
                    ),
                    Text(
                      'التاريخ: ${perm.requestDate} · الوقت المتوقع: ${perm.expectedTime} · المدة: ${perm.durationMinutes} دقيقة',
                    ),
                    if (perm.salaryDeductionFraction > 0)
                      Text(
                        'أثر الراتب: ${perm.salaryDeductionLabel} · ${perm.salaryDeductionAmount.toStringAsFixed(2)} ${perm.salaryCurrency}',
                        style: const TextStyle(color: ZaWolfColors.warning),
                      ),
                    Text(
                      'السبب: ${perm.reason}',
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                    RequestApprovalTimeline(
                      data: docs[index].data(),
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      perm.status == 'pending_hr'
                          ? 'المرحلة الحالية: المراجعة النهائية لدى HR'
                          : 'المرحلة الحالية: موافقة المدير المسؤول',
                      style: const TextStyle(color: ZaWolfColors.primaryCyan),
                    ),
                    const SizedBox(height: 16),

                    _buildApprovalActions(
                      onApprove: () async {
                        try {
                          await _permissionService.approvePermission(
                            perm.permissionId,
                            reviewer.uid,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الموافقة: $e')),
                          );
                        }
                      },
                      onReject: () => _showRejectionDialog(
                        requestId: perm.permissionId,
                        type: 'permission',
                      ),
                      onModify: () => _showModificationDialog(
                        requestId: perm.permissionId,
                        collection: 'permissions',
                        userId: perm.userId,
                        requestTitle: 'طلب الإذن',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdvancesTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream('advances', reviewer.uid, reviewer.role),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات سلفة معلقة');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final advance = AdvanceModel.fromFirestore(docs[index]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: WolfCard(
                hasBorderGlow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEmployeeHeader(
                      advance.employeeName,
                      advance.employeeId,
                      advance.department,
                      theme,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'المبلغ المطلوب: ${advance.amount} جنيه',
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    _buildRequestDateLine(
                      label: 'تاريخ تقديم الطلب',
                      date: advance.submittedAt,
                    ),
                    if (advance.reason != null && advance.reason!.isNotEmpty)
                      Text(
                        'السبب: ${advance.reason}',
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildApprovalActions(
                      onApprove: () async {
                        try {
                          await _advanceService.approveAdvanceRequest(
                            advanceId: advance.advanceId,
                            reviewer: reviewer,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الموافقة: $e')),
                          );
                        }
                      },
                      onReject: () => _showRejectionDialog(
                        requestId: advance.advanceId,
                        type: 'advance',
                      ),
                      onModify: () => _showModificationDialog(
                        requestId: advance.advanceId,
                        collection: 'advances',
                        userId: advance.userId,
                        requestTitle: 'طلب السلفة',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advance.status == 'pending_hr'
                          ? 'المرحلة الحالية: مراجعة HR'
                          : 'المرحلة الحالية: موافقة المدير النهائية',
                      style: const TextStyle(color: ZaWolfColors.primaryCyan),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComplaintsTab(UserModel reviewer, ThemeData theme) {
    final canReview = EmployeeRole.isHr(reviewer.role);
    if (!canReview) {
      return _buildEmptyState('الشكاوى تظهر لمسؤول HR والإدارة العليا فقط');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'complaints|new|${reviewer.uid}',
        _db.collection('complaints').where('status', isEqualTo: 'new'),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد شكاوى جديدة');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final complaint = ComplaintModel.fromFirestore(docs[index]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: WolfCard(
                hasBorderGlow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (complaint.isAnonymous)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.primaryCyan.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.primaryCyan.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_off_outlined,
                              color: ZaWolfColors.primaryCyan,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'شكوى مجهولة',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'هوية مقدم الشكوى غير ظاهرة للمراجعين',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: ZaWolfColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildEmployeeHeader(
                        complaint.employeeName,
                        complaint.employeeId,
                        complaint.department,
                        theme,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      complaint.title,
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildRequestDateLine(
                      label: 'تاريخ تقديم الشكوى',
                      date: complaint.submittedAt,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complaint.body,
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                      textDirection: TextDirection.rtl,
                    ),
                    if (complaint.attachmentUrl != null &&
                        complaint.attachmentUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              complaint.attachmentUrl!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ZaWolfColors.primaryCyan,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.link,
                            color: ZaWolfColors.primaryCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'مرفق الشكوى:',
                            style: theme.textTheme.bodySmall,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    WolfButton(
                      onPressed: () async {
                        try {
                          await _complaintService.markReviewed(
                            complaint.complaintId,
                            reviewer.uid,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل تحديث الشكوى: $e')),
                          );
                        }
                      },
                      text: 'تمت المراجعة',
                      secondaryText: 'MARK REVIEWED',
                      height: 44,
                      variant: WolfButtonVariant.outline,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSalaryDeductionsTab(
    UserModel reviewer,
    ThemeData theme, {
    required bool reversalOnly,
    bool absenceOnly = false,
  }) {
    if (!EmployeeRole.isHr(reviewer.role)) {
      return _buildEmptyState('خصومات الراتب تراجع من HR فقط');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'attendance|salary-deduction|${reviewer.uid}',
        _db
            .collection('attendance')
            .where(
              'salaryDeductionApprovalStatus',
              whereIn: const ['pending_hr', 'approved', 'reversed'],
            )
            .limit(200),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final loadedItems =
            snapshot.data?.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList() ??
            [];
        final allItems = loadedItems.where((attendance) {
          final status = attendance.salaryDeductionApprovalStatus;
          if (reversalOnly) {
            return status == 'approved' || status == 'reversed';
          }
          final isPending = status == 'pending_hr';
          if (!isPending) return false;

          final isAbsence = attendance.salaryDeductionFraction >= 1.0 ||
              attendance.status == 'absent' ||
              attendance.salaryDeductionCode == 'ABSENCE' ||
              attendance.salaryDeductionCode == 'full_day';

          return absenceOnly ? isAbsence : !isAbsence;
        }).toList();
        allItems.sort((a, b) => b.date.compareTo(a.date));
        final items = _filterSalaryDeductions(allItems);

        if (allItems.isEmpty) {
          return Column(
            children: [
              if (absenceOnly)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: WolfButton(
                    onPressed: () => _syncAbsences(reviewer),
                    text: 'مزامنة وتوليد غياب الشهر الحالي',
                    secondaryText: 'SYNC ABSENCE DEDUCTIONS',
                    variant: WolfButtonVariant.teal,
                    height: 44,
                  ),
                ),
              Expanded(
                child: _buildEmptyState(
                  reversalOnly
                      ? 'لا توجد خصومات معتمدة قابلة للإلغاء'
                      : (absenceOnly
                          ? 'لا توجد خصومات غياب تنتظر مراجعة HR'
                          : 'لا توجد خصومات تأخير تنتظر مراجعة HR'),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (absenceOnly) ...[
              WolfButton(
                onPressed: () => _syncAbsences(reviewer),
                text: 'مزامنة وتوليد غياب الشهر الحالي',
                secondaryText: 'SYNC ABSENCE DEDUCTIONS',
                variant: WolfButtonVariant.teal,
                height: 44,
              ),
              const SizedBox(height: 12),
            ],
            _buildSalaryDeductionToolbar(
              theme: theme,
              visibleItems: items,
              reviewer: reviewer,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              WolfCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'لا توجد خصومات مطابقة لهذا الفلتر',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              )
            else
              ...items.map((attendance) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: WolfCard(
                    hasBorderGlow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEmployeeHeader(
                          attendance.employeeName,
                          attendance.employeeId,
                          attendance.locationName,
                          theme,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          attendance.salaryDeductionLabel,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        _buildRequestDateLine(
                          label: 'يوم وتاريخ الحضور',
                          date: _parseDateKey(attendance.date),
                        ),
                        if (reviewer.role == EmployeeRole.hrAdmin ||
                            reviewer.role == EmployeeRole.hrManager ||
                            reviewer.role == EmployeeRole.superAdmin)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _correctArrivalTime(attendance, reviewer),
                              icon: const Icon(Icons.access_time),
                              label: const Text('تصحيح وقت الوصول'),
                            ),
                          ),
                        Text(
                          'التاريخ: ${attendance.date}'
                          '${attendance.lateMinutes > 0 ? ' · التأخير: ${attendance.lateMinutes} دقيقة' : ''}',
                        ),
                        Text(
                          attendance.checkInTime == null
                              ? 'وقت الحضور: لم يسجل حضوراً'
                              : 'وقت الحضور الفعلي: ${DateFormat('hh:mm a', 'ar').format(attendance.checkInTime!)}',
                          style: const TextStyle(
                            color: ZaWolfColors.textSecondary,
                          ),
                        ),
                        Text(
                          'قيمة الخصم: ${attendance.salaryDeductionAmount.toStringAsFixed(2)} ${attendance.salaryCurrency}',
                          style: const TextStyle(color: ZaWolfColors.warning),
                        ),
                        const SizedBox(height: 6),
                        _SalaryDeductionStatus(
                          status: attendance.salaryDeductionApprovalStatus,
                        ),
                        if (attendance
                                .salaryDeductionReversalReason
                                ?.isNotEmpty ??
                            false)
                          Text(
                            'سبب إلغاء الخصم: ${attendance.salaryDeductionReversalReason}',
                            style: const TextStyle(
                              color: ZaWolfColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (attendance.salaryDeductionApprovalStatus ==
                            'pending_hr')
                          _buildApprovalActions(
                            onApprove: () async {
                              try {
                                await _attendanceService.approveSalaryDeduction(
                                  attendance.attendanceId,
                                  reviewer.uid,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل الموافقة: $e')),
                                );
                              }
                            },
                            onReject: () async {
                              try {
                                await _attendanceService.rejectSalaryDeduction(
                                  attendance.attendanceId,
                                  reviewer.uid,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل الرفض: $e')),
                                );
                              }
                            },
                          )
                        else if (reversalOnly &&
                            attendance.salaryDeductionApprovalStatus ==
                                'approved')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _reverseSalaryDeduction(
                                attendance: attendance,
                                reviewer: reviewer,
                              ),
                              icon: const Icon(Icons.undo),
                              label: const Text('إلغاء الخصم المعتمد'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _syncAbsences(UserModel reviewer) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري فحص ومزامنة غياب الموظفين...')),
      );
      final count = await _attendanceService.syncAbsenceDeductionsForMonth(
        reviewer: reviewer,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'تم توليد $count خصم غياب (يوم كامل) بنجاح.'
                  : 'جميع أيام الغياب محدثة ولا يوجد غياب جديد غير مسجل.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text('فشل المزامنة: $e'),
          ),
        );
      }
    }
  }

  Widget _buildAttendanceCorrectionsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AttendanceCorrectionRequestService().pendingForHr(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final docs = [...?snapshot.data?.docs];
        docs.sort((a, b) {
          final left = a.data()['submittedAt'] as Timestamp?;
          final right = b.data()['submittedAt'] as Timestamp?;
          return (right?.millisecondsSinceEpoch ?? 0).compareTo(
            left?.millisecondsSinceEpoch ?? 0,
          );
        });
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات تصحيح حضور بانتظار HR');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final original = data['originalCheckInTime'] as Timestamp?;
            final requested = data['requestedCheckInTime'] as Timestamp?;
            return WolfCard(
              hasBorderGlow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmployeeHeader(
                    data['employeeName'] as String? ?? 'موظف',
                    data['employeeId'] as String? ?? '',
                    data['department'] as String? ?? '',
                    theme,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'يوم الحضور: ${data['attendanceDate'] ?? ''}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الوقت المسجل: ${original == null ? '--:--' : DateFormat('hh:mm a', 'ar').format(original.toDate())}',
                  ),
                  Text(
                    'الوقت المطلوب: ${requested == null ? '--:--' : DateFormat('hh:mm a', 'ar').format(requested.toDate())}',
                    style: const TextStyle(
                      color: ZaWolfColors.primaryCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('السبب: ${data['reason'] ?? ''}'),
                  const SizedBox(height: 14),
                  _buildApprovalActions(
                    onApprove: () => _reviewAttendanceCorrection(
                      requestId: doc.id,
                      reviewer: reviewer,
                      approve: true,
                    ),
                    onReject: () => _reviewAttendanceCorrection(
                      requestId: doc.id,
                      reviewer: reviewer,
                      approve: false,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reviewAttendanceCorrection({
    required String requestId,
    required UserModel reviewer,
    required bool approve,
  }) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'اعتماد تصحيح الحضور' : 'رفض تصحيح الحضور'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: approve
                ? 'ملاحظة اختيارية للموظف'
                : 'اكتب سبب الرفض للموظف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!approve && commentController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(approve ? 'اعتماد' : 'رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      commentController.dispose();
      return;
    }
    try {
      await AttendanceCorrectionRequestService().review(
        requestId: requestId,
        reviewer: reviewer,
        approve: approve,
        comment: commentController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'تم تصحيح الوقت وإعادة حساب الخصم.'
                  : 'تم رفض طلب التصحيح.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر مراجعة الطلب: $error')));
      }
    } finally {
      commentController.dispose();
    }
  }

  Future<void> _correctArrivalTime(
    AttendanceModel attendance,
    UserModel reviewer,
  ) async {
    final parsedDay = _parseDateKey(attendance.date) ?? DateTime.now();
    final initial = attendance.checkInTime ?? parsedDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null || !mounted) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سبب تصحيح وقت الوصول'),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'مثال: الموظف وصل مبكراً وتعذر التسجيل',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ وإعادة الحساب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final day = _parseDateKey(attendance.date) ?? parsedDay;
    try {
      await _attendanceService.correctCheckInTime(
        attendanceId: attendance.attendanceId,
        reviewerId: reviewer.uid,
        correctedTime: DateTime(
          day.year,
          day.month,
          day.day,
          picked.hour,
          picked.minute,
        ),
        reason: reasonController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصحيح الوقت وإعادة حساب الخصم.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تعديل الوقت: $error')));
      }
    } finally {
      reasonController.dispose();
    }
  }

  List<AttendanceModel> _filterSalaryDeductions(List<AttendanceModel> items) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return items.where((item) {
      switch (_salaryDeductionFilter) {
        case 'today':
          return item.date == today;
        case 'absent':
          return item.salaryDeductionCode == 'absent' ||
              item.status == 'absent';
        case 'late':
          return item.salaryDeductionCode.contains('late') ||
              item.isLate ||
              item.lateMinutes > 0;
        case 'checkout':
          return item.salaryDeductionCode.contains('checkout');
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildSalaryDeductionToolbar({
    required ThemeData theme,
    required List<AttendanceModel> visibleItems,
    required UserModel reviewer,
  }) {
    final pendingItems = visibleItems
        .where((item) => item.salaryDeductionApprovalStatus == 'pending_hr')
        .toList();
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _buildSalaryFilterChip('الكل', 'all'),
              _buildSalaryFilterChip('اليوم', 'today'),
              _buildSalaryFilterChip('غياب', 'absent'),
              _buildSalaryFilterChip('تأخير', 'late'),
              _buildSalaryFilterChip('انصراف', 'checkout'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'المعروض: ${visibleItems.length} · بانتظار المراجعة: ${pendingItems.length}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WolfButton(
                  onPressed: pendingItems.isEmpty
                      ? null
                      : () => _reviewVisibleSalaryDeductions(
                          items: pendingItems,
                          reviewer: reviewer,
                          approve: false,
                        ),
                  text: 'رفض المعروض',
                  secondaryText: 'REJECT FILTER',
                  variant: WolfButtonVariant.outline,
                  height: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WolfButton(
                  onPressed: pendingItems.isEmpty
                      ? null
                      : () => _reviewVisibleSalaryDeductions(
                          items: pendingItems,
                          reviewer: reviewer,
                          approve: true,
                        ),
                  text: 'اعتماد المعروض',
                  secondaryText: 'APPROVE FILTER',
                  variant: WolfButtonVariant.primary,
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryFilterChip(String label, String value) {
    final selected = _salaryDeductionFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.24),
      backgroundColor: ZaWolfColors.surface02,
      labelStyle: TextStyle(
        color: selected ? ZaWolfColors.primaryCyan : ZaWolfColors.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (_) {
        setState(() => _salaryDeductionFilter = value);
      },
    );
  }

  Future<void> _reviewVisibleSalaryDeductions({
    required List<AttendanceModel> items,
    required UserModel reviewer,
    required bool approve,
  }) async {
    final pendingItems = items
        .where((item) => item.salaryDeductionApprovalStatus == 'pending_hr')
        .toList();
    if (pendingItems.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: Text(
          approve ? 'اعتماد الخصومات المعروضة؟' : 'رفض الخصومات المعروضة؟',
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'سيتم تطبيق الإجراء على ${pendingItems.length} خصم معلق حسب الفلتر الحالي.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'اعتماد' : 'رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    var success = 0;
    var failed = 0;
    for (final item in pendingItems) {
      try {
        if (approve) {
          await _attendanceService.approveSalaryDeduction(
            item.attendanceId,
            reviewer.uid,
          );
        } else {
          await _attendanceService.rejectSalaryDeduction(
            item.attendanceId,
            reviewer.uid,
          );
        }
        success++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'تم تنفيذ الإجراء على $success خصم.'
              : 'تم تنفيذ $success وفشل $failed. تحقق من الصلاحيات.',
        ),
      ),
    );
  }

  Future<void> _reverseSalaryDeduction({
    required AttendanceModel attendance,
    required UserModel reviewer,
  }) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء خصم معتمد', textDirection: TextDirection.rtl),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
            hintText: 'اكتب سبب تصحيح القرار',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().length < 5) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('إلغاء الخصم'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.length < 5) return;
    try {
      await _attendanceService.reverseSalaryDeduction(
        attendanceId: attendance.attendanceId,
        reviewerId: reviewer.uid,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الخصم المعتمد وتسجيل السبب.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إلغاء الخصم: $error')));
    }
  }

  Widget _buildSecurityReviewsTab(UserModel reviewer, ThemeData theme) {
    if (reviewer.role == EmployeeRole.manager) {
      return _buildEmptyState('مراجعة أمان الحضور من HR فقط');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'attendance|checkin-security|${reviewer.uid}',
        _db
            .collection('attendance')
            .where('securityReviewStatus', isEqualTo: 'pending_hr'),
      ),
      builder: (context, checkInSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _cachedStream(
            'attendance|checkout-security|${reviewer.uid}',
            _db
                .collection('attendance')
                .where('checkoutSecurityReviewStatus', isEqualTo: 'pending_hr'),
          ),
          builder: (context, checkoutSnapshot) {
            final waiting =
                checkInSnapshot.connectionState == ConnectionState.waiting ||
                checkoutSnapshot.connectionState == ConnectionState.waiting;
            if (waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ZaWolfColors.primaryCyan,
                ),
              );
            }

            final items = <_SecurityReviewItem>[
              ...((checkInSnapshot.data?.docs ?? []).map(
                (doc) => _SecurityReviewItem(
                  attendance: AttendanceModel.fromFirestore(doc),
                  checkout: false,
                  docId: doc.id,
                ),
              )),
              ...((checkoutSnapshot.data?.docs ?? []).map(
                (doc) => _SecurityReviewItem(
                  attendance: AttendanceModel.fromFirestore(doc),
                  checkout: true,
                  docId: doc.id,
                ),
              )),
            ];

            items.sort((a, b) {
              final aTime =
                  (a.checkout
                      ? a.attendance.checkOutTime
                      : a.attendance.checkInTime) ??
                  _parseDateKey(a.attendance.date) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  (b.checkout
                      ? b.attendance.checkOutTime
                      : b.attendance.checkInTime) ??
                  _parseDateKey(b.attendance.date) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

            if (items.isEmpty) {
              return _buildEmptyState('لا توجد مراجعات أمنية معلقة');
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final attendance = item.attendance;
                final reasons = item.checkout
                    ? attendance.checkoutLocationRiskReasons
                    : attendance.locationRiskReasons;
                final riskMessage = item.checkout
                    ? (attendance.checkoutLocationRiskMessage ??
                          'مراجعة انصراف: تحقق من مؤشرات الموقع المسجلة')
                    : (attendance.locationRiskMessage ??
                          'مؤشرات موقع غير معتادة');
                final accuracy = item.checkout
                    ? attendance.checkoutLocationAccuracyMeters
                    : attendance.locationAccuracyMeters;
                final distance = item.checkout
                    ? attendance.checkoutLocationDistanceMeters
                    : attendance.locationDistanceMeters;
                final radius = item.checkout
                    ? attendance.checkoutLocationAllowedRadiusMeters
                    : attendance.locationAllowedRadiusMeters;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: WolfCard(
                    hasBorderGlow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEmployeeHeader(
                          attendance.employeeName,
                          attendance.employeeId,
                          attendance.locationName,
                          theme,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ZaWolfColors.warning.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                item.checkout ? 'مراجعة انصراف' : 'مراجعة حضور',
                                style: const TextStyle(
                                  color: ZaWolfColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.security,
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          riskMessage,
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ) ??
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                          textDirection: TextDirection.rtl,
                        ),
                        _buildRequestDateLine(
                          label: item.checkout ? 'وقت الانصراف' : 'وقت الحضور',
                          date: item.checkout
                              ? attendance.checkOutTime
                              : attendance.checkInTime,
                          fallback: _parseDateKey(attendance.date),
                        ),
                        if (accuracy != null)
                          _buildInfoLine(
                            'دقة الموقع',
                            '${accuracy.toStringAsFixed(0)} متر',
                          ),
                        if (distance != null && radius != null)
                          _buildInfoLine(
                            'المسافة من الفرع',
                            '${distance.toStringAsFixed(0)} متر من نطاق ${radius.toStringAsFixed(0)} متر',
                          ),
                        if (reasons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: reasons
                                  .map(
                                    (reason) => Chip(
                                      label: Text(_riskReasonLabel(reason)),
                                      backgroundColor: ZaWolfColors.surface02,
                                      labelStyle: const TextStyle(
                                        color: ZaWolfColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildApprovalActions(
                          onApprove: () async {
                            try {
                              await _attendanceService.approveSecurityReview(
                                item.docId,
                                reviewer.uid,
                                checkout: item.checkout,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل الموافقة: $e')),
                              );
                            }
                          },
                          onReject: () async {
                            try {
                              await _attendanceService.rejectSecurityReview(
                                item.docId,
                                reviewer.uid,
                                checkout: item.checkout,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل الرفض: $e')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeHeader(
    String name,
    String code,
    String dept,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('القسم: $dept', style: theme.textTheme.bodySmall),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('كود: $code', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: ZaWolfColors.surface02,
              child: Text(
                name.substring(0, 1),
                style: const TextStyle(color: ZaWolfColors.primaryCyan),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApprovalActions({
    required VoidCallback onApprove,
    required VoidCallback onReject,
    VoidCallback? onModify,
  }) {
    return Row(
      children: [
        Expanded(
          child: WolfButton(
            onPressed: onReject,
            text: 'رفض',
            secondaryText: 'REJECT',
            variant: WolfButtonVariant.outline,
            height: 48,
          ),
        ),
        if (onModify != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: WolfButton(
              onPressed: onModify,
              text: 'طلب تعديل',
              secondaryText: 'MODIFY',
              variant: WolfButtonVariant.purple,
              height: 48,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: WolfButton(
            onPressed: onApprove,
            text: 'موافقة',
            secondaryText: 'APPROVE',
            variant: WolfButtonVariant.primary,
            height: 48,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestDateLine({
    required String label,
    DateTime? date,
    DateTime? fallback,
  }) {
    final effectiveDate = date ?? fallback;
    if (effectiveDate == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$label: ${DateFormat('EEEE yyyy/MM/dd - hh:mm a', 'ar').format(effectiveDate)}',
            style: const TextStyle(
              color: ZaWolfColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.calendar_month_outlined,
            size: 15,
            color: ZaWolfColors.primaryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontSize: 12,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.info_outline,
            size: 15,
            color: ZaWolfColors.primaryCyan,
          ),
        ],
      ),
    );
  }

  String _riskReasonLabel(String reason) {
    switch (reason) {
      case 'weak_accuracy':
        return 'دقة ضعيفة';
      case 'very_poor_accuracy':
        return 'دقة مرفوضة';
      case 'near_geofence_edge':
        return 'قريب من الحد';
      case 'offline_capture':
        return 'بدون اتصال';
      case 'mock_location':
        return 'موقع وهمي';
      case 'device_credential_fallback':
        return 'بدون بصمة';
      default:
        return reason;
    }
  }

  DateTime? _parseDateKey(String value) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.done_all, color: ZaWolfColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStreamError(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: ZaWolfColors.warning,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'تحقق من الاتصال ثم أعد فتح الصفحة. لن تختفي الطلبات بصمت عند حدوث خطأ.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _translateLeaveType(String type) {
    if (type == 'wfh') return 'عمل من المنزل';
    return LeaveTypePolicy.arabicLabel(type);
  }
}

class _SecurityReviewItem {
  final AttendanceModel attendance;
  final bool checkout;
  final String docId;

  const _SecurityReviewItem({
    required this.attendance,
    required this.checkout,
    required this.docId,
  });
}

class _SalaryDeductionStatus extends StatelessWidget {
  const _SalaryDeductionStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('خصم معتمد', ZaWolfColors.success, Icons.check_circle),
      'reversed' => ('تم إلغاء الخصم', ZaWolfColors.primaryCyan, Icons.undo),
      'rejected' => ('مرفوض', ZaWolfColors.error, Icons.cancel),
      _ => ('بانتظار HR', ZaWolfColors.warning, Icons.schedule),
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 17, color: color),
        ],
      ),
    );
  }
}
