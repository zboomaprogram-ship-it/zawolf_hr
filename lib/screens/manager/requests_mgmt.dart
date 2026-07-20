import 'package:flutter/material.dart';
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
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../shared/requests_log_screen.dart';

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() =>
      _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LeaveService _leaveService = LeaveService();
  final PermissionService _permissionService = PermissionService();
  final AttendanceService _attendanceService = AttendanceService();
  final ComplaintService _complaintService = ComplaintService();
  final AdvanceService _advanceService = AdvanceService();
  String _salaryDeductionFilter = 'all';
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>> _streamCache =
      {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    return Scaffold(
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
          controller: _tabController,
          labelColor: ZaWolfColors.primaryCyan,
          unselectedLabelColor: ZaWolfColors.textSecondary,
          indicatorColor: ZaWolfColors.primaryCyan,
          isScrollable: true,
          tabs: const [
            Tab(text: 'الإجازات'),
            Tab(text: 'الأذونات'),
            Tab(text: 'السلف'),
            Tab(text: 'خصومات التأخير'),
            Tab(text: 'مراجعة أمنية'),
            Tab(text: 'الشكاوى'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: LEAVES ──
          _buildLeavesTab(manager, theme),

          // ── TAB 2: PERMISSIONS ──
          _buildPermissionsTab(manager, theme),

          // ── TAB 3: ADVANCES ──
          _buildAdvancesTab(manager, theme),

          // ── TAB 4: SALARY DEDUCTIONS ──
          _buildSalaryDeductionsTab(manager, theme),

          _buildSecurityReviewsTab(manager, theme),

          _buildComplaintsTab(manager, theme),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _cachedStream(
    String key,
    Query<Map<String, dynamic>> query,
  ) {
    return _streamCache.putIfAbsent(key, query.snapshots);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream(
    String collection,
    String reviewerId,
    String role,
  ) {
    var query = _db.collection(collection) as Query<Map<String, dynamic>>;
    final usesManagerChain =
        collection == 'leaves' || collection == 'permissions';
    if (usesManagerChain && EmployeeRole.canActAsApprovalManager(role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewerId);
    } else if (role == EmployeeRole.superAdmin) {
      query = query.where('status', whereIn: ['pending_hr', 'pending_manager']);
    } else {
      query = query.where('status', isEqualTo: 'pending_hr');
    }
    return _cachedStream('pending|$collection|$reviewerId|$role', query);
  }

  Widget _buildLeavesTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream('leaves', reviewer.uid, reviewer.role),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المرحلة الحالية: موافقة المدير المسؤول',
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

  Stream<QuerySnapshot> _permissionReviewStream(UserModel reviewer) {
    var query = _db.collection('permissions') as Query<Map<String, dynamic>>;
    if (EmployeeRole.canActAsApprovalManager(reviewer.role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    } else {
      query = query.where('managerId', isEqualTo: '__no_approver__');
    }
    return query.snapshots();
  }

  Widget _buildPermissionsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _permissionReviewStream(reviewer),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];
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
                          '⚠️ الموظف تجاوز الحد الشهري (إذنان / 5 ساعات) — قد يترتب على الموافقة خصم من الراتب',
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
                      'نوع الإذن: ${perm.permissionType == 'late_arrival' ? 'تأخير حضور' : 'مغادرة مبكرة'}',
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
                    const SizedBox(height: 8),
                    Text(
                      'المرحلة الحالية: موافقة المدير المسؤول',
                      style: const TextStyle(color: ZaWolfColors.primaryCyan),
                    ),
                    const SizedBox(height: 16),

                    if (!perm.isSubmittedAfterWorkStart)
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
                      )
                    else
                      _buildApprovalActions(
                        onApprove: () async {
                          try {
                            await _permissionService.rejectPermission(
                              perm.permissionId,
                              reviewer.uid,
                              'تم تقديم طلب التأخير بعد بداية العمل',
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الإجراء: $e')),
                            );
                          }
                        },
                        onReject: () => _showRejectionDialog(
                          requestId: perm.permissionId,
                          type: 'permission',
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

  Widget _buildSalaryDeductionsTab(UserModel reviewer, ThemeData theme) {
    if (reviewer.role == EmployeeRole.manager) {
      return _buildEmptyState('خصومات الراتب تراجع من HR فقط');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _cachedStream(
        'attendance|salary-deduction|${reviewer.uid}',
        _db
            .collection('attendance')
            .where('salaryDeductionApprovalStatus', isEqualTo: 'pending_hr'),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final allItems =
            snapshot.data?.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList() ??
            [];
        allItems.sort((a, b) => b.date.compareTo(a.date));
        final items = _filterSalaryDeductions(allItems);

        if (allItems.isEmpty) {
          return _buildEmptyState('لا توجد خصومات راتب بانتظار HR');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                        const SizedBox(height: 16),
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
            'المعروض: ${visibleItems.length} خصم',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WolfButton(
                  onPressed: visibleItems.isEmpty
                      ? null
                      : () => _reviewVisibleSalaryDeductions(
                          items: visibleItems,
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
                  onPressed: visibleItems.isEmpty
                      ? null
                      : () => _reviewVisibleSalaryDeductions(
                          items: visibleItems,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: Text(
          approve ? 'اعتماد الخصومات المعروضة؟' : 'رفض الخصومات المعروضة؟',
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'سيتم تطبيق الإجراء على ${items.length} خصم حسب الفلتر الحالي.',
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
    for (final item in items) {
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
        const SizedBox(width: 16),
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
