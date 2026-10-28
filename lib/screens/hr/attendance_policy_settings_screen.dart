import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/attendance_policy.dart';
import '../../models/chat_policy.dart';
import '../../models/request_approval_policy.dart';
import '../../services/attendance_policy_service.dart';
import '../../services/app_security_policy_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_policy_service.dart';
import '../../services/request_approval_policy_service.dart';
import '../../theme/theme.dart';
import '../../utils/user_facing_error.dart';
import '../../features/checkout_policy/data/checkout_policy_repository_impl.dart';
import '../../features/checkout_policy/domain/entities/checkout_policy.dart';
import '../../features/checkout_policy/presentation/checkout_policy_controller.dart';
import '../../features/remote_work/domain/entities/remote_policy.dart';
import '../../features/remote_work/presentation/cubit/remote_policy_editor_cubit.dart';
import '../../features/remote_work/presentation/cubit/remote_policy_publication_cubit.dart';
import '../../features/remote_work/presentation/widgets/remote_policy_effective_time_field.dart';
import '../../features/remote_work/presentation/widgets/remote_policy_review_actions.dart';
import '../../features/remote_work/data/remote_work_repository_impl.dart';
import '../../features/remote_work/domain/entities/remote_work_models.dart';
import '../../models/user_model.dart';
import 'widgets/assign_remote_days_dialog.dart';

class AttendancePolicySettingsScreen extends StatefulWidget {
  const AttendancePolicySettingsScreen({super.key});

  @override
  State<AttendancePolicySettingsScreen> createState() =>
      _AttendancePolicySettingsScreenState();
}

