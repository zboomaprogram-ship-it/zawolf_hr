import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../services/permission_service.dart';
import '../../services/attendance_service.dart';
import '../../services/complaint_service.dart';
import '../../models/employee_role.dart';
import '../../models/attendance_model.dart';
import '../../models/attendance_policy.dart';
import '../../models/complaint_model.dart';
import '../../models/leave_model.dart';
import '../../models/leave_type_policy.dart';
import '../../models/permission_model.dart';
import '../../models/permission_type_policy.dart';
import '../../models/user_model.dart';
import '../../models/advance_model.dart';
import '../../services/advance_service.dart';
import '../../services/request_approval_policy_service.dart';
import '../../services/resignation_service.dart';
import '../../services/administrative_request_service.dart';
import '../../services/pending_requests_service.dart';
import '../../services/attendance_correction_request_service.dart';
import '../../services/hr_direct_request_service.dart';
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
import '../../design_system/components/confirmation_sheet.dart';
import '../../design_system/components/data_presentations.dart';
import '../../features/configurable_requests/data/configurable_requests_repository_impl.dart';
import '../../features/configurable_requests/presentation/custom_request_screens.dart';
import '../../design_system/bidi.dart';
import '../../utils/user_facing_error.dart';
import '../../core/sync/authenticated_operation_client.dart';
import '../../features/request_visibility/domain/entities/request_view_query.dart';
import '../../navigation/request_visibility_entry.dart';
import '../shared/requests_log_screen.dart';

