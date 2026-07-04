import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../services/permission_service.dart';
import '../../services/attendance_service.dart';
import '../../models/employee_role.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../models/permission_model.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showRejectionDialog({
    required String requestId,
    required String type, // 'leave' | 'permission'
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: ZaWolfColors.primaryCyan,
          unselectedLabelColor: ZaWolfColors.textSecondary,
          indicatorColor: ZaWolfColors.primaryCyan,
          tabs: const [
            Tab(text: 'الإجازات'),
            Tab(text: 'الأذونات'),
            Tab(text: 'خصومات التأخير'),
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

          // ── TAB 3: SALARY DEDUCTIONS ──
          _buildSalaryDeductionsTab(manager, theme),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _pendingStream(
    String collection,
    String reviewerId,
    String role,
  ) {
    var query = _db
        .collection(collection)
        .where('status', isEqualTo: 'pending');
    if (role != EmployeeRole.superAdmin) {
      query = query.where('managerId', isEqualTo: reviewerId);
    }
    return query.snapshots();
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
                    const SizedBox(height: 16),
                    _buildApprovalActions(
                      onApprove: () async {
                        try {
                          await _leaveService.approveLeave(
                            leave.leaveId,
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
                        requestId: leave.leaveId,
                        type: 'leave',
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

  Stream<QuerySnapshot> _permissionReviewStream(UserModel reviewer) {
    var query = _db.collection('permissions') as Query<Map<String, dynamic>>;
    if (reviewer.role == EmployeeRole.manager) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    } else if (reviewer.role == EmployeeRole.superAdmin) {
      query = query.where('status', whereIn: ['pending_hr', 'pending_manager']);
    } else {
      query = query.where('status', isEqualTo: 'pending_hr');
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
                      perm.status == 'pending_hr'
                          ? 'المرحلة الحالية: مراجعة HR'
                          : 'المرحلة الحالية: موافقة المدير النهائية',
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

  Widget _buildSalaryDeductionsTab(UserModel reviewer, ThemeData theme) {
    if (reviewer.role == EmployeeRole.manager) {
      return _buildEmptyState('خصومات الراتب تراجع من HR فقط');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('attendance')
          .where('salaryDeductionApprovalStatus', isEqualTo: 'pending_hr')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد خصومات راتب بانتظار HR');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final attendance = AttendanceModel.fromFirestore(docs[index]);
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
                    Text(
                      'التاريخ: ${attendance.date}'
                      '${attendance.lateMinutes > 0 ? ' · التأخير: ${attendance.lateMinutes} دقيقة' : ''}',
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
    switch (type) {
      case 'annual':
        return 'سنوية';
      case 'sick':
        return 'مرضية';
      case 'casual':
        return 'عارضة';
      default:
        return type;
    }
  }
}