class _AttendancePolicySettingsScreenState
    extends State<AttendancePolicySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _checkInOpen = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _latestCheckout = TextEditingController();
  final _reminderLead = TextEditingController();
  final _lateWarning = TextEditingController();
  final _finalWarningLead = TextEditingController();
  final _grace = TextEditingController();
  final _quarterUntil = TextEditingController();
  final _halfUntil = TextEditingController();
  final _minimumAndroidBuild = TextEditingController();
  final _minimumIosBuild = TextEditingController();
  final _androidStoreUrl = TextEditingController();
  final _iosStoreUrl = TextEditingController();
  final _updateMessage = TextEditingController();
  final _ceoLeaveThreshold = TextEditingController();
  final _leaveNoticeDays = TextEditingController();
  final _probationDays = TextEditingController();
  final _workDaysPerMonth = TextEditingController();
  final _advanceMaxSalaryPercentage = TextEditingController();
  bool _requireCeoApprovalForRemote = true;
  bool _requireCeoApprovalForAdvance = true;
  bool _requireHrAfterManagerApproval = false;
  final RequestApprovalPolicyService _requestApprovalPolicyService =
      RequestApprovalPolicyService();
  final ChatPolicyService _chatPolicyService = ChatPolicyService();
  ChatPolicyConfig _chatPolicy = const ChatPolicyConfig();
  bool _loading = true;
  bool _saving = false;
  AttendancePolicyConfig _loadedPolicy = const AttendancePolicyConfig();
  Map<String, dynamic> _remoteWorkPolicy = {};
  DateTime _policyEffectiveFrom = DateTime.now();
  String _previewEmployeeId = '';
  String _approvalReason = '';
  int _remoteDraftVersion = 0;
  String? _savedPolicyFingerprint;
  String _attendanceVerificationMode = 'location_only';
  bool _forceUpdateEnabled = false;
  bool _enforceSecureAttendance = false;
  bool _blockAndroidDeveloperOptions = true;
  int _currentBuild = 0;
  final CheckoutPolicyController _checkoutPolicyController =
      CheckoutPolicyController(CheckoutPolicyRepositoryImpl());
  CheckoutPolicySnapshot? _checkoutPolicy;
  bool _savingCheckoutPolicy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _checkInOpen,
      _start,
      _end,
      _latestCheckout,
      _reminderLead,
      _lateWarning,
      _finalWarningLead,
      _grace,
      _quarterUntil,
      _halfUntil,
      _minimumAndroidBuild,
      _minimumIosBuild,
      _androidStoreUrl,
      _iosStoreUrl,
      _updateMessage,
      _ceoLeaveThreshold,
      _leaveNoticeDays,
      _probationDays,
      _workDaysPerMonth,
      _advanceMaxSalaryPercentage,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final editorCubit = context.read<RemotePolicyEditorCubit>();
    final editorLoad = editorCubit.load();
    final results = await Future.wait([
      AttendancePolicyService().getPolicyConfig(),
      AppSecurityPolicyService.instance.loadStatus(),
      _checkoutPolicyController.load(),
      _requestApprovalPolicyService.getPolicy(),
      _chatPolicyService.loadPolicy(),
    ]);
    await editorLoad;
    final policy = results[0] as AttendancePolicyConfig;
    final editorState = editorCubit.state;
    final draftAggregate = editorState is RemotePolicyEditorReady
        ? editorState.aggregate
        : null;
    final displayedPolicy = editorState is RemotePolicyEditorReady &&
            editorState.draftVersion > 0
        ? AttendancePolicyConfig.fromMap(draftAggregate!.attendancePolicy)
        : policy;
    final securityStatus = results[1] as AppSecurityStatus;
    final checkoutPolicy = results[2] as CheckoutPolicySnapshot;
    final reqPolicy = results[3] as RequestApprovalPolicy;
    final chatPolicy = results[4] as ChatPolicyConfig;
    if (!mounted) return;
    if (editorState is RemotePolicyEditorReady) {
      context.read<RemotePolicyPublicationCubit>().selectDraft(
        draftId: editorState.draftId, version: editorState.draftVersion,
      );
      if (editorState.effectiveFrom != null) {
        _policyEffectiveFrom = editorState.effectiveFrom!.toLocal();
      }
    }
    _checkInOpen.text = displayedPolicy.checkInOpenTime;
    _start.text = displayedPolicy.defaultStartTime;
    _end.text = displayedPolicy.defaultEndTime;
    _latestCheckout.text = displayedPolicy.latestCheckoutTime;
    _reminderLead.text = displayedPolicy.checkInReminderLeadMinutes.toString();
    _lateWarning.text = displayedPolicy.checkInLateWarningMinutes.toString();
    _finalWarningLead.text = displayedPolicy.checkInFinalWarningLeadMinutes.toString();
    _grace.text = displayedPolicy.graceMinutes.toString();
    _quarterUntil.text = displayedPolicy.quarterDayUntilMinutes.toString();
    _halfUntil.text = displayedPolicy.halfDayUntilMinutes.toString();
    _loadedPolicy = displayedPolicy;
    _remoteWorkPolicy = _copyPolicyMap(
      draftAggregate?.remoteWorkPolicy ?? policy.remoteWorkPolicy,
    );
    _remoteDraftVersion = editorState is RemotePolicyEditorReady
        ? editorState.draftVersion
        : 0;
    _attendanceVerificationMode = displayedPolicy.attendanceVerificationMode;
    _forceUpdateEnabled = securityStatus.policy.forceUpdateEnabled;
    _enforceSecureAttendance =
        securityStatus.policy.minimumAttendanceProtocolVersion >=
        AppSecurityPolicy.currentAttendanceProtocolVersion;
    _blockAndroidDeveloperOptions =
        securityStatus.policy.blockAndroidDeveloperOptions;
    _minimumAndroidBuild.text = securityStatus.policy.minimumAndroidBuild
        .toString();
    _minimumIosBuild.text = securityStatus.policy.minimumIosBuild.toString();
    _androidStoreUrl.text = securityStatus.policy.androidStoreUrl;
    _iosStoreUrl.text = securityStatus.policy.iosStoreUrl;
    _updateMessage.text = securityStatus.policy.messageAr;
    _currentBuild = securityStatus.currentBuild;
    _checkoutPolicy = checkoutPolicy;

    _ceoLeaveThreshold.text = reqPolicy.ceoLeaveApprovalThresholdDays.toString();
    _leaveNoticeDays.text = reqPolicy.leaveNoticeDaysNormal.toString();
    _probationDays.text = reqPolicy.probationPeriodDays.toString();
    _workDaysPerMonth.text = reqPolicy.payrollWorkDaysPerMonth.toString();
    _advanceMaxSalaryPercentage.text = reqPolicy.advanceMaxSalaryPercentage.toStringAsFixed(0);
    _requireCeoApprovalForRemote = reqPolicy.requireCeoApprovalForRemote;
    _requireCeoApprovalForAdvance = reqPolicy.requireCeoApprovalForAdvance;
    _requireHrAfterManagerApproval = reqPolicy.requireHrAfterManagerApproval;
    _chatPolicy = chatPolicy;

    _savedPolicyFingerprint = _policyFingerprint();
    setState(() => _loading = false);
  }

  Future<void> _confirmCheckoutPolicyChange(bool enabled) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(enabled ? 'تفعيل تسجيل الانصراف' : 'إيقاف تسجيل الانصراف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enabled
                  ? 'سيظهر تسجيل الانصراف للعمليات الجديدة فقط، دون تعديل السجلات السابقة.'
                  : 'سيختفي تسجيل الانصراف وتتوقف الخصومات الجديدة المرتبطة به. تسجيل الحضور وطلب إذن المغادرة المبكرة يظلان متاحين.',
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 500,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'سبب التغيير (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _savingCheckoutPolicy = true);
    try {
      final value = await _checkoutPolicyController.change(
        enabled: enabled,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _checkoutPolicy = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'تم تفعيل تسجيل الانصراف.' : 'تم إيقاف تسجيل الانصراف.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('تعذر تغيير حالة الانصراف. حدّث الصفحة ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _savingCheckoutPolicy = false);
    }
  }

  Future<void> _editAutomaticCheckoutSettings() async {
    final snapshot = _checkoutPolicy;
    if (snapshot?.canManage != true || _savingCheckoutPolicy) return;
    final policy = snapshot!.policy;
    final graceController = TextEditingController(
      text: policy.autoCheckoutReturnGraceMinutes.toString(),
    );
    final breakStartController = TextEditingController(
      text: policy.companyBreakStartTime,
    );
    final breakEndController = TextEditingController(
      text: policy.companyBreakEndTime,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ضبط الانصراف التلقائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'عند خروج الموظف من الموقع ينتظر النظام عودته خلال المهلة. لا ينفذ الانصراف أثناء إذن مغادرة معتمد أو استراحة الشركة.',
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: graceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مهلة العودة بالدقائق (1–180)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: breakStartController,
              decoration: const InputDecoration(
                labelText: 'بداية استراحة الشركة (HH:mm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: breakEndController,
              decoration: const InputDecoration(
                labelText: 'نهاية استراحة الشركة (HH:mm)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final grace = int.tryParse(graceController.text.trim());
    final breakStart = breakStartController.text.trim();
    final breakEnd = breakEndController.text.trim();
    graceController.dispose();
    breakStartController.dispose();
    breakEndController.dispose();
    if (saved != true || !mounted) return;
    if (grace == null ||
        grace < 1 ||
        grace > 180 ||
        !_validTime(breakStart) ||
        !_validTime(breakEnd) ||
        breakStart.compareTo(breakEnd) >= 0) {
      _showError(
        'أدخل مهلة من 1 إلى 180 دقيقة ووقت استراحة صحيحاً من البداية إلى النهاية.',
      );
      return;
    }
    setState(() => _savingCheckoutPolicy = true);
    try {
      final value = await _checkoutPolicyController.change(
        enabled: policy.enabled,
        reason: 'تحديث إعدادات الانصراف التلقائي',
        autoCheckoutReturnGraceMinutes: grace,
        companyBreakStartTime: breakStart,
        companyBreakEndTime: breakEnd,
      );
      if (!mounted) return;
      setState(() => _checkoutPolicy = value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ مهلة العودة واستراحة الشركة.')),
      );
    } catch (_) {
      if (mounted) {
        _showError(
          'تعذر حفظ إعدادات الانصراف التلقائي. حدّث الصفحة ثم أعد المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingCheckoutPolicy = false);
    }
  }

  Widget _buildCheckoutPolicyCard(ThemeData theme) {
    final snapshot = _checkoutPolicy;
    final enabled = snapshot?.policy.enabled ?? false;
    final changedBy = snapshot?.policy.changedByUserId;
    final auditLine = changedBy == null
        ? ''
        : '\nسجل المراجعة: آخر تغيير معتمد بواسطة $changedBy';
    return WolfCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: snapshot?.canManage == true && !_savingCheckoutPolicy
                ? _confirmCheckoutPolicyChange
                : null,
            secondary: _savingCheckoutPolicy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    enabled ? Icons.logout : Icons.login,
                    color: enabled ? ZaWolfColors.warning : ZaWolfColors.primaryCyan,
                  ),
            title: const Text('تسجيل الانصراف'),
            subtitle: Text(
              enabled
                  ? 'مفعّل للعمليات الجديدة. مهلة العودة: ${snapshot?.policy.autoCheckoutReturnGraceMinutes ?? 15} دقيقة. استراحة الشركة: ${snapshot?.policy.companyBreakStartTime ?? '13:00'}–${snapshot?.policy.companyBreakEndTime ?? '14:00'}.$auditLine'
                  : 'متوقف افتراضياً. تسجيل الحضور وطلبات الإذن تظل متاحة بشكل مستقل.\nالإصدار: ${snapshot?.policy.revision ?? 0}$auditLine',
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.rtl,
            ),
          ),
          if (snapshot?.canManage == true)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _savingCheckoutPolicy
                    ? null
                    : _editAutomaticCheckoutSettings,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('ضبط مهلة العودة والاستراحة'),
              ),
            ),
        ],
      ),
    );
  }

  bool _validTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
    return match;
  }

  int _readInt(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (RemoteWorkPolicyValidation.validate(_remoteWorkPolicy).isNotEmpty) {
      _showError(
        'راجع إعدادات العمل عن بُعد: أيام الأسبوع، عدد الأيام المسموح، وأوقات ونقاط المتابعة.',
      );
      return;
    }
    final grace = _readInt(_grace);
    final quarter = _readInt(_quarterUntil);
    final half = _readInt(_halfUntil);
    if (grace < 0 || quarter < grace || half < quarter) {
      _showError('رتّب حدود التأخير: السماح ثم ربع يوم ثم نصف يوم.');
      return;
    }
    if (_forceUpdateEnabled &&
        (_readInt(_minimumAndroidBuild) <= 0 ||
            _readInt(_minimumIosBuild) <= 0 ||
            _androidStoreUrl.text.trim().isEmpty ||
            _iosStoreUrl.text.trim().isEmpty)) {
      _showError(
        'قبل تفعيل التحديث الإجباري، أدخل أقل Build ورابط المتجر لأندرويد وiOS حتى لا يتم قفل المستخدمين دون وسيلة تحديث.',
      );
      return;
    }
    final savedFingerprint = _policyFingerprint();
    setState(() => _saving = true);
    final workDays = _readInt(_workDaysPerMonth);
    final policy = AttendancePolicyConfig(
      checkInOpenTime: _checkInOpen.text.trim(),
      defaultStartTime: _start.text.trim(),
      defaultEndTime: _end.text.trim(),
      latestCheckoutTime: _latestCheckout.text.trim(),
      graceMinutes: grace,
      quarterDayUntilMinutes: quarter,
      halfDayUntilMinutes: half,
      payrollWorkDaysPerMonth: workDays > 0 ? workDays : _loadedPolicy.payrollWorkDaysPerMonth,
      checkInReminderLeadMinutes: _readInt(_reminderLead),
      checkInLateWarningMinutes: _readInt(_lateWarning),
      checkInFinalWarningLeadMinutes: _readInt(_finalWarningLead),
      attendanceVerificationMode: _attendanceVerificationMode,
      remoteWorkPolicy: _copyPolicyMap(_remoteWorkPolicy),
      extensionFields: _copyPolicyMap(_loadedPolicy.extensionFields),
    );
    final securityPolicy = AppSecurityPolicy(
      forceUpdateEnabled: _forceUpdateEnabled,
      minimumAndroidBuild: _readInt(_minimumAndroidBuild),
      minimumIosBuild: _readInt(_minimumIosBuild),
      minimumAttendanceProtocolVersion: _enforceSecureAttendance
          ? AppSecurityPolicy.currentAttendanceProtocolVersion
          : 0,
      blockAndroidDeveloperOptions: _blockAndroidDeveloperOptions,
      androidStoreUrl: _androidStoreUrl.text.trim(),
      iosStoreUrl: _iosStoreUrl.text.trim(),
      messageAr: _updateMessage.text.trim(),
    );
    final reqApprovalPolicy = RequestApprovalPolicy(
      requireHrAfterManagerApproval: _requireHrAfterManagerApproval,
      ceoLeaveApprovalThresholdDays: _readInt(_ceoLeaveThreshold),
      requireCeoApprovalForRemote: _requireCeoApprovalForRemote,
      leaveNoticeDaysNormal: _readInt(_leaveNoticeDays),
      probationPeriodDays: _readInt(_probationDays),
      payrollWorkDaysPerMonth: workDays > 0 ? workDays : 26,
      requireCeoApprovalForAdvance: _requireCeoApprovalForAdvance,
      advanceMaxSalaryPercentage: double.tryParse(_advanceMaxSalaryPercentage.text.trim()) ?? 50.0,
    );
    final currentUser = context.read<AuthService>().currentUser;
    final actorId = currentUser?.uid ?? 'system';
    try {
      final editor = context.read<RemotePolicyEditorCubit>();
      editor.edit(
        RemotePolicyAggregate(
          attendancePolicy: policy.toMap(),
          remoteWorkPolicy: _copyPolicyMap(_remoteWorkPolicy),
          revision: _loadedPolicy.remoteWorkPolicy.isEmpty ? 0 : 1,
          version: _remoteDraftVersion,
        ),
      );
      final draftReceipt = await editor.saveDraft(
        effectiveFrom: _policyEffectiveFrom,
      );
      if (draftReceipt == null) {
        throw const RemotePolicyException(
          'policy_draft_failed',
          'تعذر حفظ مسودة السياسة. تحقق من صلاحية إدارة سياسة الدوام ثم أعد المحاولة.',
        );
      }
      _remoteDraftVersion = draftReceipt.version;
      _savedPolicyFingerprint = savedFingerprint;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('companies').doc('zawolf'), {
        'securityPolicy': securityPolicy.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(db.collection('publicConfig').doc('appSecurity'), {
        ...securityPolicy.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(db.collection('publicConfig').doc('requestApproval'), {
        ...reqApprovalPolicy.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();

      await _chatPolicyService.updatePolicy(
        policy: _chatPolicy,
        actorId: actorId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text(
              'تم حفظ مسودة سياسة الدوام. لن تسري أوقاتها أو قيودها حتى مراجعتها ونشرها. وحُفظت بقية الإعدادات.',
            ),
          ),
        );
      }
    } catch (error) {
      _showError(
        userFacingError(
          error,
          fallback: 'تعذر حفظ إعدادات الدوام الآن. حاول مرة أخرى.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: ZaWolfColors.error, content: Text(message)),
    );
  }

  Widget _timeField(String label, TextEditingController controller) {
    return WolfInputField(
      controller: controller,
      labelText: label,
      englishLabel: 'HH:MM',
      keyboardType: TextInputType.datetime,
      textDirection: TextDirection.ltr,
      validator: (value) =>
          _validTime(value?.trim() ?? '') ? null : 'اكتب الوقت بصيغة 09:00',
    );
  }

  Widget _minutesField(String label, TextEditingController controller) {
    return WolfInputField(
      controller: controller,
      labelText: label,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      validator: (value) {
        final minutes = int.tryParse(value?.trim() ?? '');
        return minutes != null && minutes >= 0 && minutes <= 240
            ? null
            : 'أدخل من 0 إلى 240 دقيقة';
      },
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return WolfInputField(
      controller: controller,
      labelText: label,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      validator: (value) {
        final build = int.tryParse(value?.trim() ?? '');
        return build != null && build >= 0 ? null : 'أدخل رقم Build صحيحاً';
      },
    );
  }

  Map<String, dynamic> _copyPolicyMap(Map<String, dynamic> source) =>
      source.map((key, value) => MapEntry(key, _copyPolicyValue(value)));

  dynamic _copyPolicyValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _copyPolicyValue(nested)),
      );
    }
    if (value is List) return value.map(_copyPolicyValue).toList();
    return value;
  }

  Map<String, dynamic> _remoteSection(String key) {
    final value = _remoteWorkPolicy[key];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  void _updateRemoteSection(String key, Map<String, dynamic> section) {
    setState(
      () =>
          _remoteWorkPolicy = {
            ..._remoteWorkPolicy,
            'schemaVersion': _remoteWorkPolicy['schemaVersion'] ?? 1,
            key: section,
          },
    );
  }

  RemotePolicyAggregate _remoteAggregateFromForm() {
    final attendance = _loadedPolicy.toMap();
    attendance.addAll({
      'checkInOpenTime': _checkInOpen.text.trim(),
      'defaultStartTime': _start.text.trim(),
      'defaultEndTime': _end.text.trim(),
      'latestCheckoutTime': _latestCheckout.text.trim(),
      'graceMinutes': _readInt(_grace),
      'quarterDayUntilMinutes': _readInt(_quarterUntil),
      'halfDayUntilMinutes': _readInt(_halfUntil),
      'checkInReminderLeadMinutes': _readInt(_reminderLead),
      'checkInLateWarningMinutes': _readInt(_lateWarning),
      'checkInFinalWarningLeadMinutes': _readInt(_finalWarningLead),
      'attendanceVerificationMode': _attendanceVerificationMode,
      'payrollWorkDaysPerMonth': _readInt(_workDaysPerMonth),
    });
    return RemotePolicyAggregate(
      attendancePolicy: attendance,
      remoteWorkPolicy: _copyPolicyMap(_remoteWorkPolicy),
      revision: _loadedPolicy.remoteWorkPolicy.isEmpty ? 0 : 1,
      version: _remoteDraftVersion,
    );
  }

  String _policyFingerprint() => jsonEncode({
    ..._remoteAggregateFromForm().toAggregateMap(),
    'effectiveFrom': _policyEffectiveFrom.toUtc().toIso8601String(),
  });

  Widget _buildRemotePolicyCard(ThemeData theme) {
    final enabled = _remoteWorkPolicy['enabled'] == true;
    final eligibility = _remoteSection('eligibility');
    final schedule = _remoteSection('schedule');
    final plan = _remoteSection('dailyWork');
    final devices = _remoteSection('devices');
    final review = _remoteSection('review');
    final notifications = _remoteSection('notifications');
    final privacy = _remoteSection('privacy');
    final approvals = _remoteSection('approvals');
    final channels =
        (_remoteWorkPolicy['channels'] is List
                ? (_remoteWorkPolicy['channels'] as List)
                : const <dynamic>[])
            .whereType<String>()
            .toSet();
    final approvalSteps =
        (approvals['remoteDay'] is List
                ? (approvals['remoteDay'] as List)
                : const <dynamic>[])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
    final checkpoints =
        (schedule['checkpoints'] is List
                ? (schedule['checkpoints'] as List)
                : const <dynamic>[])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
    final weekdays =
        (eligibility['allowedWeekdays'] is List
                ? (eligibility['allowedWeekdays'] as List)
                : const <dynamic>[])
            .whereType<num>()
            .map((day) => day.toInt())
            .toSet();

    Widget numberField(
      String label,
      String key,
      Map<String, dynamic> section,
      void Function(Map<String, dynamic>) update, {
      int fallback = 0,
    }) {
      return TextFormField(
        key: ValueKey('remote-$key'),
        initialValue: (section[key] ?? fallback).toString(),
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) update({...section, key: parsed});
        },
      );
    }

    Widget inheritedTime(String label, String key) {
      final value =
          schedule[key] is Map
              ? Map<String, dynamic>.from(schedule[key] as Map)
              : <String, dynamic>{'mode': 'inherit'};
      final inherited = value['mode'] != 'override';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: inherited,
            onChanged:
                _saving
                    ? null
                    : (inherit) => _updateRemoteSection('schedule', {
                      ...schedule,
                      key:
                          inherit
                              ? {'mode': 'inherit'}
                              : {
                                'mode': 'override',
                                'value': switch (key) {
                                  'startTime' => _start.text,
                                  'endTime' => _end.text,
                                  'checkInOpenTime' => _checkInOpen.text,
                                  _ => _latestCheckout.text,
                                },
                              },
                    }),
            title: Text(
              '$label — ${inherited ? 'موروث من سياسة الدوام' : 'تخصيص للعمل عن بُعد'}',
            ),
          ),
          if (!inherited)
            TextFormField(
              key: ValueKey('remote-time-$key'),
              initialValue:
                  (value['value'] as String?) ??
                  switch (key) {
                    'startTime' => _start.text,
                    'endTime' => _end.text,
                    'checkInOpenTime' => _checkInOpen.text,
                    _ => _latestCheckout.text,
                  },
              decoration: InputDecoration(
                labelText: label,
                hintText: 'HH:MM',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
              textDirection: TextDirection.ltr,
              validator:
                  (time) =>
                      _validTime(time?.trim() ?? '')
                          ? null
                          : 'اكتب الوقت بصيغة 09:00',
              onChanged:
                  (time) => _updateRemoteSection('schedule', {
                    ...schedule,
                    key: {'mode': 'override', 'value': time.trim()},
                  }),
            ),
        ],
      );
    }

    Widget inheritedMinutes(String label, String key, int sharedValue) {
      final value =
          schedule[key] is Map
              ? Map<String, dynamic>.from(schedule[key] as Map)
              : <String, dynamic>{'mode': 'inherit'};
      final inherited = value['mode'] != 'override';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: inherited,
            onChanged:
                _saving
                    ? null
                    : (inherit) => _updateRemoteSection('schedule', {
                      ...schedule,
                      key:
                          inherit
                              ? {'mode': 'inherit'}
                              : {'mode': 'override', 'value': sharedValue},
                    }),
            title: Text(
              '$label — ${inherited ? 'موروث من سياسة الدوام' : 'تخصيص للعمل عن بُعد'}',
            ),
          ),
          if (!inherited)
            TextFormField(
              key: ValueKey('remote-minutes-$key'),
              initialValue: (value['value'] ?? sharedValue).toString(),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: '$label (بالدقائق)',
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null && parsed >= 0) {
                  _updateRemoteSection('schedule', {
                    ...schedule,
                    key: {'mode': 'override', 'value': parsed},
                  });
                }
              },
            ),
        ],
      );
    }

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'العمل عن بُعد',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          const Text(
            'إعدادات العمل عن بُعد محفوظة داخل سياسة الدوام نفسها. تظل الميزة متوقفة حتى تفعيلها صراحةً.',
            textDirection: TextDirection.rtl,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged:
                _saving
                    ? null
                    : (value) => setState(() {
                      _remoteWorkPolicy = {
                        ..._starterRemotePolicy(),
                        ..._remoteWorkPolicy,
                        'schemaVersion':
                            _remoteWorkPolicy['schemaVersion'] ?? 1,
                        'enabled': value,
                      };
                    }),
            title: const Text('السماح بالعمل عن بُعد'),
          ),
          if (enabled) ...[
            const Divider(),
            Text(
              'الأهلية والأيام',
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            numberField(
              'عدد الأيام المسموح بها في الأسبوع',
              'daysPerWeek',
              eligibility,
              (value) => _updateRemoteSection('eligibility', value),
              fallback: 1,
            ),
            DropdownButtonFormField<int>(
              initialValue:
                  const {1, 2, 3, 4, 5, 6, 7}.contains(
                        (eligibility['weekStartDay'] as num?)?.toInt() ?? 6,
                      )
                      ? (eligibility['weekStartDay'] as num?)?.toInt() ?? 6
                      : 6,
              decoration: const InputDecoration(labelText: 'بداية أسبوع العمل'),
              items: const [
                DropdownMenuItem(value: 6, child: Text('السبت')),
                DropdownMenuItem(value: 7, child: Text('الأحد')),
                DropdownMenuItem(value: 1, child: Text('الإثنين')),
                DropdownMenuItem(value: 2, child: Text('الثلاثاء')),
                DropdownMenuItem(value: 3, child: Text('الأربعاء')),
                DropdownMenuItem(value: 4, child: Text('الخميس')),
                DropdownMenuItem(value: 5, child: Text('الجمعة')),
              ],
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        if (value != null) {
                          _updateRemoteSection('eligibility', {
                            ...eligibility,
                            'weekStartDay': value,
                          });
                        }
                      },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: eligibility['carryoverEnabled'] == true,
              onChanged:
                  _saving
                      ? null
                      : (value) => _updateRemoteSection('eligibility', {
                        ...eligibility,
                        'carryoverEnabled': value,
                      }),
              title: const Text('السماح بترحيل الأيام غير المستخدمة'),
            ),
            if (eligibility['carryoverEnabled'] == true)
              numberField(
                'الحد الأقصى للأيام المرحلة',
                'carryoverCap',
                eligibility,
                (value) => _updateRemoteSection('eligibility', value),
              ),
            const SizedBox(height: 8),
            Text(
              'أيام الأسبوع المسموح بها',
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodyMedium,
            ),
            Wrap(
              spacing: 4,
              children: [
                for (final entry in const [
                  (1, 'الإثنين'),
                  (2, 'الثلاثاء'),
                  (3, 'الأربعاء'),
                  (4, 'الخميس'),
                  (5, 'الجمعة'),
                  (6, 'السبت'),
                  (7, 'الأحد'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: weekdays.contains(entry.$1),
                    onSelected:
                        _saving
                            ? null
                            : (selected) {
                              final next = {...weekdays};
                              selected
                                  ? next.add(entry.$1)
                                  : next.remove(entry.$1);
                              _updateRemoteSection('eligibility', {
                                ...eligibility,
                                'allowedWeekdays': next.toList()..sort(),
                              });
                            },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => AssignRemoteDaysDialog.show(
                context,
                eligibility: eligibility,
                loadEmployees: () async {
                  final snap = await FirebaseFirestore.instance
                      .collection('users')
                      .where('isActive', isEqualTo: true)
                      .get();
                  final list =
                      snap.docs
                          .map((d) => UserModel.fromFirestore(d))
                          .toList();
                  list.sort((a, b) => a.displayName.compareTo(b.displayName));
                  return list;
                },
                onSave: (employeeId, remoteDays) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(employeeId)
                      .update({'workSchedule.remoteWorkDays': remoteDays});
                  final now = DateTime.now();
                  final todayStr =
                      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final endYearStr = '${now.year + 1}-12-31';
                  try {
                    await RemoteWorkRepositoryImpl().submitScheduleCommand(
                      RemoteCommand(
                        operationId:
                            'sched-$employeeId-${DateTime.now().millisecondsSinceEpoch}',
                        kind: 'save_schedule',
                        payload: {
                          'schedule': {
                            'employeeId': employeeId,
                            'startDate': todayStr,
                            'endDate': endYearStr,
                            'weekdays': remoteDays,
                          },
                        },
                      ),
                    );
                  } catch (_) {}
                },
              ),
              icon: const Icon(
                Icons.person_add_alt_1_outlined,
                color: ZaWolfColors.primaryCyan,
              ),
              label: const Text(
                'تعيين جدول العمل عن بُعد للموظفين',
                style: TextStyle(
                  color: ZaWolfColors.primaryCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ZaWolfColors.primaryCyan),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
            const Divider(),
            Text(
              'الساعات — تتبع أوقات الدوام ما لم تخصصها هنا',
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
            inheritedTime('بداية الدوام عن بُعد', 'startTime'),
            inheritedTime('نهاية الدوام عن بُعد', 'endTime'),
            inheritedTime('فتح تسجيل الحضور عن بُعد', 'checkInOpenTime'),
            inheritedTime('آخر موعد للانصراف عن بُعد', 'latestCheckoutTime'),
            numberField(
              'إزاحة نهاية الدوام للأيام التالية (0 لليوم نفسه)',
              'endDayOffset',
              schedule,
              (value) => _updateRemoteSection('schedule', value),
            ),
            inheritedMinutes(
              'فترة السماح بالتأخير',
              'graceMinutes',
              _readInt(_grace),
            ),
            inheritedMinutes(
              'حد ربع اليوم',
              'quarterDayUntilMinutes',
              _readInt(_quarterUntil),
            ),
            inheritedMinutes(
              'حد نصف اليوم',
              'halfDayUntilMinutes',
              _readInt(_halfUntil),
            ),
            Text(
              'قنوات الدوام المتاحة',
              style: theme.textTheme.titleSmall,
              textDirection: TextDirection.rtl,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final channel in const [
                  ('remote_web', 'من المتصفح عن بُعد'),
                  ('on_site_mobile', 'من الجوال في الموقع'),
                ])
                  FilterChip(
                    label: Text(channel.$2),
                    selected: channels.contains(channel.$1),
                    onSelected:
                        _saving
                            ? null
                            : (selected) {
                              final next = {...channels};
                              selected
                                  ? next.add(channel.$1)
                                  : next.remove(channel.$1);
                              setState(
                                () =>
                                    _remoteWorkPolicy = {
                                      ..._remoteWorkPolicy,
                                      'channels': next.toList()..sort(),
                                    },
                              );
                            },
                  ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: eligibility['probationEligible'] == true,
              onChanged:
                  _saving
                      ? null
                      : (value) => _updateRemoteSection('eligibility', {
                        ...eligibility,
                        'probationEligible': value,
                      }),
              title: const Text('السماح للموظف خلال فترة التجربة'),
            ),
            const Text('قنوات تسجيل الحضور'),
            for (final channel in const [
              ('remote_web', 'العمل من المتصفح'),
              ('on_site_mobile', 'الحضور من موقع الشركة'),
            ])
              CheckboxListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: channels.contains(channel.$1),
                onChanged: _saving
                    ? null
                    : (checked) {
                        final next = {...channels};
                        if (checked == true) {
                          next.add(channel.$1);
                        } else {
                          next.remove(channel.$1);
                        }
                        setState(() => _remoteWorkPolicy = {
                              ..._remoteWorkPolicy,
                              'channels': next.toList()..sort(),
                            });
                      },
                title: Text(channel.$2),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نقاط المتابعة (${checkpoints.length})',
                    style: theme.textTheme.titleMedium,
                    textDirection: TextDirection.rtl,
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () {
                            final next = [
                              ...checkpoints,
                              {
                                'id':
                                    'checkpoint_${DateTime.now().microsecondsSinceEpoch}',
                                'label': 'نقطة متابعة جديدة',
                                'dueTime': '12:00',
                                'graceMinutes': 15,
                              },
                            ];
                            _updateRemoteSection('schedule', {
                              ...schedule,
                              'checkpoints': next,
                            });
                          },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة نقطة'),
                ),
              ],
            ),
            for (var index = 0; index < checkpoints.length; index++) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                'checkpoint-label-$index-${checkpoints[index]['id']}',
                              ),
                              initialValue:
                                  checkpoints[index]['label']?.toString() ?? '',
                              decoration: const InputDecoration(
                                labelText: 'اسم النقطة',
                              ),
                              onChanged: (value) {
                                final next = [...checkpoints];
                                next[index] = {...next[index], 'label': value};
                                _updateRemoteSection('schedule', {
                                  ...schedule,
                                  'checkpoints': next,
                                });
                              },
                            ),
                          ),
                          IconButton(
                            onPressed:
                                _saving
                                    ? null
                                    : () {
                                      final next = [...checkpoints]
                                        ..removeAt(index);
                                      _updateRemoteSection('schedule', {
                                        ...schedule,
                                        'checkpoints': next,
                                      });
                                    },
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'حذف النقطة',
                          ),
                        ],
                      ),
                      TextFormField(
                        key: ValueKey(
                          'checkpoint-time-$index-${checkpoints[index]['id']}',
                        ),
                        initialValue:
                            checkpoints[index]['dueTime']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'موعدها (HH:MM)',
                        ),
                        textDirection: TextDirection.ltr,
                        onChanged: (value) {
                          final next = [...checkpoints];
                          next[index] = {...next[index], 'dueTime': value};
                          _updateRemoteSection('schedule', {
                            ...schedule,
                            'checkpoints': next,
                          });
                        },
                      ),
                      TextFormField(
                        key: ValueKey(
                          'checkpoint-grace-$index-${checkpoints[index]['id']}',
                        ),
                        initialValue:
                            (checkpoints[index]['graceMinutes'] ?? 15)
                                .toString(),
                        decoration: const InputDecoration(
                          labelText: 'فترة السماح بالدقائق',
                        ),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed < 0) return;
                          final next = [...checkpoints];
                          next[index] = {
                            ...next[index],
                            'graceMinutes': parsed,
                          };
                          _updateRemoteSection('schedule', {
                            ...schedule,
                            'checkpoints': next,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(),
            Text(
              'الخطة والأجهزة والمراجعة',
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: plan['planRequired'] == true,
              onChanged:
                  _saving
                      ? null
                      : (value) => _updateRemoteSection('dailyWork', {
                        ...plan,
                        'planRequired': value,
                      }),
              title: const Text('طلب خطة عمل يومية'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: plan['summaryRequired'] == true,
              onChanged:
                  _saving
                      ? null
                      : (value) => _updateRemoteSection('dailyWork', {
                        ...plan,
                        'summaryRequired': value,
                      }),
              title: const Text('طلب ملخص نهاية اليوم'),
            ),
            numberField(
              'عدد الأجهزة المعتمدة لكل موظف',
              'maxCredentials',
              devices,
              (value) => _updateRemoteSection('devices', value),
              fallback: 1,
            ),
            numberField(
              'مدة مراجعة الجهاز بالأيام',
              'reviewIntervalDays',
              devices,
              (value) => _updateRemoteSection('devices', value),
              fallback: 180,
            ),
            numberField(
              'الحد الأدنى لأهداف خطة العمل',
              'minimumGoals',
              plan,
              (value) => _updateRemoteSection('dailyWork', value),
              fallback: 0,
            ),
            numberField(
              'الحد الأعلى لأهداف خطة العمل',
              'maximumGoals',
              plan,
              (value) => _updateRemoteSection('dailyWork', value),
              fallback: 10,
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  const {
                        'none',
                        'reminder',
                        'review',
                        'warning',
                        'pending_financial_review',
                      }.contains(review['missingCheckpointAction'])
                      ? review['missingCheckpointAction'] as String
                      : 'review',
              decoration: const InputDecoration(
                labelText: 'التعامل مع نقطة متابعة فائتة',
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('بدون إجراء')),
                DropdownMenuItem(value: 'reminder', child: Text('تذكير')),
                DropdownMenuItem(value: 'review', child: Text('مراجعة فقط')),
                DropdownMenuItem(
                  value: 'warning',
                  child: Text('تنبيه ومراجعة'),
                ),
                DropdownMenuItem(
                  value: 'pending_financial_review',
                  child: Text('اقتراح مالي بانتظار مراجعة HR'),
                ),
              ],
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        if (value != null) {
                          _updateRemoteSection('review', {
                            ...review,
                            'missingCheckpointAction': value,
                          });
                        }
                      },
            ),
            if (review['missingCheckpointAction'] == 'pending_financial_review')
              numberField(
                'الحد الأقصى للاقتراح المالي اليومي',
                'dailyFinancialCap',
                review,
                (value) => _updateRemoteSection('review', value),
                fallback: 0,
              ),
            const Divider(),
            Text('التذكيرات والخصوصية', style: theme.textTheme.titleMedium),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: notifications['enabled'] == true,
              onChanged: _saving
                  ? null
                  : (value) => _updateRemoteSection('notifications', {
                        ...notifications,
                        'enabled': value,
                      }),
              title: const Text('تفعيل تذكيرات نقاط المتابعة'),
            ),
            if (notifications['enabled'] == true)
              numberField(
                'التذكير قبل الموعد بالدقائق',
                'reminderLeadMinutes',
                notifications,
                (value) => _updateRemoteSection('notifications', value),
                fallback: 30,
              ),
            numberField(
              'مدة الاحتفاظ بسجل العمل بالأيام',
              'workEvidenceDays',
              (privacy['retentionDays'] is Map
                  ? Map<String, dynamic>.from(privacy['retentionDays'] as Map)
                  : <String, dynamic>{'workEvidenceDays': 365}),
              (value) => _updateRemoteSection('privacy', {
                ...privacy,
                'retentionDays': {
                  if (privacy['retentionDays'] is Map)
                    ...Map<String, dynamic>.from(privacy['retentionDays'] as Map),
                  ...value,
                },
              }),
              fallback: 365,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'سلسلة الموافقات',
                    style: theme.textTheme.titleMedium,
                    textDirection: TextDirection.rtl,
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () => setState(
                            () =>
                                _remoteWorkPolicy = {
                                  ..._remoteWorkPolicy,
                                  'approvals': {
                                    ...approvals,
                                    'remoteDay': [
                                      ...approvalSteps,
                                    {
                                      'id':
                                          'approver_${DateTime.now().microsecondsSinceEpoch}',
                                      'resolver': 'manager',
                                      'required': true,
                                    },
                                    ],
                                  },
                                },
                          ),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مرحلة'),
                ),
              ],
            ),
            for (var index = 0; index < approvalSteps.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('المرحلة ${index + 1}'),
                subtitle: DropdownButton<String>(
                  isExpanded: true,
                  value:
                      const {
                            'manager',
                            'hr',
                            'it',
                            'ceo',
                            'specific_user',
                            'capability',
                          }.contains(approvalSteps[index]['resolver'])
                          ? approvalSteps[index]['resolver'] as String
                          : 'manager',
                  items: const [
                    DropdownMenuItem(
                      value: 'manager',
                      child: Text('المدير المباشر'),
                    ),
                    DropdownMenuItem(
                      value: 'hr',
                      child: Text('الموارد البشرية'),
                    ),
                    DropdownMenuItem(
                      value: 'it',
                      child: Text('تقنية المعلومات'),
                    ),
                    DropdownMenuItem(
                      value: 'ceo',
                      child: Text('المدير التنفيذي'),
                    ),
                    DropdownMenuItem(
                      value: 'specific_user',
                      child: Text('مستخدم محدد'),
                    ),
                    DropdownMenuItem(
                      value: 'capability',
                      child: Text('صلاحية محددة'),
                    ),
                  ],
                  onChanged:
                      _saving
                          ? null
                          : (resolver) {
                            if (resolver == null) return;
                            final next = [...approvalSteps];
                            next[index] = {
                              ...next[index],
                              'resolver': resolver,
                            };
                            setState(
                              () =>
                                  _remoteWorkPolicy = {
                                    ..._remoteWorkPolicy,
                                    'approvals': {...approvals, 'remoteDay': next},
                                  },
                            );
                          },
                ),
                trailing: IconButton(
                  tooltip: 'حذف المرحلة',
                  onPressed:
                      _saving
                          ? null
                          : () {
                            final next = [...approvalSteps]..removeAt(index);
                            setState(
                              () =>
                                  _remoteWorkPolicy = {
                                    ..._remoteWorkPolicy,
                                    'approvals': {...approvals, 'remoteDay': next},
                                  },
                            );
                          },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            const Divider(),
            Text(
              'معاينة المسودة ومراجعتها ونشرها',
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
            Text(
              'حفظ التعديلات ينشئ مسودة. لا تصبح أوقات الدوام أو قيود العمل نافذة قبل معاينتها وموافقة شخص آخر ونشرها.',
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.rtl,
            ),
            RemotePolicyEffectiveTimeField(
              value: _policyEffectiveFrom,
              enabled: !_saving,
              onChanged: (value) => setState(() => _policyEffectiveFrom = value),
            ),
            TextFormField(
              initialValue: _previewEmployeeId,
              decoration: const InputDecoration(
                labelText: 'معرف الموظف لمعاينة الأثر',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _previewEmployeeId = value.trim()),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_as_outlined),
              label: const Text('حفظ المسودة'),
            ),
            OutlinedButton.icon(
              onPressed: _saving || _previewEmployeeId.isEmpty
                  ? null
                  : () => context.read<RemotePolicyPublicationCubit>().preview(
                        aggregate: _remoteAggregateFromForm(),
                        employeeId: _previewEmployeeId,
                        date: _policyEffectiveFrom,
                        draftVersion: _remoteDraftVersion,
                      ),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('معاينة الموظف والتاريخ'),
            ),
            if (_remoteDraftVersion > 0) ...[
              TextFormField(
                initialValue: _approvalReason,
                decoration: const InputDecoration(
                  labelText: 'سبب مراجعة المسودة',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _approvalReason = value),
              ),
              BlocBuilder<RemotePolicyPublicationCubit, RemotePolicyPublicationState>(
                builder: (context, state) => RemotePolicyReviewActions(
                  draftVersion: _remoteDraftVersion,
                  hasUnsavedChanges: _savedPolicyFingerprint != _policyFingerprint(),
                  working: _saving || state is RemotePolicyPublicationWorking,
                  reason: _approvalReason,
                  onApprove: () async {
                    final editor = context.read<RemotePolicyEditorCubit>();
                    final receipt = await context.read<RemotePolicyPublicationCubit>().approve(
                      expectedVersion: _remoteDraftVersion, reason: _approvalReason.trim(),
                    );
                    if (receipt != null && mounted) {
                      editor.recordReceipt(receipt);
                      setState(() => _remoteDraftVersion = receipt.version);
                    }
                  },
                  onPublish: () async {
                    final receipt = await context.read<RemotePolicyPublicationCubit>().publish(
                      expectedVersion: _remoteDraftVersion, effectiveFrom: _policyEffectiveFrom,
                    );
                    if (receipt != null && mounted) await _load();
                  },
                ),
              ),
            ],
            TextButton.icon(
              onPressed: () => context
                  .read<RemotePolicyPublicationCubit>()
                  .loadHistory(),
              icon: const Icon(Icons.history),
              label: const Text('سجل الإصدارات'),
            ),
            BlocBuilder<RemotePolicyPublicationCubit, RemotePolicyPublicationState>(
              builder: (context, state) {
                final ready = switch (state) {
                  RemotePolicyPublicationReady value => value,
                  RemotePolicyPublicationWorking(:final previous) => previous,
                  _ => null,
                };
                if (state is RemotePolicyPublicationFailure) {
                  return Text(state.message, textDirection: TextDirection.rtl);
                }
                if (ready == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ready.message != null)
                      Text(ready.message!, textDirection: TextDirection.rtl),
                    if (ready.preview != null)
                      Text(
                        'بصمة السياسة المعاينة: ${ready.preview!['resolvedHash'] ?? ''}',
                        textDirection: TextDirection.ltr,
                      ),
                    for (final revision in ready.history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('الإصدار ${revision['revision'] ?? ''}'),
                        subtitle: Text(
                          'الحالة: ${revision['state'] ?? ''} • ${revision['effectiveFrom'] ?? ''}',
                          textDirection: TextDirection.rtl,
                        ),
                        trailing: IconButton(
                          tooltip: 'إنشاء مسودة من هذا الإصدار',
                          onPressed: () async {
                            final publicationCubit = context
                                .read<RemotePolicyPublicationCubit>();
                            final editorCubit = context
                                .read<RemotePolicyEditorCubit>();
                            final receipt = await publicationCubit
                                .revert(
                                  targetRevisionId: '${revision['revisionId'] ?? revision['revision']}',
                                  effectiveFrom: DateTime.now(),
                                );
                            if (receipt == null || !mounted) return;
                            await editorCubit.load(draftId: receipt.draftId);
                            if (mounted) await _load();
                          },
                          icon: const Icon(Icons.restore),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _starterRemotePolicy() => {
    'eligibility': {
      'weekStartDay': 6,
      'daysPerWeek': 1,
      'allowedWeekdays': [6, 7, 1, 2, 3, 4],
      'probationEligible': false,
    },
    'schedule': {
      'startTime': {'mode': 'inherit'},
      'endTime': {'mode': 'inherit'},
      'checkInOpenTime': {'mode': 'inherit'},
      'latestCheckoutTime': {'mode': 'inherit'},
      'graceMinutes': {'mode': 'inherit'},
      'quarterDayUntilMinutes': {'mode': 'inherit'},
      'halfDayUntilMinutes': {'mode': 'inherit'},
      'endDayOffset': 0,
      'checkpoints': [
        {
          'id': 'update_1',
          'label': 'تحديث الصباح',
          'dueTime': '11:00',
          'graceMinutes': 15,
        },
        {
          'id': 'update_2',
          'label': 'تحديث منتصف اليوم',
          'dueTime': '13:00',
          'graceMinutes': 15,
        },
        {
          'id': 'update_3',
          'label': 'تحديث نهاية اليوم',
          'dueTime': '15:00',
          'graceMinutes': 15,
        },
      ],
    },
    'channels': ['remote_web'],
    'devices': {'maxCredentials': 1, 'reviewIntervalDays': 180, 'verificationProfile': 'hr_approved_passkey'},
    'dailyWork': {
      'planRequired': true,
      'summaryRequired': true,
      'minimumGoals': 0,
      'maximumGoals': 10,
    },
    'notifications': {'enabled': false, 'reminderLeadMinutes': 30},
    'privacy': {'retentionDays': {'workEvidenceDays': 365}},
    'approvals': {
      'remoteDay': [
        {'id': 'hr_approval', 'resolver': 'hr', 'required': true},
      ],
    },
    'review': {'missingCheckpointAction': 'review'},
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'سياسة الدوام والحضور',
            style: theme.textTheme.headlineMedium,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            )
          : Form(
              key: _formKey,
              onChanged: () {
                if (!_loading && mounted) setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCheckoutPolicyCard(theme),
                  const SizedBox(height: 16),
                  _buildRemotePolicyCard(theme),
                  const SizedBox(height: 16),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'طريقة التحقق من الحضور',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'location_only',
                                icon: Icon(Icons.location_on_outlined),
                                label: Text('الموقع فقط'),
                              ),
                              ButtonSegment<String>(
                                value: 'biometric',
                                icon: Icon(Icons.fingerprint),
                                label: Text('الموقع والبصمة'),
                              ),
                            ],
                            selected: {_attendanceVerificationMode},
                            showSelectedIcon: false,
                            onSelectionChanged: _saving
                                ? null
                                : (selection) {
                                    setState(() {
                                      _attendanceVerificationMode =
                                          selection.first;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _attendanceVerificationMode == 'biometric'
                              ? 'يتطلب الموقع داخل النطاق ثم بصمة أو وجه الجهاز.'
                              : 'يتحقق من الجهاز والموقع داخل النطاق دون طلب البصمة.',
                          style: theme.textTheme.bodySmall,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'التحديث والأمان',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'البناء الحالي على هذا الجهاز: $_currentBuild. فعّل المنع بعد نشر الإصدار الآمن على المتاجر فقط.',
                          style: theme.textTheme.bodySmall,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _forceUpdateEnabled,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                    setState(() => _forceUpdateEnabled = value),
                          title: const Text('إلزام المستخدمين بالتحديث'),
                          subtitle: const Text(
                            'يعرض شاشة تحديث مانعة للإصدارات الأقل من الأرقام المحددة.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _enforceSecureAttendance,
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _enforceSecureAttendance = value,
                                ),
                          title: const Text('منع الحضور من الإصدارات القديمة'),
                          subtitle: const Text(
                            'يفرض بروتوكول الحضور الآمن رقم 2 في قواعد Firebase.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _blockAndroidDeveloperOptions,
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _blockAndroidDeveloperOptions = value,
                                ),
                          title: const Text(
                            'منع الحضور مع خيارات المطور على Android',
                          ),
                          subtitle: const Text(
                            'يمنع مسار تطبيقات Fake GPS المعتادة. يجب إيقاف Developer options وUSB debugging.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNumberField(
                          'أقل Build مسموح لأندرويد',
                          _minimumAndroidBuild,
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          'أقل Build مسموح لـ iOS',
                          _minimumIosBuild,
                        ),
                        const SizedBox(height: 12),
                        WolfInputField(
                          controller: _androidStoreUrl,
                          labelText: 'رابط تحديث Android',
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 12),
                        WolfInputField(
                          controller: _iosStoreUrl,
                          labelText: 'رابط تحديث iOS',
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 12),
                        WolfInputField(
                          controller: _updateMessage,
                          labelText: 'رسالة التحديث الإجباري',
                          textDirection: TextDirection.rtl,
                          validator: (value) =>
                              (value?.trim().isNotEmpty ?? false)
                              ? null
                              : 'اكتب رسالة واضحة للمستخدم',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'أوقات الدوام',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        _timeField('فتح تسجيل الحضور', _checkInOpen),
                        const SizedBox(height: 12),
                        _timeField('بداية الدوام الافتراضية', _start),
                        const SizedBox(height: 12),
                        _timeField('نهاية الدوام الافتراضية', _end),
                        const SizedBox(height: 12),
                        _timeField('آخر موعد لتسجيل الانصراف', _latestCheckout),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تذكيرات الحضور',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تُرسل من الخادم للموظف في يوم عمله فقط، مع مراعاة الإجازات والأذونات المعتمدة.',
                          style: theme.textTheme.bodySmall,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        _minutesField(
                          'قبل بداية الدوام بكم دقيقة',
                          _reminderLead,
                        ),
                        const SizedBox(height: 12),
                        _minutesField(
                          'تنبيه قبل احتساب التأخير بكم دقيقة',
                          _lateWarning,
                        ),
                        const SizedBox(height: 12),
                        _minutesField(
                          'التنبيه النهائي قبل خصم يوم كامل بكم دقيقة',
                          _finalWarningLead,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'خصومات التأخير',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        _minutesField('فترة السماح بالدقائق', _grace),
                        const SizedBox(height: 12),
                        _minutesField(
                          'حتى ربع يوم بالدقائق من بداية الدوام',
                          _quarterUntil,
                        ),
                        const SizedBox(height: 12),
                        _minutesField(
                          'حتى نصف يوم بالدقائق من بداية الدوام',
                          _halfUntil,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'أي خصم مقترح يبقى بانتظار موافقة HR قبل اعتماده.',
                          style: theme.textTheme.bodySmall,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                  WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'قواعد الطلبات والاعتماد المالي والإداري',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تخصيص شروط وسلالم تصعيد موافقة المدير التنفيذي (CEO) والمدد الزمنية للطلبات بدلاً من القيم الثابتة.',
                          style: theme.textTheme.bodySmall,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          'حد أيام الإجازة لتصعيدها للـ CEO (3 كقيمة افتراضية، 0 للإلغاء)',
                          _ceoLeaveThreshold,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _requireCeoApprovalForRemote,
                          onChanged: _saving
                              ? null
                              : (val) => setState(() => _requireCeoApprovalForRemote = val),
                          title: const Text('طلب موافقة CEO على العمل عن بعد'),
                          subtitle: const Text('يتطلب يوم العمل عن بعد موافقة المدير التنفيذي.'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _requireCeoApprovalForAdvance,
                          onChanged: _saving
                              ? null
                              : (val) => setState(() => _requireCeoApprovalForAdvance = val),
                          title: const Text('طلب موافقة CEO على طلبات السلفة'),
                          subtitle: const Text('تمر السلفة بمرحلة اعتماد CEO قبل الصرف المالي.'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _requireHrAfterManagerApproval,
                          onChanged: _saving
                              ? null
                              : (val) => setState(() => _requireHrAfterManagerApproval = val),
                          title: const Text('إلزام مراجعة HR بعد موافقة المدير المباشر'),
                          subtitle: const Text('تتطلب الطلبات العادية توثيق HR بعد المدير.'),
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          'أيام الإشعار المسبق للإجازة العادية (بالأيام)',
                          _leaveNoticeDays,
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          'فترة التجربة للموظف الجديد (بالأيام - 90 يوماً افتراضياً)',
                          _probationDays,
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          'عدد أيام العمل المحسوبة للشهر في مسير الرواتب (26 افتراضياً)',
                          _workDaysPerMonth,
                        ),
                        const SizedBox(height: 12),
                        WolfInputField(
                          controller: _advanceMaxSalaryPercentage,
                          labelText: 'الحد الأقصى للسلفة كنسبة من الراتب الشهري (%)',
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          validator: (value) {
                            final val = double.tryParse(value?.trim() ?? '');
                            return val != null && val > 0 && val <= 100
                                ? null
                                : 'أدخل نسبة مئوية بين 1 و 100';
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChatPolicyCard(theme),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('حفظ جميع الإعدادات والسياسات'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChatPolicyCard(ThemeData theme) {
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: ZaWolfColors.primaryCyan,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سياسة وقواعد المحادثات والشات (Chat Governance)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'تحديد صلاحيات الموظف في بدء المحادثات المباشرة. إذا بادر المدير أو الأدمن بمراسلة الموظف، تفتح القناة ويستطيع الموظف التحدث معه تلقائياً.',
            style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 13),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithPeers,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers: val,
                        employeeCanChatWithDirectManager:
                            _chatPolicy.employeeCanChatWithDirectManager,
                        employeeCanChatWithHr: _chatPolicy.employeeCanChatWithHr,
                        employeeCanChatWithIt: _chatPolicy.employeeCanChatWithIt,
                        employeeCanChatWithOtherManagers:
                            _chatPolicy.employeeCanChatWithOtherManagers,
                        employeeCanChatWithSuperAdmin:
                            _chatPolicy.employeeCanChatWithSuperAdmin,
                      ),
                    ),
            title: const Text('مراسلة الموظفين لبعضهم (الزملاء بنفس المستوى)'),
            subtitle: const Text(
                'يسمح للموظف ببدء محادثة مباشرة مع زملائه الموظفين في الشركة.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithDirectManager,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers:
                            _chatPolicy.employeeCanChatWithPeers,
                        employeeCanChatWithDirectManager: val,
                        employeeCanChatWithHr: _chatPolicy.employeeCanChatWithHr,
                        employeeCanChatWithIt: _chatPolicy.employeeCanChatWithIt,
                        employeeCanChatWithOtherManagers:
                            _chatPolicy.employeeCanChatWithOtherManagers,
                        employeeCanChatWithSuperAdmin:
                            _chatPolicy.employeeCanChatWithSuperAdmin,
                      ),
                    ),
            title: const Text('مراسلة الموظف لمديره المباشر'),
            subtitle: const Text(
                'يسمح للموظف ببدء محادثة مباشرة مع مديره المباشر أو قائد فريقه.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithHr,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers:
                            _chatPolicy.employeeCanChatWithPeers,
                        employeeCanChatWithDirectManager:
                            _chatPolicy.employeeCanChatWithDirectManager,
                        employeeCanChatWithHr: val,
                        employeeCanChatWithIt: _chatPolicy.employeeCanChatWithIt,
                        employeeCanChatWithOtherManagers:
                            _chatPolicy.employeeCanChatWithOtherManagers,
                        employeeCanChatWithSuperAdmin:
                            _chatPolicy.employeeCanChatWithSuperAdmin,
                      ),
                    ),
            title: const Text('مراسلة مسؤولي الموارد البشرية (HR)'),
            subtitle: const Text(
                'يسمح للموظف بمراسلة مسؤولي الموارد البشرية للاستفسارات والدعم.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithIt,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers:
                            _chatPolicy.employeeCanChatWithPeers,
                        employeeCanChatWithDirectManager:
                            _chatPolicy.employeeCanChatWithDirectManager,
                        employeeCanChatWithHr: _chatPolicy.employeeCanChatWithHr,
                        employeeCanChatWithIt: val,
                        employeeCanChatWithOtherManagers:
                            _chatPolicy.employeeCanChatWithOtherManagers,
                        employeeCanChatWithSuperAdmin:
                            _chatPolicy.employeeCanChatWithSuperAdmin,
                      ),
                    ),
            title: const Text('مراسلة الدعم الفني وتقنية المعلومات (IT)'),
            subtitle: const Text(
                'يسمح للموظف بمراسلة قسم الدعم الفني لحل المشاكل التقنية.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithOtherManagers,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers:
                            _chatPolicy.employeeCanChatWithPeers,
                        employeeCanChatWithDirectManager:
                            _chatPolicy.employeeCanChatWithDirectManager,
                        employeeCanChatWithHr: _chatPolicy.employeeCanChatWithHr,
                        employeeCanChatWithIt: _chatPolicy.employeeCanChatWithIt,
                        employeeCanChatWithOtherManagers: val,
                        employeeCanChatWithSuperAdmin:
                            _chatPolicy.employeeCanChatWithSuperAdmin,
                      ),
                    ),
            title: const Text('بدء محادثة مع مدراء آخرين خارج إدارته'),
            subtitle: const Text(
                'معطل افتراضياً. إذا بدأ المدير الآخر المحادثة أولاً، تصبح القناة متاحة للموظف للرد والتواصل.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _chatPolicy.employeeCanChatWithSuperAdmin,
            onChanged: _saving
                ? null
                : (val) => setState(
                      () => _chatPolicy = ChatPolicyConfig(
                        employeeCanChatWithPeers:
                            _chatPolicy.employeeCanChatWithPeers,
                        employeeCanChatWithDirectManager:
                            _chatPolicy.employeeCanChatWithDirectManager,
                        employeeCanChatWithHr: _chatPolicy.employeeCanChatWithHr,
                        employeeCanChatWithIt: _chatPolicy.employeeCanChatWithIt,
                        employeeCanChatWithOtherManagers:
                            _chatPolicy.employeeCanChatWithOtherManagers,
                        employeeCanChatWithSuperAdmin: val,
                      ),
                    ),
            title: const Text('بدء محادثة مباشرة مع الإدارة العليا / Super Admin'),
            subtitle: const Text(
                'معطل افتراضياً. يمكن التواصل إذا بادر الأدمن بالمحادثة، أو عبر تقديم طلب اجتماع (Meeting Request).'),
          ),
        ],
      ),
    );
  }
}