// Approval requests use cards on every viewport. The old desktop master/detail
// table hid request fields and reserved a large blank detail pane.
const bool _requestMasterDetailEnabled = false;

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({
    super.key,
    this.initialCategory,
    this.initialRequestId,
    this.smartTabSelect = false,
  });

  final String? initialCategory;
  final String? initialRequestId;
  final bool smartTabSelect;

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
  final Set<String> _busyRequestIds = {};
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>> _streamCache =
      {};
  final Map<String, Stream<dynamic>> _derivedStreamCache = {};
  final http.Client _requestOperationsHttp = http.Client();
  late final AuthenticatedOperationClient _requestOperations =
      AuthenticatedOperationClient(
        client: _requestOperationsHttp,
        tokenProvider:
            () async => FirebaseAuth.instance.currentUser?.getIdToken(),
      );

  bool _isRequestBusy(String requestId) => _busyRequestIds.contains(requestId);

  /// Runs [action] with the request's action buttons disabled until done
  /// (specs/ui_redesign/06 R2: disable during submission).
  Future<void> _withRequestGuard(
    String requestId,
    Future<void> Function() action,
  ) async {
    if (_busyRequestIds.contains(requestId)) return;
    setState(() => _busyRequestIds.add(requestId));
    try {
      await action();
    } finally {
      _busyRequestIds.remove(requestId);
      if (mounted) setState(() {});
    }
  }

  /// Confirms through [ConfirmationSheet], then runs [run] guarded per row.
  Future<void> _confirmAndRun({
    required String requestId,
    required String title,
    String message = 'سيتم تنفيذ الإجراء على هذا الطلب.',
    required String confirmLabel,
    bool destructive = false,
    required Future<void> Function() run,
  }) async {
    if (!mounted) return;
    final ok = await showConfirmationSheet(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!ok || !mounted) return;
    await _withRequestGuard(requestId, run);
  }

  bool _canArchiveManagedRequest(UserModel reviewer) {
    final role = EmployeeRole.normalize(reviewer.role).trim().toLowerCase();
    return EmployeeRole.isHr(reviewer.role) ||
        const {
          'hr',
          'hr_admin',
          'hr_manager',
          'admin',
          'administrator',
          'owner',
          'super_admin',
        }.contains(role);
  }

  Future<void> _confirmAndArchiveRequest({
    required String collection,
    required String requestId,
  }) async {
    await _confirmAndRun(
      requestId: 'archive-$collection-$requestId',
      title: 'حذف من قائمة الإدارة',
      message:
          'سيُخفى الطلب من قائمة الإدارة مع الاحتفاظ بسجل الطلب والموافقة والتدقيق. لن يُحذف أي سجل مالي.',
      confirmLabel: 'حذف من القائمة',
      destructive: true,
      run: () async {
        final response = await _requestOperations.post(
          Uri.parse(
            'https://notification.zawolf.ai/operations/request-management/archive',
          ),
          operationId: 'archive-$collection-$requestId',
          body: <String, Object?>{
            'collection': collection,
            'requestId': requestId,
          },
        );
        if (!mounted) return;
        final message = switch (response.statusCode) {
          401 => 'انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.',
          403 => 'لا تتوفر لك صلاحية حذف هذا الطلب من القائمة.',
          _ when response.ok => 'تم حذف الطلب من قائمة الإدارة مع حفظ سجله.',
          _ => 'تعذر حذف الطلب من القائمة الآن. أعد المحاولة لاحقاً.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        if (response.ok) {
          _streamCache.clear();
          _derivedStreamCache.clear();
          setState(() {});
        }
      },
    );
  }

  Future<String?> _requestNotificationDescription(String target) async {
    final controller = TextEditingController();
    String? validationMessage;
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    target == 'manager'
                        ? 'تذكير المدير بالطلب'
                        : 'إبلاغ الموظف بالتعديل المطلوب',
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 700,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText:
                            target == 'manager'
                                ? 'وصف التذكير'
                                : 'ما التعديل المطلوب من الموظف؟',
                        hintText: 'اكتب رسالة واضحة تظهر في الإشعار…',
                        errorText: validationMessage,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final value = controller.text.trim();
                        if (value.isEmpty) {
                          setDialogState(
                            () => validationMessage = 'الوصف مطلوب.',
                          );
                          return;
                        }
                        Navigator.of(dialogContext).pop(value);
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('إرسال الإشعار'),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _sendRequestNotification({
    required String collection,
    required String requestId,
    required String target,
  }) async {
    final description = await _requestNotificationDescription(target);
    if (description == null || !mounted) return;
    final operationId =
        'request-notify-$collection-$requestId-$target-${DateTime.now().microsecondsSinceEpoch}';
    await _withRequestGuard(operationId, () async {
      final response = await _requestOperations.post(
        Uri.parse(
          'https://notification.zawolf.ai/operations/request-management/notify',
        ),
        operationId: operationId,
        body: <String, Object?>{
          'collection': collection,
          'requestId': requestId,
          'target': target,
          'description': description,
        },
      );
      if (!mounted) return;
      final message = switch (response.safeCode) {
        'manager_not_assigned' => 'لا يوجد مدير مرتبط بهذا الموظف.',
        'employee_not_linked' => 'تعذر ربط الطلب بحساب الموظف.',
        'recipient_not_found' => 'لم يتم العثور على حساب المستلم.',
        'session_expired' => 'انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.',
        'access_denied' => 'لا تتوفر لك صلاحية إرسال هذا الإشعار.',
        'already_sent' => 'تم إرسال هذا الإشعار سابقاً.',
        _ when response.ok => 'تم إرسال الإشعار بنجاح.',
        _ => 'تعذر إرسال الإشعار الآن. أعد المحاولة لاحقاً.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Widget _buildArchiveRequestAction({
    required UserModel reviewer,
    required String collection,
    required String requestId,
  }) {
    if (!_canArchiveManagedRequest(reviewer)) return const SizedBox.shrink();
    final busy = _isRequestBusy('archive-$collection-$requestId');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            PopupMenuButton<String>(
              tooltip: 'إرسال إشعار بخصوص الطلب',
              onSelected:
                  (target) => _sendRequestNotification(
                    collection: collection,
                    requestId: requestId,
                    target: target,
                  ),
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: 'manager',
                      child: ListTile(
                        leading: Icon(Icons.supervisor_account_outlined),
                        title: Text('تذكير المدير بالطلب'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'employee',
                      child: ListTile(
                        leading: Icon(Icons.edit_notifications_outlined),
                        title: Text('طلب تعديل من الموظف'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_outlined),
                    SizedBox(width: 8),
                    Text('إرسال إشعار'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed:
                  busy
                      ? null
                      : () => _confirmAndArchiveRequest(
                        collection: collection,
                        requestId: requestId,
                      ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف من القائمة'),
              style: TextButton.styleFrom(foregroundColor: ZaWolfColors.error),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _requestOperationsHttp.close();
    super.dispose();
  }

  Future<void> _openAttachment(String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رابط المرفق غير صالح.')));
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط المرفق.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط المرفق.')));
    }
  }

  Future<void> _showDirectHrGrantDialog(UserModel hr) async {
    final reasonController = TextEditingController();
    var kind = 'leave';
    UserModel? employee;
    var leaveType = LeaveTypePolicy.normal;
    var permissionType = PermissionTypePolicy.earlyLeave;
    var startDate = DateTime.now();
    var endDate = DateTime.now();
    var permissionDate = DateTime.now();
    var permissionTime = const TimeOfDay(hour: 9, minute: 0);
    var durationHours = 1;
    var deductible = false;
    var saving = false;

    final users =
        await _db.collection('users').where('isActive', isEqualTo: true).get();
    final employees =
        users.docs
            .map(UserModel.fromFirestore)
            .where(
              (user) => user.uid != hr.uid && !EmployeeRole.isHr(user.role),
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('إضافة مباشرة لموظف'),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'leave',
                                label: Text('إجازة'),
                              ),
                              ButtonSegment(
                                value: 'permission',
                                label: Text('إذن'),
                              ),
                            ],
                            selected: {kind},
                            onSelectionChanged:
                                saving
                                    ? null
                                    : (value) => setDialogState(
                                      () => kind = value.first,
                                    ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<UserModel>(
                            initialValue: employee,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'الموظف',
                            ),
                            items:
                                employees
                                    .map(
                                      (user) => DropdownMenuItem(
                                        value: user,
                                        child: Text(
                                          '${user.displayName} (${user.employeeId})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                saving
                                    ? null
                                    : (value) =>
                                        setDialogState(() => employee = value),
                          ),
                          const SizedBox(height: 14),
                          if (kind == 'leave') ...[
                            DropdownButtonFormField<String>(
                              initialValue: leaveType,
                              decoration: const InputDecoration(
                                labelText: 'نوع الإجازة',
                              ),
                              items:
                                  LeaveTypePolicy.supportedTypes
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(
                                            LeaveTypePolicy.arabicLabel(type),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  saving
                                      ? null
                                      : (value) => setDialogState(
                                        () => leaveType = value ?? leaveType,
                                      ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('فترة الإجازة'),
                              subtitle: Text(
                                '${DateFormat('yyyy/MM/dd').format(startDate)} - ${DateFormat('yyyy/MM/dd').format(endDate)}',
                              ),
                              trailing: const Icon(Icons.date_range),
                              onTap:
                                  saving
                                      ? null
                                      : () async {
                                        final range = await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365),
                                          ),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 730),
                                          ),
                                          initialDateRange: DateTimeRange(
                                            start: startDate,
                                            end: endDate,
                                          ),
                                        );
                                        if (range != null) {
                                          setDialogState(() {
                                            startDate = range.start;
                                            endDate = range.end;
                                          });
                                        }
                                      },
                            ),
                          ] else ...[
                            DropdownButtonFormField<String>(
                              initialValue: permissionType,
                              decoration: const InputDecoration(
                                labelText: 'نوع الإذن',
                              ),
                              items:
                                  const [
                                        PermissionTypePolicy.earlyLeave,
                                        PermissionTypePolicy.lateArrival,
                                        PermissionTypePolicy.midShiftExit,
                                      ]
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(
                                            PermissionTypePolicy.arabicLabel(
                                              type,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  saving
                                      ? null
                                      : (value) => setDialogState(
                                        () =>
                                            permissionType =
                                                value ?? permissionType,
                                      ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('تاريخ ووقت الإذن'),
                              subtitle: Text(
                                '${DateFormat('yyyy/MM/dd').format(permissionDate)} · ${permissionTime.format(context)}',
                              ),
                              onTap:
                                  saving
                                      ? null
                                      : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: permissionDate,
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365),
                                          ),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                        );
                                        if (date == null || !context.mounted) {
                                          return;
                                        }
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: permissionTime,
                                        );
                                        if (time != null) {
                                          setDialogState(() {
                                            permissionDate = date;
                                            permissionTime = time;
                                          });
                                        }
                                      },
                            ),
                            DropdownButtonFormField<int>(
                              initialValue: durationHours,
                              decoration: const InputDecoration(
                                labelText: 'المدة',
                              ),
                              items:
                                  const [1, 2, 3, 4]
                                      .map(
                                        (hours) => DropdownMenuItem(
                                          value: hours,
                                          child: Text('$hours ساعة'),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  saving
                                      ? null
                                      : (value) => setDialogState(
                                        () =>
                                            durationHours =
                                                value ?? durationHours,
                                      ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: deductible,
                              title: const Text('إذن استقطاعي'),
                              onChanged:
                                  saving
                                      ? null
                                      : (value) => setDialogState(
                                        () => deductible = value,
                                      ),
                            ),
                          ],
                          TextField(
                            controller: reasonController,
                            minLines: 2,
                            maxLines: 4,
                            textDirection: TextDirection.rtl,
                            decoration: const InputDecoration(
                              labelText: 'السبب / ملاحظة HR',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed:
                          saving
                              ? null
                              : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                if (employee == null ||
                                    reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('اختر الموظف واكتب السبب.'),
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => saving = true);
                                try {
                                  final service = HrDirectRequestService();
                                  if (kind == 'leave') {
                                    await service.grantLeave(
                                      employee: employee!,
                                      hr: hr,
                                      leaveType: leaveType,
                                      startDate: startDate,
                                      endDate: endDate,
                                      reason: reasonController.text,
                                    );
                                  } else {
                                    final expectedTime =
                                        '${permissionTime.hour.toString().padLeft(2, '0')}:${permissionTime.minute.toString().padLeft(2, '0')}';
                                    await service.grantPermission(
                                      employee: employee!,
                                      hr: hr,
                                      permissionType: permissionType,
                                      date: permissionDate,
                                      expectedTime: expectedTime,
                                      durationMinutes: durationHours * 60,
                                      reason: reasonController.text,
                                      isDeductible: deductible,
                                    );
                                  }
                                  if (!dialogContext.mounted || !mounted) {
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تمت الإضافة والاعتماد مباشرة.',
                                      ),
                                    ),
                                  );
                                } catch (error) {
                                  if (!dialogContext.mounted || !mounted) {
                                    return;
                                  }
                                  setDialogState(() => saving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(userFacingError(error)),
                                    ),
                                  );
                                }
                              },
                      child:
                          saving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('إضافة واعتماد'),
                    ),
                  ],
                ),
          ),
    );
    reasonController.dispose();
  }

  Future<void> _showRejectionDialog({
    required String requestId,
    required String type, // 'leave' | 'permission' | 'advance'
  }) async {
    final commentController = TextEditingController();

    final confirmed = await showConfirmationSheet(
      context,
      title: 'رفض الطلب',
      message: 'سيتم رفض الطلب وإشعار الموظف بالسبب.',
      confirmLabel: 'رفض الطلب',
      commentHint: 'اكتب سبب الرفض هنا... (مطلوب)',
      requireComment: true,
      commentController: commentController,
    );
    if (!confirmed || !mounted) {
      commentController.dispose();
      return;
    }
    final reason = commentController.text.trim();
    commentController.dispose();

    await _withRequestGuard(requestId, () async {
      final authService = Provider.of<AuthService>(context, listen: false);
      final reviewerId = authService.currentUser!.uid;
      try {
        if (type == 'leave') {
          await _leaveService.rejectLeave(requestId, reviewerId, reason);
        } else if (type == 'permission') {
          await _permissionService.rejectPermission(
            requestId,
            reviewerId,
            reason,
          );
        } else if (type == 'advance') {
          await _advanceService.updateAdvanceStatus(
            advanceId: requestId,
            status: 'rejected',
            reviewerId: reviewerId,
            comment: reason,
          );
        } else if (type == 'administrative') {
          await _administrativeRequestService.reject(
            requestId,
            authService.currentUser!,
            reason,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم رفض الطلب بنجاح.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الإجراء: ${userFacingError(e)}')),
          );
        }
      }
    });
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
    DateTime startDate =
        (currentData?['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime endDate =
        (currentData?['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    DateTime resignationDate =
        (currentData?['resignationDate'] as Timestamp?)?.toDate() ??
        DateTime.now();
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
              title: Text(
                'تعديل $requestTitle',
                textDirection: TextDirection.rtl,
              ),
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
                              icon: Icon(Icons.mail_outline),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged:
                              (val) => setDialogState(() => mode = val.first),
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
                              hintText:
                                  'اكتب ما تطلب من الموظف تعديله في الطلب...',
                            ),
                            validator: (val) {
                              if (mode == 'request' &&
                                  (val == null || val.trim().isEmpty)) {
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
                              trailing: const Icon(
                                Icons.calendar_today,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  initialDateRange: DateTimeRange(
                                    start: startDate,
                                    end: endDate,
                                  ),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
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
                              decoration: const InputDecoration(
                                labelText: 'نوع الإجازة',
                              ),
                              dropdownColor: ZaWolfColors.surface02,
                              items: const [
                                DropdownMenuItem(
                                  value: 'casual',
                                  child: Text('عارضة'),
                                ),
                                DropdownMenuItem(
                                  value: 'annual',
                                  child: Text('سنوية'),
                                ),
                                DropdownMenuItem(
                                  value: 'unpaid',
                                  child: Text('بدون أجر'),
                                ),
                                DropdownMenuItem(
                                  value: 'sick',
                                  child: Text('مرضية'),
                                ),
                              ],
                              onChanged:
                                  (val) => setDialogState(
                                    () => leaveType = val ?? 'casual',
                                  ),
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
                                if (mode == 'direct' &&
                                    (double.tryParse(val ?? '') ?? 0) <= 0) {
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
                              subtitle: Text(
                                DateFormat(
                                  'yyyy/MM/dd',
                                ).format(resignationDate),
                              ),
                              trailing: const Icon(
                                Icons.calendar_today,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: resignationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => resignationDate = picked,
                                  );
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
                  icon: Icon(
                    mode == 'direct' ? Icons.check : Icons.mail_outline,
                  ),
                  label: Text(
                    mode == 'direct' ? 'حفظ التعديل المباشر' : 'إرسال للموظف',
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final authService = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
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
                          final mins =
                              int.tryParse(durationController.text.trim()) ??
                              60;
                          patch['durationMinutes'] = mins;
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'advances') {
                          final amt =
                              double.tryParse(amountController.text.trim()) ??
                              0;
                          patch['amount'] = amt;
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'resignations') {
                          patch['resignationDate'] = Timestamp.fromDate(
                            resignationDate,
                          );
                          patch['reason'] = reasonController.text.trim();
                        } else if (collection == 'administrativeRequests') {
                          patch['notes'] = reasonController.text.trim();
                        }

                        await _db
                            .collection(collection)
                            .doc(requestId)
                            .update(patch);
                        await _sendModificationNotif(
                          userId: userId,
                          title: 'تم تعديل بيانات طلبك ✏️',
                          body:
                              'قامت الإدارة بتحديث بيانات $requestTitle مباشرة.',
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
                          SnackBar(
                            content: Text('فشل التعديل: ${userFacingError(e)}'),
                          ),
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
    final notifRef =
        _db.collection('notifications').doc(userId).collection('items').doc();
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
    await _db
        .collection('users')
        .doc(userId)
        .update({'unreadNotifications': FieldValue.increment(1)})
        .catchError((_) {});
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
    final canReviewTimeCorrections = EmployeeRole.isHr(manager.role);
    final canReviewSecurity = EmployeeRole.isHr(manager.role);
    final historyQuery = RequestViewQuery(
      actorScope: RequestActorScope(actorId: manager.uid, role: manager.role),
      tab: RequestViewTab.history,
      fromDate: DateTime.utc(2020),
      toDate: DateTime.now().toUtc().add(const Duration(days: 366)),
    );
    final deductionQuery = RequestViewQuery(
      actorScope: historyQuery.actorScope,
      tab: RequestViewTab.deductions,
      fromDate: historyQuery.fromDate,
      toDate: historyQuery.toDate,
    );
    final tabs = <Tab>[
      const Tab(text: 'الإجازات'),
      const Tab(text: 'الأذونات'),
      const Tab(text: 'السلف'),
      const Tab(text: 'طلبات الاجتماعات'),
      const Tab(text: 'مصروفات ومدفوعات الشركة'),
      const Tab(text: 'خدمات تقنية وتشغيلية'),
      const Tab(text: 'طلبات مخصصة'),
      if (canReviewSalaryDeductions) const Tab(text: 'خصومات التأخير'),
      if (canReviewSalaryDeductions) const Tab(text: 'خصومات الغياب'),
      if (canReviewSalaryDeductions) const Tab(text: 'الخصومات المعتمدة'),
      const Tab(text: 'خصومات إدارية'),
      if (canReviewTimeCorrections) const Tab(text: 'تصحيح الحضور'),
      if (canReviewSecurity) const Tab(text: 'مراجعة أمنية'),
      const Tab(text: 'الشكاوى'),
      const Tab(text: 'الاستقالات'),
      const Tab(text: 'إدارية'),
      const Tab(text: 'السجل الموحد'),
    ];
    final tabViews = <Widget>[
      _buildLeavesTab(manager, theme),
      _buildPermissionsTab(manager, theme),
      _buildAdvancesTab(manager, theme),
      _buildMeetingRequestsTab(manager, theme),
      _buildCompanyExpensesTab(manager, theme),
      _buildItOperationalServicesTab(manager, theme),
      _buildCustomRequestsTab(manager, theme),
      if (canReviewSalaryDeductions)
        _buildSalaryDeductionsTab(
          manager,
          theme,
          reversalOnly: false,
          absenceOnly: false,
        ),
      if (canReviewSalaryDeductions)
        _buildSalaryDeductionsTab(
          manager,
          theme,
          reversalOnly: false,
          absenceOnly: true,
        ),
      if (canReviewSalaryDeductions)
        RequestVisibilityEntry(
          key: const ValueKey('unified-deductions'),
          query: deductionQuery,
          searchTerm: _searchQuery,
        ),
      _buildManualDeductionsTab(manager, theme),
      if (canReviewTimeCorrections)
        _buildAttendanceCorrectionsTab(manager, theme),
      if (canReviewSecurity) _buildSecurityReviewsTab(manager, theme),
      _buildComplaintsTab(manager, theme),
      _buildResignationsTab(manager, theme),
      _buildAdministrativeRequestsTab(manager, theme, widget.initialRequestId),
      RequestVisibilityEntry(
        key: const ValueKey('unified-request-history'),
        query: historyQuery,
        searchTerm: _searchQuery,
      ),
    ];

    final initialCategory =
        widget.initialCategory ??
        (widget.smartTabSelect
            ? PendingRequestsService.instance.firstPendingCategory
            : null);

    int initialTabIndex = 0;
    if (initialCategory != null && initialCategory.isNotEmpty) {
      final cat = initialCategory.trim().toLowerCase();
      if (cat.contains('leave') || cat.contains('إجاز')) {
        initialTabIndex = 0;
      } else if (cat.contains('permission') ||
          cat.contains('إذن') ||
          cat.contains('أذون')) {
        initialTabIndex = 1;
      } else if (cat.contains('advance') || cat.contains('سلف')) {
        initialTabIndex = 2;
      } else if (cat.contains('admin') ||
          cat.contains('مهم') ||
          cat.contains('إداري')) {
        final found = tabs.indexWhere((t) => (t.text ?? '').contains('إدارية'));
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('resign') || cat.contains('استقال')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('الاستقالات'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('complaint') || cat.contains('شكا')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('الشكاوى'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('meeting') || cat.contains('اجتماع')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('الاجتماعات'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('company_os') ||
          cat.contains('expense') ||
          cat.contains('مصروف') ||
          cat.contains('مدفوع')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('مصروفات'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('it_service') ||
          cat.contains('operational') ||
          cat.contains('تقن') ||
          cat.contains('تشغيل')) {
        final found = tabs.indexWhere((t) => (t.text ?? '').contains('تقنية'));
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('custom') || cat.contains('مخصص')) {
        final found = tabs.indexWhere((t) => (t.text ?? '').contains('مخصصة'));
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('manual_deduction') ||
          cat.contains('خصومات إدارية')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('خصومات إدارية'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('salary_deduction') ||
          cat.contains('deduction') ||
          cat.contains('خصم')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('خصومات التأخير'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('attendance_correction') ||
          cat.contains('تصحيح')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('تصحيح الحضور'),
        );
        if (found >= 0) initialTabIndex = found;
      } else if (cat.contains('security') || cat.contains('أمن')) {
        final found = tabs.indexWhere(
          (t) => (t.text ?? '').contains('مراجعة أمنية'),
        );
        if (found >= 0) initialTabIndex = found;
      }
    }

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'طلبات الموافقة المعلقة',
            style: theme.textTheme.headlineMedium,
          ),
          actions: [
            if (EmployeeRole.isHr(manager.role))
              IconButton(
                icon: const Icon(
                  Icons.playlist_add_circle_outlined,
                  color: ZaWolfColors.success,
                ),
                tooltip: 'إضافة إجازة أو إذن مباشرة',
                onPressed: () => _showDirectHrGrantDialog(manager),
              ),
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
                onChanged:
                    (value) => setState(
                      () => _searchQuery = value.trim().toLowerCase(),
                    ),
              ),
            ),
            _buildRequestCategoryPicker(tabs),
            Expanded(
              child: TabBarView(
                children: tabViews
                    .map((child) => _KeepAliveRequestTab(child: child))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Replaces the hard-to-scan label strip with touch-friendly request
  /// containers. Each container keeps the original tab as its destination,
  /// so existing request views and reviewer authorization remain unchanged.
  Widget _buildRequestCategoryPicker(List<Tab> tabs) => SizedBox(
    height: 78,
    child: Builder(
      builder: (context) {
        final controller = DefaultTabController.of(context);
        return ValueListenableBuilder<int>(
          valueListenable: PendingRequestsService.instance.pendingCount,
          builder:
              (_, __, ___) => AnimatedBuilder(
                animation: controller,
                builder:
                    (_, __) => ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        16,
                        10,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final label = tabs[index].text ?? '';
                        final group = _requestGroupForLabel(label);
                        final pending = switch (label) {
                          'الإجازات' =>
                            PendingRequestsService.instance.leavesCount,
                          'الأذونات' =>
                            PendingRequestsService.instance.permissionsCount,
                          'السلف' =>
                            PendingRequestsService.instance.advancesCount,
                          'إدارية' =>
                            PendingRequestsService.instance.administrativeCount,
                          'الاستقالات' =>
                            PendingRequestsService.instance.resignationCount,
                          _ => 0,
                        };
                        final selected = controller.index == index;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => controller.animateTo(index),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 110),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? ZaWolfColors.primaryCyan.withValues(
                                        alpha: .16,
                                      )
                                      : ZaWolfColors.surface01,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    selected
                                        ? ZaWolfColors.primaryCyan
                                        : Colors.white.withValues(alpha: .12),
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      group,
                                      style: TextStyle(
                                        color:
                                            selected
                                                ? ZaWolfColors.primaryCyan
                                                    .withValues(alpha: .78)
                                                : ZaWolfColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        color:
                                            selected
                                                ? ZaWolfColors.primaryCyan
                                                : Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (pending > 0)
                                  PositionedDirectional(
                                    top: 10,
                                    end: -8,
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
                            ),
                          ),
                        );
                      },
                    ),
              ),
        );
      },
    ),
  );

  String _requestGroupForLabel(String label) {
    if (label.contains('إجاز') ||
        label.contains('أذون') ||
        label.contains('تصحيح')) {
      return 'الحضور';
    }
    if (label.contains('سلف') ||
        label.contains('خصومات') ||
        label.contains('مصروف')) {
      return 'المالية';
    }
    if (label.contains('تقنية') || label.contains('تشغيل')) return 'التشغيل';
    if (label.contains('شك') ||
        label.contains('استقال') ||
        label.contains('إدارية')) {
      return 'شؤون الموظفين';
    }
    if (label.contains('اجتماع')) return 'الإدارة';
    if (label.contains('مخصص')) return 'الطلبات';
    if (label.contains('أمن')) return 'الأمان';
    return 'السجل';
  }

  Widget _buildManualDeductionsTab(UserModel reviewer, ThemeData theme) {
    final service = ManualDeductionService();
    return StreamBuilder<List<ManualDeductionModel>>(
      stream: _cachedDerivedStream(
        'manual-deductions|${reviewer.uid}|${reviewer.role}',
        () => service.watchManagedDeductions(reviewer),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل الخصومات الإدارية');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل الخصومات الإدارية...');
        }
        final allItems = snapshot.data ?? [];
        final items =
            allItems.where((item) {
              if (_searchQuery.isEmpty) return true;
              return item.employeeName.toLowerCase().contains(_searchQuery) ||
                  item.employeeId.toLowerCase().contains(_searchQuery) ||
                  item.department.toLowerCase().contains(_searchQuery) ||
                  item.reason.toLowerCase().contains(_searchQuery);
            }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
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
                    child: Text(
                      'لا توجد طلبات خصم إداري حالياً',
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              )
            else
              ...items.map(
                (item) =>
                    _buildManualDeductionCard(item, reviewer, theme, service),
              ),
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
    final isMyTeam =
        item.managerIds.contains(reviewer.uid) ||
        item.managerId == reviewer.uid;

    final canApprove =
        isSuperAdmin ||
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
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
              style: const TextStyle(
                color: ZaWolfColors.warning,
                fontWeight: FontWeight.w600,
              ),
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
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 12,
              ),
              textDirection: TextDirection.rtl,
            ),
            if (canApprove &&
                (item.status == 'pending_hr' ||
                    item.status == 'pending_manager')) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await service.rejectDeduction(
                          deductionId: item.id,
                          reviewer: reviewer,
                          reason: 'تم الرفض بواسطة ${reviewer.displayName}',
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('تم رفض طلب الخصم.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(userFacingError(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, color: ZaWolfColors.error),
                    label: const Text(
                      'رفض',
                      style: TextStyle(color: ZaWolfColors.error),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await service.approveDeduction(
                          deductionId: item.id,
                          reviewer: reviewer,
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم اعتماد خصم الراتب وإرسال الإشعارات بنجاح.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(userFacingError(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('اعتماد الخصم'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZaWolfColors.error,
                    ),
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
          const SnackBar(
            content: Text('لا يوجد موظفون تابعون لك لإسناد الخصم.'),
          ),
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
              title: const Text(
                'إضافة طلب خصم إداري جديد',
                textDirection: TextDirection.rtl,
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'اختر الموظف:',
                        style: TextStyle(color: ZaWolfColors.textMuted),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<UserModel>(
                        initialValue: selectedUser,
                        isExpanded: true,
                        dropdownColor: ZaWolfColors.surface02,
                        items:
                            employees.map((emp) {
                              return DropdownMenuItem(
                                value: emp,
                                child: Text(
                                  '${emp.displayName} (${emp.employeeId.isNotEmpty ? emp.employeeId : emp.department})',
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (val) => setDialogState(() => selectedUser = val),
                        validator:
                            (val) => val == null ? 'يرجى اختيار الموظف' : null,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'تاريخ الخصم:',
                        style: TextStyle(color: ZaWolfColors.textMuted),
                        textDirection: TextDirection.rtl,
                      ),
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
                        label: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'مقدار الخصم:',
                        style: TextStyle(color: ZaWolfColors.textMuted),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<double>(
                        initialValue: selectedFraction,
                        dropdownColor: ZaWolfColors.surface02,
                        items: const [
                          DropdownMenuItem(
                            value: 0.25,
                            child: Text('ربع يوم (0.25)'),
                          ),
                          DropdownMenuItem(
                            value: 0.50,
                            child: Text('نصف يوم (0.50)'),
                          ),
                          DropdownMenuItem(
                            value: 1.00,
                            child: Text('يوم كامل (1.00)'),
                          ),
                          DropdownMenuItem(
                            value: 2.00,
                            child: Text('يومان (2.00)'),
                          ),
                          DropdownMenuItem(
                            value: 3.00,
                            child: Text('ثلاثة أيام (3.00)'),
                          ),
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
                        validator:
                            (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'يرجى كتابة سبب الخصم'
                                    : null,
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
                    if (!formKey.currentState!.validate() ||
                        selectedUser == null) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final service = ManualDeductionService();
                      await service.createDeductionRequest(
                        creator: reviewer,
                        targetEmployee: selectedUser!,
                        date: selectedDate,
                        dayFraction: selectedFraction,
                        reason: reasonController.text.trim(),
                      );
                      if (!dialogContext.mounted || !mounted) return;
                      Navigator.pop(dialogContext);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            EmployeeRole.isHr(reviewer.role)
                                ? 'تم إنشاء طلب الخصم بنجاح وتحويله للمدير للموافقة.'
                                : 'تم إنشاء طلب الخصم بنجاح وتحويله لـ HR للاعتماد.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'فشل إنشاء طلب الخصم: ${userFacingError(e)}',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ZaWolfColors.error,
                  ),
                  child: const Text('إرسال الطلب'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdministrativeRequestsTab(
    UserModel reviewer,
    ThemeData theme,
    String? targetRequestId,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedDerivedStream(
        'administrative|${reviewer.uid}|${reviewer.role}',
        () => _administrativeRequestService.watchPending(reviewer),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل الطلبات الإدارية');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل الطلبات الإدارية...');
        }
        final pendingDocs = snapshot.data?.docs ?? [];
        final isCompanyCeo = reviewer.canReviewCeoStage;
        final scopedDocs =
            isCompanyCeo
                ? pendingDocs
                    .where((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? '').toString();
                      final currentApproverId =
                          (data['currentApproverId'] ?? '').toString();
                      final managerId = (data['managerId'] ?? '').toString();
                      final ceoId = (data['ceoId'] ?? '').toString();
                      if (data['approvalRouteVersion'] == 1) {
                        return status == 'pending_manager' &&
                            (currentApproverId == reviewer.uid ||
                                currentApproverId == 'CEO-100' ||
                                currentApproverId == reviewer.employeeId ||
                                managerId == reviewer.uid);
                      }
                      return (status == 'pending_manager' &&
                              (managerId == reviewer.uid ||
                                  currentApproverId == reviewer.uid)) ||
                          (status == 'pending_ceo' &&
                              (ceoId.isEmpty ||
                                  ceoId == reviewer.uid ||
                                  ceoId == 'CEO-100')) ||
                          status == 'pending_hr';
                    })
                    .toList(growable: false)
                : pendingDocs;
        final docs = _newestFirst(_visibleApprovalDocs(scopedDocs, reviewer));
        final target = targetRequestId?.trim() ?? '';
        final targetMissing =
            target.isNotEmpty && !docs.any((doc) => doc.id == target);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إدارية معلقة');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + (targetMissing ? 1 : 0),
          itemBuilder: (context, index) {
            if (targetMissing && index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: WolfCard(
                  child: Text(
                    'هذا الطلب لم يعد بانتظار قرارك، أو لا تتوفر لك صلاحية فتحه.',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              );
            }
            final doc = docs[targetMissing ? index - 1 : index];
            final request = AdministrativeRequestModel.fromFirestore(doc);
            final isTarget = target.isNotEmpty && request.id == target;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration:
                    isTarget
                        ? BoxDecoration(
                          border: Border.all(
                            color: ZaWolfColors.primaryCyan,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        )
                        : null,
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
                        request.categoryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(request.notes),
                      if (request.category ==
                          AdministrativeRequestCategory.fieldMission) ...[
                        const SizedBox(height: 6),
                        Text(
                          'المكان: ${request.siteName ?? '-'} · التاريخ: ${request.missionDate ?? '-'}',
                        ),
                        Text(
                          'الوقت: ${request.startTime ?? '-'} - ${request.endTime ?? '-'}',
                        ),
                        Text(
                          'العودة للمكتب: ${request.requiresReturnToOffice ? "نعم" : "لا"} · تسجيل الانصراف: ${request.requiresCheckout ? "مطلوب" : "غير مطلوب"}',
                        ),
                      ],
                      _buildRequestDateLine(
                        label: 'تاريخ تقديم الطلب',
                        date: request.submittedAt,
                        fallback: request.submittedAt,
                      ),
                      if ((request.attachmentUrl ?? '').isNotEmpty)
                        Text(
                          request.attachmentUrl!,
                          style: const TextStyle(
                            color: ZaWolfColors.primaryCyan,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      RequestApprovalTimeline(data: doc.data(), compact: true),
                      const SizedBox(height: 10),
                      if (request.category == 'company_os')
                        FilledButton.icon(
                          onPressed:
                              () => context.push(
                                '${EmployeeRole.isHr(reviewer.role) || reviewer.role == EmployeeRole.superAdmin ? '/hr' : '/manager'}/requests/operational/${request.id}',
                              ),
                          icon: const Icon(Icons.route_outlined),
                          label: const Text('فتح مسار الموافقات'),
                        )
                      else if (_canActOnApproval(doc.data(), reviewer))
                        _buildApprovalActions(
                          disabled: _isRequestBusy(request.id),
                          onDelete:
                              () => _deleteRequestDocument(
                                collection: 'administrativeRequests',
                                docId: request.id,
                                requestTitle: 'الطلب الإداري',
                              ),
                          onApprove:
                              () => _confirmAndRun(
                                requestId: request.id,
                                title: 'اعتماد الطلب الإداري',
                                confirmLabel: 'اعتماد',
                                run:
                                    () => _administrativeRequestService.approve(
                                      request.id,
                                      reviewer,
                                    ),
                              ),
                          onReject:
                              () => _showRejectionDialog(
                                requestId: request.id,
                                type: 'administrative',
                              ),
                        ),
                      _buildArchiveRequestAction(
                        reviewer: reviewer,
                        collection: 'administrativeRequests',
                        requestId: request.id,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMeetingRequestsTab(UserModel reviewer, ThemeData theme) {
    final isHrOrAdmin =
        EmployeeRole.isHr(reviewer.role) ||
        reviewer.role == 'admin' ||
        reviewer.role == 'super_admin';
    final stream =
        isHrOrAdmin
            ? FirebaseFirestore.instance
                .collection('meetingRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('meetingRequests')
                .where('currentApproverId', isEqualTo: reviewer.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات الاجتماعات');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل طلبات الاجتماعات...');
        }
        final docs = _newestFirst(snapshot.data?.docs ?? []);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات اجتماعات معلقة');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final startAt = (data['startAt'] as Timestamp?)?.toDate();
            final endAt = (data['endAt'] as Timestamp?)?.toDate();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WolfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEmployeeHeader(
                      '${data['requesterName'] ?? 'موظف'}',
                      '',
                      'طلب اجتماع',
                      theme,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'القاعة: ${data['roomName'] ?? 'غرفة الاجتماعات'}',
                      style: const TextStyle(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السبب: ${data['purpose'] ?? ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (startAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'موعد الاجتماع: ${DateFormat('yyyy/MM/dd hh:mm a').format(startAt)} ${endAt != null ? "حتى ${DateFormat('yyyy/MM/dd hh:mm a').format(endAt)}" : ""}',
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildApprovalActions(
                      disabled: _isRequestBusy(doc.id),
                      onDelete:
                          () => _deleteRequestDocument(
                            collection: 'meetingRequests',
                            docId: doc.id,
                            requestTitle: 'طلب اجتماع',
                          ),
                      onApprove:
                          () => _confirmAndRun(
                            requestId: doc.id,
                            title: 'اعتماد طلب الاجتماع',
                            confirmLabel: 'اعتماد',
                            run: () => _decideMeetingCall(doc.id, true),
                          ),
                      onReject:
                          () => _confirmAndRun(
                            requestId: doc.id,
                            title: 'رفض طلب الاجتماع',
                            confirmLabel: 'رفض',
                            run: () => _decideMeetingCall(doc.id, false),
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

  Future<void> _decideMeetingCall(String requestId, bool approved) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('سجل الدخول مرة أخرى.');
    final response = await http.post(
      Uri.parse(
        'https://notification.zawolf.ai/operations/meeting-requests/$requestId/decision',
      ),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'decision': approved ? 'approved' : 'rejected',
        'comment': '',
        'operationId': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );
    if (response.statusCode >= 300) {
      throw StateError('تعذر حفظ القرار.');
    }
  }

  Widget _buildCompanyExpensesTab(UserModel reviewer, ThemeData theme) {
    return _buildCategoryFilteredAdminTab(
      reviewer: reviewer,
      theme: theme,
      title: 'مصروفات ومدفوعات الشركة',
      emptyMessage: 'لا توجد طلبات مصروفات ومدفوعات معلقة',
      categoryPredicate:
          (cat) =>
              cat == 'company_expenses' ||
              cat == 'expenses' ||
              cat.contains('مصروف') ||
              cat.contains('مدفوع') ||
              cat.contains('مالي'),
    );
  }

  Widget _buildItOperationalServicesTab(UserModel reviewer, ThemeData theme) {
    return _buildCategoryFilteredAdminTab(
      reviewer: reviewer,
      theme: theme,
      title: 'خدمات تقنية وتشغيلية',
      emptyMessage: 'لا توجد طلبات خدمات تقنية وتشغيلية معلقة',
      categoryPredicate:
          (cat) =>
              cat == 'it_services' ||
              cat == 'software_subscription' ||
              cat == 'equipment' ||
              cat.contains('تقن') ||
              cat.contains('تشغيل') ||
              cat.contains('برنامج') ||
              cat.contains('جهاز'),
    );
  }

  Widget _buildCustomRequestsTab(UserModel reviewer, ThemeData theme) {
    return CustomRequestQueueScreen(
      repository: ConfigurableRequestsRepositoryImpl(),
    );
  }

  Widget _buildCategoryFilteredAdminTab({
    required UserModel reviewer,
    required ThemeData theme,
    required String title,
    required String emptyMessage,
    required bool Function(String category) categoryPredicate,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedDerivedStream(
        'admin-cat|$title|${reviewer.uid}|${reviewer.role}',
        () => _administrativeRequestService.watchPending(reviewer),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildStreamError('تعذر تحميل $title');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل $title...');
        }
        final pendingDocs = snapshot.data?.docs ?? [];
        final scopedDocs = _visibleApprovalDocs(pendingDocs, reviewer);
        final filteredDocs =
            scopedDocs.where((doc) {
              final data = doc.data();
              final cat = '${data['category'] ?? ''}'.toLowerCase();
              final catLabel = '${data['categoryLabel'] ?? ''}'.toLowerCase();
              return categoryPredicate(cat) || categoryPredicate(catLabel);
            }).toList();
        _sortNewestFirstInPlace(filteredDocs);

        if (filteredDocs.isEmpty) return _buildEmptyState(emptyMessage);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
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
                      request.categoryLabel,
                      style: const TextStyle(
                        color: ZaWolfColors.primaryCyan,
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
                    if (_canActOnApproval(doc.data(), reviewer))
                      _buildApprovalActions(
                        disabled: _isRequestBusy(request.id),
                        onDelete:
                            () => _deleteRequestDocument(
                              collection: 'administrativeRequests',
                              docId: request.id,
                              requestTitle: title,
                            ),
                        onApprove:
                            () => _confirmAndRun(
                              requestId: request.id,
                              title: 'اعتماد $title',
                              confirmLabel: 'اعتماد',
                              run:
                                  () => _administrativeRequestService.approve(
                                    request.id,
                                    reviewer,
                                  ),
                            ),
                        onReject:
                            () => _showRejectionDialog(
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
      stream: _cachedDerivedStream(
        'resignations|${reviewer.uid}|${reviewer.role}',
        () => _resignationService.watchPending(reviewer),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              userFacingError(
                snapshot.error!,
                fallback: 'تعذر تحميل طلبات الاستقالة حالياً. أعد المحاولة.',
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData) {
          return _buildLoadingState('تحميل طلبات الاستقالة...');
        }
        var requests = [...snapshot.data!];
        requests.sort(
          (a, b) => (b.submittedAt?.millisecondsSinceEpoch ?? 0).compareTo(
            a.submittedAt?.millisecondsSinceEpoch ?? 0,
          ),
        );
        if (_searchQuery.isNotEmpty) {
          requests =
              requests
                  .where(
                    (r) => _matchesSearch([
                      r.employeeName,
                      r.employeeId,
                      r.department,
                      r.reason,
                    ]),
                  )
                  .toList();
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
                          onPressed:
                              _isRequestBusy(request.resignationId)
                                  ? null
                                  : () => _confirmAndRun(
                                    requestId: request.resignationId,
                                    title: 'اعتماد طلب الاستقالة',
                                    confirmLabel: 'اعتماد',
                                    run:
                                        () => _resignationService.review(
                                          resignationId: request.resignationId,
                                          reviewer: reviewer,
                                          approve: true,
                                        ),
                                  ),
                          text: 'موافقة',
                          variant: WolfButtonVariant.teal,
                          height: 42,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: WolfButton(
                          onPressed:
                              () => _showModificationDialog(
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
                          onPressed:
                              _isRequestBusy(request.resignationId)
                                  ? null
                                  : () => _rejectResignation(request, reviewer),
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
    final confirmed = await showConfirmationSheet(
      context,
      title: 'رفض طلب الاستقالة',
      message: 'سيتم رفض الطلب وإشعار الموظف بالسبب.',
      confirmLabel: 'رفض',
      commentHint: 'اكتب سبب الرفض... (مطلوب)',
      requireComment: true,
      commentController: controller,
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (!confirmed || reason.isEmpty) return;
    await _withRequestGuard(request.resignationId, () {
      return _resignationService.review(
        resignationId: request.resignationId,
        reviewer: reviewer,
        approve: false,
        comment: reason,
      );
    });
  }

  Widget _buildApprovalPolicyControl(UserModel superAdmin) {
    return StreamBuilder<RequestApprovalPolicy>(
      stream: _cachedDerivedStream(
        'approval-policy',
        _approvalPolicyService.watchPolicy,
      ),
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
                        content: Text(
                          'تعذر حفظ مسار الموافقات: ${userFacingError(error)}',
                        ),
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

  Stream<T> _cachedDerivedStream<T>(String key, Stream<T> Function() create) {
    return _derivedStreamCache.putIfAbsent(key, create) as Stream<T>;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleApprovalDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    UserModel reviewer,
  ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs
        .where((doc) => doc.data()['managementArchived'] != true)
        .toList(growable: false);
    // HR is allowed to monitor every pending stage.  The old filter fetched
    // pending_manager records and then silently removed them unless HR was
    // also their assigned manager, so valid requests looked missing.
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((doc) {
            final data = doc.data();
            return _matchesSearch([
              data['employeeName'],
              data['employeeId'],
              data['department'],
              data['reason'],
              data['notes'],
              data['categoryLabel'],
            ]);
          }).toList();
    }
    final reviewerIsCeo = reviewer.canReviewCeoStage;
    if (reviewerIsCeo) {
      filtered = filtered
          .where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final currentApproverId =
                (data['currentApproverId'] ?? '').toString();
            final managerId = (data['managerId'] ?? '').toString();
            final ceoId = (data['ceoId'] ?? '').toString();
            if (data['approvalRouteVersion'] == 1) {
              return status == 'pending_manager' &&
                  (currentApproverId == reviewer.uid ||
                      currentApproverId == 'CEO-100' ||
                      currentApproverId == reviewer.employeeId ||
                      managerId == reviewer.uid);
            }
            return (status == 'pending_manager' &&
                    (managerId == reviewer.uid ||
                        currentApproverId == reviewer.uid)) ||
                (status == 'pending_ceo' &&
                    (ceoId.isEmpty ||
                        ceoId == reviewer.uid ||
                        ceoId == 'CEO-100')) ||
                status == 'pending_hr';
          })
          .toList(growable: false);
    }
    return _newestFirst(filtered);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _newestFirst(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ordered = docs.toList();
    _sortNewestFirstInPlace(ordered);
    return ordered;
  }

  void _sortNewestFirstInPlace(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int timestamp(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      for (final field in const ['submittedAt', 'createdAt', 'requestedAt']) {
        final value = data[field];
        if (value is Timestamp) return value.millisecondsSinceEpoch;
        if (value is DateTime) return value.millisecondsSinceEpoch;
      }
      return 0;
    }

    docs.sort((left, right) {
      final target = widget.initialRequestId?.trim() ?? '';
      if (target.isNotEmpty) {
        if (left.id == target) return -1;
        if (right.id == target) return 1;
      }
      final newestFirst = timestamp(right).compareTo(timestamp(left));
      return newestFirst != 0 ? newestFirst : right.id.compareTo(left.id);
    });
  }

  bool _canActOnApproval(Map<String, dynamic> data, UserModel reviewer) {
    final status = '${data['status'] ?? ''}';
    final isSystemOwner = reviewer.role == EmployeeRole.superAdmin;
    final isCompanyCeo = reviewer.canReviewCeoStage;

    // The system owner can resolve any pending request except their own. This
    // is an explicit audited override for unavailable managers, not a shortcut
    // for ordinary manager accounts.
    if (isSystemOwner &&
        data['userId'] != reviewer.uid &&
        const {
          'pending_manager',
          'pending_ceo',
          'pending_hr',
        }.contains(status)) {
      return true;
    }

    if (data['approvalRouteVersion'] == 1) {
      final currentApproverId = (data['currentApproverId'] ?? '').toString();
      return status == 'pending_manager' &&
          (currentApproverId == reviewer.uid ||
              (isCompanyCeo &&
                  (currentApproverId == 'CEO-100' ||
                      currentApproverId == reviewer.employeeId)));
    }
    if (isCompanyCeo) {
      if (status == 'pending_manager') {
        final currentApproverId = (data['currentApproverId'] ?? '').toString();
        final managerId = (data['managerId'] ?? '').toString();
        if (managerId == reviewer.uid ||
            currentApproverId == reviewer.uid ||
            currentApproverId == 'CEO-100' ||
            currentApproverId == reviewer.employeeId) {
          return true;
        }
      }
      if (status == 'pending_ceo') {
        final ceoId = (data['ceoId'] ?? '').toString();
        return ceoId.isEmpty || ceoId == reviewer.uid || ceoId == 'CEO-100';
      }
      if (status == 'pending_hr') {
        return true;
      }
    }
    if (EmployeeRole.isHr(reviewer.role)) {
      if (status == 'pending_hr') return true;
      return status == 'pending_ceo' && isCompanyCeo;
    }
    return status == 'pending_manager' && data['managerId'] == reviewer.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream(
    String collection,
    String reviewerId,
    String role, {
    String? employeeId,
  }) {
    var query = _db.collection(collection) as Query<Map<String, dynamic>>;
    final usesManagerChain =
        collection == 'leaves' ||
        collection == 'permissions' ||
        collection == 'advances';
    final reviewerIsCeo =
        employeeId?.trim().toUpperCase() == 'CEO-100' ||
        role == EmployeeRole.superAdmin;
    if (usesManagerChain && reviewerIsCeo) {
      query = query.where(
        'status',
        whereIn: ['pending_manager', 'pending_ceo'],
      );
    } else if (usesManagerChain && EmployeeRole.isHr(role)) {
      query = query.where(
        'status',
        whereIn: ['pending', 'pending_hr', 'pending_manager'],
      );
    } else if (usesManagerChain && EmployeeRole.canActAsApprovalManager(role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewerId);
    } else {
      query = query.where('status', whereIn: ['pending', 'pending_hr']);
    }
    return _cachedStream(
      'pending|$collection|$reviewerId|$role',
      query.limit(300),
    );
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
          return _buildLoadingState('تحميل طلبات الإجازة...');
        }

        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إجازة معلقة');
        }

        // Web >=980: table + side detail panel instead of full-page
        // navigation (specs/ui_redesign/06 R2).
        final rows = <AppRow>[
          for (final doc in docs)
            () {
              final leave = LeaveModel.fromFirestore(doc);
              return AppRow(
                id: leave.leaveId,
                title: leave.employeeName,
                leading: Icons.beach_access_outlined,
                cells: [
                  _translateLeaveType(leave.leaveType),
                  '${DateFormat('yyyy-MM-dd').format(leave.startDate)}'
                      ' ← ${DateFormat('yyyy-MM-dd').format(leave.endDate)}',
                  leave.status == 'pending_hr'
                      ? 'بانتظار HR'
                      : 'بانتظار المدير',
                ],
              );
            }(),
        ];
        final leaveById = {
          for (final doc in docs) LeaveModel.fromFirestore(doc).leaveId: doc,
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            if (!_requestMasterDetailEnabled || constraints.maxWidth < 980) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder:
                    (context, index) => _buildLeaveRequestCard(
                      doc: docs[index],
                      reviewer: reviewer,
                      theme: theme,
                    ),
              );
            }
            return DsMasterDetailView(
              columns: const [
                AppColumn('الموظف'),
                AppColumn('النوع'),
                AppColumn('الفترة', width: 220),
                AppColumn('المرحلة'),
              ],
              rows: rows,
              detailBuilder: (row) {
                final doc = leaveById[row.id];
                if (doc == null) return const SizedBox.shrink();
                return _buildLeaveRequestCard(
                  doc: doc,
                  reviewer: reviewer,
                  theme: theme,
                );
              },
              emptyDetailLabel:
                  'اختر طلب إجازة من الجدول لعرض التفاصيل والموافقة',
            );
          },
        );
      },
    );
  }

  Widget _buildLeaveRequestCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
    final leave = LeaveModel.fromFirestore(doc);
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
              style: theme.textTheme.titleMedium!.copyWith(color: Colors.white),
            ),
            _buildRequestDateLine(
              label: 'تاريخ تقديم الطلب',
              date: leave.submittedAt,
              fallback: leave.startDate,
            ),
            Text(
              'الفترة: ${DateFormat('yyyy-MM-dd').format(leave.startDate)} إلى ${DateFormat('yyyy-MM-dd').format(leave.endDate)} (${leave.numberOfDays} يوم)',
            ),
            if (leave.convertToAnnual)
              const Text(
                'سيُخصم هذا الطلب من رصيد الإجازة السنوية عند الموافقة.',
                style: TextStyle(color: ZaWolfColors.primaryCyan),
              ),
            if (leave.reason != null && leave.reason!.isNotEmpty)
              Text(
                'السبب: ${leave.reason}',
                style: const TextStyle(color: ZaWolfColors.textSecondary),
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
                    child: Semantics(
                      button: true,
                      label: 'فتح المرفق',
                      child: InkWell(
                        onTap: () => _openAttachment(leave.attachmentUrl!),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                      ),
                    ),
                  ),
                ],
              ),
            ],
            RequestApprovalTimeline(data: doc.data(), compact: true),
            const SizedBox(height: 16),
            if (_canActOnApproval(doc.data(), reviewer))
              _buildApprovalActions(
                disabled: _isRequestBusy(leave.leaveId),
                onDelete:
                    () => _deleteRequestDocument(
                      collection: 'leaves',
                      docId: leave.leaveId,
                      requestTitle: 'طلب الإجازة',
                    ),
                onApprove:
                    () => _confirmAndRun(
                      requestId: leave.leaveId,
                      title: 'اعتماد طلب الإجازة',
                      confirmLabel: 'اعتماد',
                      run:
                          () => _leaveService.approveLeave(
                            leave.leaveId,
                            reviewer.uid,
                            reviewer.role,
                          ),
                    ),
                onReject:
                    () => _showRejectionDialog(
                      requestId: leave.leaveId,
                      type: 'leave',
                    ),
                onModify:
                    () => _showModificationDialog(
                      requestId: leave.leaveId,
                      collection: 'leaves',
                      userId: leave.userId,
                      requestTitle: 'طلب الإجازة',
                    ),
              ),
            _buildArchiveRequestAction(
              reviewer: reviewer,
              collection: 'leaves',
              requestId: leave.leaveId,
            ),
            if (leave.autoApprovedOverridden ||
                leave.autoApprovalOverrideReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZaWolfColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ZaWolfColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: ZaWolfColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'حوّلتها الموارد البشرية للمراجعة: ${leave.autoApprovalOverrideReason ?? "تحويل إداري للمراجعة اليدوية"}',
                        style: const TextStyle(
                          color: ZaWolfColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if ((EmployeeRole.isHr(reviewer.role) ||
                    reviewer.role == 'admin' ||
                    reviewer.role == 'super_admin' ||
                    reviewer.role == 'hr_admin' ||
                    reviewer.role == 'hr_manager' ||
                    reviewer.role == 'hr_staff' ||
                    reviewer.role == 'hr') &&
                (leave.leaveType == 'casual' ||
                    leave.leaveType == 'casual_leave' ||
                    leave.leaveType.contains('casual') ||
                    leave.leaveType.contains('عارض'))) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZaWolfColors.primaryCyan,
                        side: const BorderSide(color: ZaWolfColors.primaryCyan),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _promptEditCasualLeaveDates(leave),
                      icon: const Icon(Icons.edit_calendar, size: 14),
                      label: const Text(
                        'تعديل تاريخ الإجازة العارضة',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZaWolfColors.warning,
                        side: const BorderSide(color: ZaWolfColors.warning),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          () => _promptOverrideCasualLeave(leave.leaveId),
                      icon: const Icon(Icons.rule, size: 14),
                      label: const Text(
                        'تحويل للمراجعة',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              leave.status == 'pending_hr'
                  ? 'المرحلة الحالية: المراجعة النهائية لدى HR'
                  : (leave.status == 'approved'
                      ? 'تم اعتماد الإجازة'
                      : 'المرحلة الحالية: موافقة المدير المسؤول'),
              style: const TextStyle(color: ZaWolfColors.primaryCyan),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptEditCasualLeaveDates(LeaveModel leave) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: leave.startDate,
        end: leave.endDate,
      ),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (pickedRange == null) return;
    if (!mounted) return;

    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text(
              'تعديل تاريخ الإجازة العارضة',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سيتم تعديل تاريخ الإجازة إلى:\n${DateFormat('yyyy-MM-dd').format(pickedRange.start)} إلى ${DateFormat('yyyy-MM-dd').format(pickedRange.end)}',
                  style: const TextStyle(color: ZaWolfColors.primaryCyan),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'سبب التعديل الإداري (اختياري)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('تأكيد وحفظ التعديل'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (reason == null) return;

    try {
      await _leaveService.editCasualLeaveDates(
        leaveId: leave.leaveId,
        startDate: pickedRange.start,
        endDate: pickedRange.end,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تعديل موعد الإجازة العارضة بنجاح وإشعار الموظف والمدير.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تعديل تاريخ الإجازة: $e')));
    }
  }

  Future<void> _promptOverrideCasualLeave(String leaveId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text(
              'تحويل الإجازة العارضة للمراجعة',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سيتم تحويل هذه الإجازة العارضة المعتمدة تلقائياً إلى مسار المراجعة اليدوية بدلاً من الاعتماد التلقائي.',
                  style: TextStyle(color: ZaWolfColors.textSecondary),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'سبب تحويل الإجازة للمراجعة (مطلوب)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: ZaWolfColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  final val = controller.text.trim();
                  if (val.isNotEmpty) Navigator.pop(dialogContext, val);
                },
                child: const Text(
                  'تحويل للمراجعة',
                  style: TextStyle(color: ZaWolfColors.warning),
                ),
              ),
            ],
          ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;

    try {
      await _leaveService.overrideCasualLeave(leaveId: leaveId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحويل الإجازة العارضة للمراجعة وإشعار الموظف والمدير بنجاح.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحويل الإجازة: $e')));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _permissionReviewStream(
    UserModel reviewer,
  ) {
    var query = _db.collection('permissions') as Query<Map<String, dynamic>>;
    final isCompanyCeo = reviewer.employeeId.trim().toUpperCase() == 'CEO-100';
    if (isCompanyCeo) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    } else if (EmployeeRole.isHr(reviewer.role)) {
      query = query.where(
        'status',
        whereIn: ['pending', 'pending_hr', 'pending_manager'],
      );
    } else if (EmployeeRole.canActAsApprovalManager(reviewer.role)) {
      query = query
          .where('status', isEqualTo: 'pending_manager')
          .where('managerId', isEqualTo: reviewer.uid);
    } else {
      query = query.where('managerId', isEqualTo: '__no_approver__');
    }
    return _cachedStream(
      'permissions|${reviewer.uid}|${reviewer.role}',
      query.limit(300),
    );
  }

  Widget _buildPermissionsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _permissionReviewStream(reviewer),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات الأذونات');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل طلبات الأذونات...');
        }

        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات إذن معلقة');
        }

        final rows = <AppRow>[
          for (final doc in docs)
            () {
              final perm = PermissionModel.fromFirestore(doc);
              return AppRow(
                id: perm.permissionId,
                title: perm.employeeName,
                leading: Icons.schedule_outlined,
                cells: [
                  '${perm.permissionType == 'late_arrival' ? 'تأخير حضور' : 'مغادرة مبكرة'}${perm.isDeductible ? ' · استقطاعي' : ''}',
                  '${perm.requestDate} · ${perm.expectedTime}',
                  perm.status == 'pending_hr' ? 'بانتظار HR' : 'بانتظار المدير',
                ],
              );
            }(),
        ];
        final permissionById = {
          for (final doc in docs)
            PermissionModel.fromFirestore(doc).permissionId: doc,
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            if (!_requestMasterDetailEnabled || constraints.maxWidth < 980) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder:
                    (context, index) => _buildPermissionRequestCard(
                      doc: docs[index],
                      reviewer: reviewer,
                      theme: theme,
                    ),
              );
            }
            return DsMasterDetailView(
              columns: const [
                AppColumn('الموظف'),
                AppColumn('النوع'),
                AppColumn('التاريخ والوقت', width: 200),
                AppColumn('المرحلة'),
              ],
              rows: rows,
              detailBuilder: (row) {
                final doc = permissionById[row.id];
                if (doc == null) return const SizedBox.shrink();
                return _buildPermissionRequestCard(
                  doc: doc,
                  reviewer: reviewer,
                  theme: theme,
                );
              },
              emptyDetailLabel:
                  'اختر طلب إذن من الجدول لعرض التفاصيل والموافقة',
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionRequestCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
    final perm = PermissionModel.fromFirestore(doc);
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
              style: theme.textTheme.titleMedium!.copyWith(color: Colors.white),
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
                'أثر الراتب: ${AttendancePolicy.arabicDeductionLabel(perm.salaryDeductionCode, fallback: perm.salaryDeductionLabel)} · ${perm.salaryDeductionAmount.toStringAsFixed(2)} ${perm.salaryCurrency}',
                style: const TextStyle(color: ZaWolfColors.warning),
              ),
            Text(
              'السبب: ${perm.reason}',
              style: const TextStyle(color: ZaWolfColors.textSecondary),
            ),
            RequestApprovalTimeline(data: doc.data(), compact: true),
            const SizedBox(height: 8),
            Text(
              perm.status == 'pending_hr'
                  ? 'المرحلة الحالية: المراجعة النهائية لدى HR'
                  : 'المرحلة الحالية: موافقة المدير المسؤول',
              style: const TextStyle(color: ZaWolfColors.primaryCyan),
            ),
            const SizedBox(height: 16),

            if (_canActOnApproval(doc.data(), reviewer))
              _buildApprovalActions(
                disabled: _isRequestBusy(perm.permissionId),
                onDelete:
                    () => _deleteRequestDocument(
                      collection: 'permissions',
                      docId: perm.permissionId,
                      requestTitle: 'طلب الإذن',
                    ),
                onApprove:
                    () => _confirmAndRun(
                      requestId: perm.permissionId,
                      title: 'اعتماد طلب الإذن',
                      confirmLabel: 'اعتماد',
                      run:
                          () => _permissionService.approvePermission(
                            perm.permissionId,
                            reviewer.uid,
                          ),
                    ),
                onReject:
                    () => _showRejectionDialog(
                      requestId: perm.permissionId,
                      type: 'permission',
                    ),
                onModify:
                    () => _showModificationDialog(
                      requestId: perm.permissionId,
                      collection: 'permissions',
                      userId: perm.userId,
                      requestTitle: 'طلب الإذن',
                    ),
              ),
            _buildArchiveRequestAction(
              reviewer: reviewer,
              collection: 'permissions',
              requestId: perm.permissionId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancesTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream('advances', reviewer.uid, reviewer.role),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات السلف');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل طلبات السلف...');
        }

        final docs = _visibleApprovalDocs(snapshot.data?.docs ?? [], reviewer);
        if (docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات سلفة معلقة');
        }

        final rows = <AppRow>[
          for (final doc in docs)
            () {
              final advance = AdvanceModel.fromFirestore(doc);
              return AppRow(
                id: advance.advanceId,
                title: advance.employeeName,
                leading: Icons.payments_outlined,
                accentColor: ZaWolfColors.warning,
                cells: [
                  '${dsBidi(advance.amount.toString())} جنيه',
                  advance.submittedAt == null
                      ? ''
                      : DateFormat('yyyy-MM-dd').format(advance.submittedAt!),
                  _advanceStageLabel(doc.data()),
                ],
              );
            }(),
        ];
        final advanceById = {
          for (final doc in docs)
            AdvanceModel.fromFirestore(doc).advanceId: doc,
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            if (!_requestMasterDetailEnabled || constraints.maxWidth < 980) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder:
                    (context, index) => _buildAdvanceRequestCard(
                      doc: docs[index],
                      reviewer: reviewer,
                      theme: theme,
                    ),
              );
            }
            return DsMasterDetailView(
              columns: const [
                AppColumn('الموظف'),
                AppColumn('المبلغ'),
                AppColumn('تاريخ الطلب'),
                AppColumn('المرحلة'),
              ],
              rows: rows,
              detailBuilder: (row) {
                final doc = advanceById[row.id];
                if (doc == null) return const SizedBox.shrink();
                return _buildAdvanceRequestCard(
                  doc: doc,
                  reviewer: reviewer,
                  theme: theme,
                );
              },
              emptyDetailLabel:
                  'اختر طلب سلفة من الجدول لعرض التفاصيل والموافقة',
            );
          },
        );
      },
    );
  }

  Widget _buildAdvanceRequestCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
    final advance = AdvanceModel.fromFirestore(doc);
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
              style: theme.textTheme.titleMedium!.copyWith(color: Colors.white),
            ),
            _buildRequestDateLine(
              label: 'تاريخ تقديم الطلب',
              date: advance.submittedAt,
            ),
            if (advance.reason != null && advance.reason!.isNotEmpty)
              Text(
                'السبب: ${advance.reason}',
                style: const TextStyle(color: ZaWolfColors.textSecondary),
              ),
            const SizedBox(height: 16),
            if (_canActOnApproval(doc.data(), reviewer))
              _buildApprovalActions(
                disabled: _isRequestBusy(advance.advanceId),
                onDelete:
                    () => _deleteRequestDocument(
                      collection: 'advances',
                      docId: advance.advanceId,
                      requestTitle: 'طلب السلفة',
                    ),
                onApprove:
                    () => _confirmAndRun(
                      requestId: advance.advanceId,
                      title: 'اعتماد طلب السلفة',
                      confirmLabel: 'اعتماد',
                      run:
                          () => _advanceService.approveAdvanceRequest(
                            advanceId: advance.advanceId,
                            reviewer: reviewer,
                          ),
                    ),
                onReject:
                    () => _showRejectionDialog(
                      requestId: advance.advanceId,
                      type: 'advance',
                    ),
                onModify:
                    () => _showModificationDialog(
                      requestId: advance.advanceId,
                      collection: 'advances',
                      userId: advance.userId,
                      requestTitle: 'طلب السلفة',
                    ),
              ),
            _buildArchiveRequestAction(
              reviewer: reviewer,
              collection: 'advances',
              requestId: advance.advanceId,
            ),
            const SizedBox(height: 8),
            Text(
              'المرحلة الحالية: ${_advanceStageLabel(doc.data())}',
              style: const TextStyle(color: ZaWolfColors.primaryCyan),
            ),
          ],
        ),
      ),
    );
  }

  String _advanceStageLabel(Map<String, dynamic> data) {
    if (data['status'] == 'pending_hr') return 'مراجعة HR';
    switch (data['advanceRouteStage']) {
      case 'ceo':
        return 'موافقة الرئيس التنفيذي';
      case 'accounting':
        return 'اعتماد الحسابات النهائي';
      default:
        return 'موافقة المدير';
    }
  }

  Widget _buildComplaintsTab(UserModel reviewer, ThemeData theme) {
    final canReview = EmployeeRole.isHr(reviewer.role);
    if (!canReview) {
      return _buildEmptyState('الشكاوى تظهر لمسؤول HR والإدارة العليا فقط');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream(
        'complaints|new|${reviewer.uid}',
        _db.collection('complaints').where('status', isEqualTo: 'new'),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل الشكاوى');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل الشكاوى...');
        }

        final docs = _newestFirst(
          (snapshot.data?.docs ?? []).where((doc) {
            if (_searchQuery.isEmpty) return true;
            final data = doc.data();
            return _matchesSearch([
              data['employeeName'],
              data['employeeId'],
              data['department'],
              data['title'],
              data['body'],
            ]);
          }),
        );
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
                            SnackBar(
                              content: Text(
                                'فشل تحديث الشكوى: ${userFacingError(e)}',
                              ),
                            ),
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

  /// A single confirmed-deductions register.  Previously this screen showed
  /// only approved attendance deductions, while approved deductible
  /// permissions and approved manual deductions were hidden in other tabs.
  /// That made a valid confirmed salary deduction appear to be missing.
  // Retained temporarily as the rollback seam for the unified visibility tab.
  // ignore: unused_element
  Widget _buildConfirmedDeductionsTab(UserModel reviewer, ThemeData theme) {
    final attendanceStream = _cachedStream(
      'attendance|salary-deduction|${reviewer.uid}|confirmed',
      _db
          .collection('attendance')
          .where('salaryDeductionApprovalStatus', isEqualTo: 'approved')
          .limit(300),
    );
    final permissionStream = _cachedStream(
      'permissions|salary-deduction|${reviewer.uid}|confirmed',
      _db
          .collection('permissions')
          .where('status', isEqualTo: 'approved')
          .limit(300),
    );
    final manualStream = _cachedStream(
      'manual-deductions|${reviewer.uid}|confirmed',
      _db
          .collection('manual_deductions')
          .where('status', isEqualTo: 'approved')
          .limit(300),
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: attendanceStream,
      builder:
          (
            context,
            attendanceSnapshot,
          ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: permissionStream,
            builder:
                (
                  context,
                  permissionSnapshot,
                ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: manualStream,
                  builder: (context, manualSnapshot) {
                    if (attendanceSnapshot.hasError ||
                        permissionSnapshot.hasError ||
                        manualSnapshot.hasError) {
                      return _buildStreamError('تعذر تحميل الخصومات المعتمدة');
                    }
                    if (attendanceSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        permissionSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        manualSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return _buildLoadingState(
                        'تحميل سجل الخصومات المعتمدة...',
                      );
                    }
                    final attendance =
                        (attendanceSnapshot.data?.docs ?? const [])
                            .map(AttendanceModel.fromFirestore)
                            .toList();
                    final permissions =
                        (permissionSnapshot.data?.docs ?? const [])
                            .map(PermissionModel.fromFirestore)
                            .where(
                              (item) =>
                                  item.isDeductible &&
                                  item.salaryDeductionFraction > 0 &&
                                  item.salaryDeductionApprovalStatus ==
                                      'approved',
                            )
                            .toList();
                    final manual =
                        (manualSnapshot.data?.docs ?? const [])
                            .map(ManualDeductionModel.fromFirestore)
                            .toList();
                    final items =
                        <_ConfirmedDeductionItem>[
                            ...attendance.map(
                              (item) => _ConfirmedDeductionItem(
                                id: item.attendanceId,
                                source: 'الحضور والانصراف',
                                employeeName: item.employeeName,
                                employeeId: item.employeeId,
                                department: item.locationName,
                                date: item.date,
                                reason: AttendancePolicy.arabicDeductionLabel(
                                  item.salaryDeductionCode,
                                  fallback: item.salaryDeductionLabel,
                                ),
                                fraction: item.salaryDeductionFraction,
                                amount: item.salaryDeductionAmount,
                                currency: item.salaryCurrency,
                                attendance: item,
                              ),
                            ),
                            ...permissions.map(
                              (item) => _ConfirmedDeductionItem(
                                id: item.permissionId,
                                source: 'إذن استقطاعي',
                                employeeName: item.employeeName,
                                employeeId: item.employeeId,
                                department: item.department,
                                date: item.requestDate,
                                reason: AttendancePolicy.arabicDeductionLabel(
                                  item.salaryDeductionCode,
                                  fallback: item.salaryDeductionLabel,
                                ),
                                fraction: item.salaryDeductionFraction,
                                amount: item.salaryDeductionAmount,
                                currency: item.salaryCurrency,
                              ),
                            ),
                            ...manual.map(
                              (item) => _ConfirmedDeductionItem(
                                id: item.id,
                                source: 'خصم إداري',
                                employeeName: item.employeeName,
                                employeeId: item.employeeId,
                                department: item.department,
                                date: item.dateKey,
                                reason: item.reason,
                                fraction: item.dayFraction,
                                amount: 0,
                                currency: '',
                              ),
                            ),
                          ]
                          ..removeWhere(
                            (item) =>
                                !_matchesSearch([
                                  item.employeeName,
                                  item.employeeId,
                                  item.department,
                                  item.source,
                                  item.reason,
                                ]),
                          )
                          ..sort((a, b) => b.date.compareTo(a.date));
                    if (items.isEmpty) {
                      return _buildEmptyState(
                        'لا توجد خصومات راتب معتمدة مطابقة للبحث',
                      );
                    }
                    final rows = <AppRow>[
                      for (final item in items)
                        AppRow(
                          id: item.id,
                          title: item.employeeName,
                          leading: Icons.receipt_long_outlined,
                          accentColor: ZaWolfColors.warning,
                          cells: [
                            item.source,
                            '${item.date} · ${item.reason}',
                            '${dsBidi(item.fraction.toStringAsFixed(2))} يوم',
                          ],
                        ),
                    ];
                    final itemById = {for (final item in items) item.id: item};

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (!_requestMasterDetailEnabled ||
                            constraints.maxWidth < 980) {
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder:
                                (context, index) =>
                                    _buildConfirmedDeductionCard(
                                      item: items[index],
                                      reviewer: reviewer,
                                      theme: theme,
                                    ),
                          );
                        }
                        return DsMasterDetailView(
                          columns: const [
                            AppColumn('الموظف'),
                            AppColumn('المصدر', width: 160),
                            AppColumn('التاريخ والسبب'),
                            AppColumn('قيمة الخصم'),
                          ],
                          rows: rows,
                          detailBuilder: (row) {
                            final item = itemById[row.id];
                            if (item == null) return const SizedBox.shrink();
                            return _buildConfirmedDeductionCard(
                              item: item,
                              reviewer: reviewer,
                              theme: theme,
                            );
                          },
                          emptyDetailLabel:
                              'اختر خصماً من الجدول لعرض التفاصيل',
                        );
                      },
                    );
                  },
                ),
          ),
    );
  }

  Widget _buildConfirmedDeductionCard({
    required _ConfirmedDeductionItem item,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
    return WolfCard(
      hasBorderGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmployeeHeader(
            item.employeeName,
            item.employeeId,
            item.department,
            theme,
          ),
          const SizedBox(height: 10),
          Text(
            item.source,
            style: const TextStyle(color: ZaWolfColors.primaryCyan),
          ),
          Text(item.reason, style: theme.textTheme.titleMedium),
          Text(
            'التاريخ: ${item.date} · قيمة الخصم: ${item.fraction.toStringAsFixed(2)} يوم',
          ),
          if (item.amount > 0)
            Text(
              'القيمة المالية: ${item.amount.toStringAsFixed(2)} ${item.currency}',
              style: const TextStyle(color: ZaWolfColors.warning),
            ),
          const SizedBox(height: 8),
          const _SalaryDeductionStatus(status: 'approved'),
          if (item.attendance != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    () => _reverseSalaryDeduction(
                      attendance: item.attendance!,
                      reviewer: reviewer,
                    ),
                icon: const Icon(Icons.undo),
                label: const Text('إلغاء خصم الحضور المعتمد'),
              ),
            ),
          ],
        ],
      ),
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
    Query<Map<String, dynamic>> deductionsQuery = _db.collection('attendance');
    if (reversalOnly) {
      deductionsQuery = deductionsQuery.where(
        'salaryDeductionApprovalStatus',
        whereIn: const ['approved', 'reversed'],
      );
    } else {
      // Keep the active HR queue separate from history. Combining approved,
      // reversed and pending records could fill the bounded page before recent
      // pending deductions (such as Ashraf's) were returned.
      deductionsQuery = deductionsQuery.where(
        'salaryDeductionApprovalStatus',
        isEqualTo: 'pending_hr',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream(
        'attendance|salary-deduction|${reviewer.uid}|reversal:$reversalOnly',
        deductionsQuery.limit(200),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل خصومات الحضور');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل خصومات الحضور...');
        }

        final loadedItems =
            snapshot.data?.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList() ??
            [];
        final allItems =
            loadedItems.where((attendance) {
              final status = attendance.salaryDeductionApprovalStatus;
              if (reversalOnly) {
                return status == 'approved' || status == 'reversed';
              }
              final isPending = status == 'pending_hr';
              if (!isPending) return false;

              final isAbsence =
                  attendance.salaryDeductionFraction >= 1.0 ||
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
                          AttendancePolicy.arabicDeductionLabel(
                            attendance.salaryDeductionCode,
                            fallback: attendance.salaryDeductionLabel,
                          ),
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        _buildRequestDateLine(
                          label: 'يوم وتاريخ الحضور',
                          date: _parseDateKey(attendance.date),
                        ),
                        if (attendance.userId != reviewer.uid &&
                            EmployeeRole.isHr(reviewer.role))
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed:
                                  () =>
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
                        if (attendance.checkoutPolicyEnabled == false)
                          const Text(
                            'تسجيل الانصراف لا ينطبق على هذا اليوم وفق سياسة HR المسجلة.',
                            style: TextStyle(color: ZaWolfColors.textSecondary),
                            textDirection: TextDirection.rtl,
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
                            disabled: _isRequestBusy(attendance.attendanceId),
                            onApprove:
                                () => _confirmAndRun(
                                  requestId: attendance.attendanceId,
                                  title: 'اعتماد الخصم',
                                  confirmLabel: 'اعتماد',
                                  run:
                                      () => _attendanceService
                                          .approveSalaryDeduction(
                                            attendance.attendanceId,
                                            reviewer.uid,
                                          ),
                                ),
                            onReject:
                                () => _confirmAndRun(
                                  requestId: attendance.attendanceId,
                                  title: 'رفض الخصم',
                                  confirmLabel: 'رفض',
                                  destructive: true,
                                  run:
                                      () => _attendanceService
                                          .rejectSalaryDeduction(
                                            attendance.attendanceId,
                                            reviewer.uid,
                                          ),
                                ),
                          )
                        else if (reversalOnly &&
                            attendance.salaryDeductionApprovalStatus ==
                                'approved')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => _reverseSalaryDeduction(
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
            content: Text('فشل المزامنة: ${userFacingError(e)}'),
          ),
        );
      }
    }
  }

  Widget _buildAttendanceCorrectionsTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedDerivedStream(
        'attendance-corrections|${reviewer.uid}',
        AttendanceCorrectionRequestService().pendingForHr,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('تعذر تحميل طلبات تصحيح الحضور');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('تحميل طلبات تصحيح الحضور...');
        }
        final docs = [...?snapshot.data?.docs];
        if (_searchQuery.isNotEmpty) {
          docs.removeWhere((doc) {
            final data = doc.data();
            return !_matchesSearch([
              data['employeeName'],
              data['employeeId'],
              data['department'],
              data['attendanceDate'],
              data['reason'],
            ]);
          });
        }
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
        final correctionById = {for (final doc in docs) doc.id: doc};
        final rows = <AppRow>[
          for (final doc in docs)
            () {
              final data = doc.data();
              final requested = data['requestedCheckInTime'] as Timestamp?;
              return AppRow(
                id: doc.id,
                title: data['employeeName'] as String? ?? 'موظف',
                leading: Icons.edit_calendar_outlined,
                cells: [
                  data['attendanceDate'] as String? ?? '',
                  requested == null
                      ? '--:--'
                      : DateFormat('hh:mm a', 'ar').format(requested.toDate()),
                  'بانتظار HR',
                ],
              );
            }(),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (!_requestMasterDetailEnabled || constraints.maxWidth < 980) {
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder:
                    (context, index) => _buildCorrectionRequestCard(
                      doc: docs[index],
                      reviewer: reviewer,
                      theme: theme,
                    ),
              );
            }
            return DsMasterDetailView(
              columns: const [
                AppColumn('الموظف'),
                AppColumn('يوم الحضور'),
                AppColumn('الوقت المطلوب', width: 140),
                AppColumn('المرحلة'),
              ],
              rows: rows,
              detailBuilder: (row) {
                final doc = correctionById[row.id];
                if (doc == null) return const SizedBox.shrink();
                return _buildCorrectionRequestCard(
                  doc: doc,
                  reviewer: reviewer,
                  theme: theme,
                );
              },
              emptyDetailLabel:
                  'اختر طلب تصحيح من الجدول لعرض التفاصيل والموافقة',
            );
          },
        );
      },
    );
  }

  Widget _buildCorrectionRequestCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
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
            disabled: _isRequestBusy(doc.id),
            onDelete:
                () => _deleteRequestDocument(
                  collection: 'attendanceCorrectionRequests',
                  docId: doc.id,
                  requestTitle: 'طلب تصحيح الحضور',
                ),
            onApprove:
                () => _reviewAttendanceCorrection(
                  requestId: doc.id,
                  reviewer: reviewer,
                  approve: true,
                ),
            onReject:
                () => _reviewAttendanceCorrection(
                  requestId: doc.id,
                  reviewer: reviewer,
                  approve: false,
                ),
          ),
          _buildArchiveRequestAction(
            reviewer: reviewer,
            collection: 'attendanceCorrectionRequests',
            requestId: doc.id,
          ),
        ],
      ),
    );
  }

  Future<void> _reviewAttendanceCorrection({
    required String requestId,
    required UserModel reviewer,
    required bool approve,
  }) async {
    final commentController = TextEditingController();
    final confirmed = await showConfirmationSheet(
      context,
      title: approve ? 'اعتماد تصحيح الحضور' : 'رفض تصحيح الحضور',
      message:
          approve
              ? 'سيتم تصحيح الوقت وإعادة حساب الخصم.'
              : 'سيتم رفض طلب التصحيح وإشعار الموظف بالسبب.',
      confirmLabel: approve ? 'اعتماد' : 'رفض',
      destructive: !approve,
      commentHint:
          approve ? 'ملاحظة اختيارية للموظف' : 'اكتب سبب الرفض للموظف (مطلوب)',
      requireComment: !approve,
      commentController: commentController,
    );
    if (!confirmed) {
      commentController.dispose();
      return;
    }
    await _withRequestGuard(requestId, () async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر مراجعة الطلب: ${userFacingError(error)}'),
            ),
          );
        }
      }
    });
    commentController.dispose();
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
      builder:
          (dialogContext) => AlertDialog(
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
    final correctedTime = DateTime(
      day.year,
      day.month,
      day.day,
      picked.hour,
      picked.minute,
    );
    // The correction feature is intentionally only for an earlier arrival
    // (for example: the employee arrived before the phone could register).
    // Validate it before Firestore so HR receives a useful explanation rather
    // than a generic save/permission error.
    if (correctedTime.isAfter(initial)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'وقت التصحيح يجب أن يكون قبل أو مساوياً لوقت الوصول المسجل.',
          ),
        ),
      );
      reasonController.dispose();
      return;
    }
    try {
      await _attendanceService.correctCheckInTime(
        attendanceId: attendance.attendanceId,
        reviewerId: reviewer.uid,
        correctedTime: correctedTime,
        reason: reasonController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصحيح الوقت وإعادة حساب الخصم.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تعديل الوقت: ${userFacingError(error)}'),
          ),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  List<AttendanceModel> _filterSalaryDeductions(List<AttendanceModel> items) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return items.where((item) {
      if (!_matchesSearch([
        item.employeeName,
        item.employeeId,
        item.locationName,
        item.salaryDeductionLabel,
        item.salaryDeductionCode,
        item.date,
      ])) {
        return false;
      }
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
    final pendingItems =
        visibleItems
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
                  onPressed:
                      pendingItems.isEmpty
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
                  onPressed:
                      pendingItems.isEmpty
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
    final pendingItems =
        items
            .where((item) => item.salaryDeductionApprovalStatus == 'pending_hr')
            .toList();
    if (pendingItems.isEmpty) return;
    final confirmed = await showConfirmationSheet(
      context,
      title: approve ? 'اعتماد الخصومات المعروضة؟' : 'رفض الخصومات المعروضة؟',
      message:
          'سيتم تطبيق الإجراء على ${pendingItems.length} خصم معلق حسب الفلتر الحالي.',
      confirmLabel: approve ? 'اعتماد' : 'رفض',
      destructive: !approve,
    );
    if (!confirmed || !mounted) return;

    await _withRequestGuard('salary-deductions-bulk', () async {
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
    });
  }

  Future<void> _reverseSalaryDeduction({
    required AttendanceModel attendance,
    required UserModel reviewer,
  }) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text(
                    'إلغاء خصم معتمد',
                    textDirection: TextDirection.rtl,
                  ),
                  content: Form(
                    key: formKey,
                    child: TextFormField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 4,
                      autofocus: true,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'سبب الإلغاء',
                        hintText: 'اكتب سبباً واضحاً من 5 أحرف على الأقل',
                      ),
                      validator:
                          (value) =>
                              (value ?? '').trim().length < 5
                                  ? 'سبب الإلغاء يجب أن يكون 5 أحرف على الأقل.'
                                  : null,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                      child: const Text('تراجع'),
                    ),
                    FilledButton(
                      onPressed:
                          saving
                              ? null
                              : () {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                setDialogState(() => saving = true);
                                Navigator.pop(dialogContext, true);
                              },
                      child:
                          saving
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('إلغاء الخصم'),
                    ),
                  ],
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إلغاء الخصم: ${userFacingError(error)}')),
      );
    }
  }

  Widget _buildSecurityReviewsTab(UserModel reviewer, ThemeData theme) {
    if (reviewer.role == EmployeeRole.manager) {
      return _buildEmptyState('مراجعة أمان الحضور من HR فقط');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream(
        'attendance|checkin-security|${reviewer.uid}',
        _db
            .collection('attendance')
            .where('securityReviewStatus', isEqualTo: 'pending_hr'),
      ),
      builder: (context, checkInSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cachedStream(
            'attendance|checkout-security|${reviewer.uid}',
            _db
                .collection('attendance')
                .where('checkoutSecurityReviewStatus', isEqualTo: 'pending_hr'),
          ),
          builder: (context, checkoutSnapshot) {
            if (checkInSnapshot.hasError || checkoutSnapshot.hasError) {
              return _buildStreamError('تعذر تحميل مراجعات أمان الحضور');
            }
            final waiting =
                checkInSnapshot.connectionState == ConnectionState.waiting ||
                checkoutSnapshot.connectionState == ConnectionState.waiting;
            if (waiting) {
              return _buildLoadingState('تحميل مراجعات أمان الحضور...');
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

            if (_searchQuery.isNotEmpty) {
              items.removeWhere(
                (item) =>
                    !_matchesSearch([
                      item.attendance.employeeName,
                      item.attendance.employeeId,
                      item.attendance.locationName,
                      item.attendance.date,
                      item.attendance.locationRiskMessage,
                      item.attendance.checkoutLocationRiskMessage,
                    ]),
              );
            }

            if (items.isEmpty) {
              return _buildEmptyState('لا توجد مراجعات أمنية معلقة');
            }

            final reviewById = {for (final item in items) item.docId: item};
            final rows = <AppRow>[
              for (final item in items)
                AppRow(
                  id: item.docId,
                  title: item.attendance.employeeName,
                  leading: Icons.security,
                  accentColor: ZaWolfColors.warning,
                  cells: [
                    item.checkout ? 'مراجعة انصراف' : 'مراجعة حضور',
                    item.attendance.date,
                    item.attendance.locationName,
                  ],
                ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                if (!_requestMasterDetailEnabled ||
                    constraints.maxWidth < 980) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder:
                        (context, index) => _buildSecurityReviewCard(
                          item: items[index],
                          reviewer: reviewer,
                          theme: theme,
                        ),
                  );
                }
                return DsMasterDetailView(
                  columns: const [
                    AppColumn('الموظف'),
                    AppColumn('النوع', width: 140),
                    AppColumn('التاريخ', width: 130),
                    AppColumn('الفرع'),
                  ],
                  rows: rows,
                  detailBuilder: (row) {
                    final item = reviewById[row.id];
                    if (item == null) return const SizedBox.shrink();
                    return _buildSecurityReviewCard(
                      item: item,
                      reviewer: reviewer,
                      theme: theme,
                    );
                  },
                  emptyDetailLabel:
                      'اختر مراجعة أمنية من الجدول لعرض التفاصيل والموافقة',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSecurityReviewCard({
    required _SecurityReviewItem item,
    required UserModel reviewer,
    required ThemeData theme,
  }) {
    final attendance = item.attendance;
    final reasons =
        item.checkout
            ? attendance.checkoutLocationRiskReasons
            : attendance.locationRiskReasons;
    final riskMessage =
        item.checkout
            ? (attendance.checkoutLocationRiskMessage ??
                'مراجعة انصراف: تحقق من مؤشرات الموقع المسجلة')
            : (attendance.locationRiskMessage ?? 'مؤشرات موقع غير معتادة');
    final accuracy =
        item.checkout
            ? attendance.checkoutLocationAccuracyMeters
            : attendance.locationAccuracyMeters;
    final distance =
        item.checkout
            ? attendance.checkoutLocationDistanceMeters
            : attendance.locationDistanceMeters;
    final radius =
        item.checkout
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
                    color: ZaWolfColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ZaWolfColors.warning.withValues(alpha: 0.35),
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
                const Icon(Icons.security, color: ZaWolfColors.primaryCyan),
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
              date:
                  item.checkout
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
                  children:
                      reasons
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
              disabled: _isRequestBusy(item.docId),
              onApprove:
                  () => _confirmAndRun(
                    requestId: item.docId,
                    title: 'اعتماد المراجعة الأمنية',
                    confirmLabel: 'اعتماد',
                    run:
                        () => _attendanceService.approveSecurityReview(
                          item.docId,
                          reviewer.uid,
                          checkout: item.checkout,
                        ),
                  ),
              onReject:
                  () => _confirmAndRun(
                    requestId: item.docId,
                    title: 'رفض المراجعة الأمنية',
                    confirmLabel: 'رفض',
                    destructive: true,
                    run:
                        () => _attendanceService.rejectSecurityReview(
                          item.docId,
                          reviewer.uid,
                          checkout: item.checkout,
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader(
    String name,
    String code,
    String dept,
    ThemeData theme,
  ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ZaWolfColors.surface02,
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1) : 'م',
                  style: const TextStyle(color: ZaWolfColors.primaryCyan),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text('كود: $code', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface02,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZaWolfColors.surface03),
            ),
            child: Text(
              'القسم: $dept',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZaWolfColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequestDocument({
    required String collection,
    required String docId,
    required String requestTitle,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('حذف $requestTitle نهائياً'),
              content: Text(
                'هل أنت متأكد من حذف هذا الطلب ($requestTitle) نهائياً من النظام؟\nلن يمكن استعادة الطلب بعد الحذف.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('حذف نهائي'),
                ),
              ],
            ),
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .delete();
        if (mounted) setState(() {});
        messenger.showSnackBar(
          SnackBar(content: Text('تم حذف $requestTitle بنجاح.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تعذر حذف الطلب. تحقق من الصلاحيات والاتصال.'),
          ),
        );
      }
    }
  }

  Widget _buildApprovalActions({
    required VoidCallback onApprove,
    required VoidCallback onReject,
    VoidCallback? onModify,
    VoidCallback? onDelete,
    bool disabled = false,
  }) {
    return Row(
      children: [
        if (onDelete != null) ...[
          Expanded(
            child: WolfButton(
              onPressed: disabled ? null : onDelete,
              text: 'حذف الطلب',
              secondaryText: 'DELETE',
              variant: WolfButtonVariant.danger,
              height: 48,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: WolfButton(
            onPressed: disabled ? null : onReject,
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
              onPressed: disabled ? null : onModify,
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
            onPressed: disabled ? null : onApprove,
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
              'تحقق من الاتصال ثم اضغط إعادة المحاولة. لن تختفي الطلبات بصمت عند حدوث خطأ.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                _streamCache.clear();
                _derivedStreamCache.clear();
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String text) {
    return _RequestLoadingState(
      label: text,
      onRetry: () {
        _streamCache.clear();
        _derivedStreamCache.clear();
        if (mounted) setState(() {});
      },
    );
  }

  String _translateLeaveType(String type) {
    if (type == 'wfh') return 'عمل من المنزل';
    return LeaveTypePolicy.arabicLabel(type);
  }

  bool _matchesSearch(Iterable<Object?> values) {
    if (_searchQuery.isEmpty) return true;
    return values.any(
      (value) => (value ?? '').toString().toLowerCase().contains(_searchQuery),
    );
  }
}

class _KeepAliveRequestTab extends StatefulWidget {
  const _KeepAliveRequestTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveRequestTab> createState() => _KeepAliveRequestTabState();
}

class _RequestLoadingState extends StatefulWidget {
  const _RequestLoadingState({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  State<_RequestLoadingState> createState() => _RequestLoadingStateState();
}

class _RequestLoadingStateState extends State<_RequestLoadingState> {
  Timer? _timer;
  var _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_disabled_outlined,
                color: ZaWolfColors.warning,
                size: 52,
              ),
              const SizedBox(height: 12),
              const Text(
                'استغرق تحميل الطلبات وقتاً أطول من المتوقع.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          const SizedBox(height: 12),
          Text(
            widget.label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: ZaWolfColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _KeepAliveRequestTabState extends State<_KeepAliveRequestTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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

class _ConfirmedDeductionItem {
  final String id;
  final String source;
  final String employeeName;
  final String employeeId;
  final String department;
  final String date;
  final String reason;
  final double fraction;
  final double amount;
  final String currency;
  final AttendanceModel? attendance;

  const _ConfirmedDeductionItem({
    required this.id,
    required this.source,
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.date,
    required this.reason,
    required this.fraction,
    required this.amount,
    required this.currency,
    this.attendance,
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
      alignment: AlignmentDirectional.centerStart,
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
