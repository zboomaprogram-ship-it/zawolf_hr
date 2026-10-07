import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../utils/user_facing_error.dart';
import '../../features/checkout_policy/data/checkout_policy_repository_impl.dart';
import '../../features/checkout_policy/domain/entities/checkout_policy.dart';
import '../../features/checkout_policy/presentation/checkout_policy_controller.dart';

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
    final results = await Future.wait([
      AttendancePolicyService().getPolicyConfig(),
      AppSecurityPolicyService.instance.loadStatus(),
      _checkoutPolicyController.load(),
      _requestApprovalPolicyService.getPolicy(),
      _chatPolicyService.loadPolicy(),
    ]);
    final policy = results[0] as AttendancePolicyConfig;
    final securityStatus = results[1] as AppSecurityStatus;
    final checkoutPolicy = results[2] as CheckoutPolicySnapshot;
    final reqPolicy = results[3] as RequestApprovalPolicy;
    final chatPolicy = results[4] as ChatPolicyConfig;
    if (!mounted) return;
    _checkInOpen.text = policy.checkInOpenTime;
    _start.text = policy.defaultStartTime;
    _end.text = policy.defaultEndTime;
    _latestCheckout.text = policy.latestCheckoutTime;
    _reminderLead.text = policy.checkInReminderLeadMinutes.toString();
    _lateWarning.text = policy.checkInLateWarningMinutes.toString();
    _finalWarningLead.text = policy.checkInFinalWarningLeadMinutes.toString();
    _grace.text = policy.graceMinutes.toString();
    _quarterUntil.text = policy.quarterDayUntilMinutes.toString();
    _halfUntil.text = policy.halfDayUntilMinutes.toString();
    _loadedPolicy = policy;
    _attendanceVerificationMode = policy.attendanceVerificationMode;
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
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('companies').doc('zawolf'), {
        'attendancePolicy': policy.toMap(),
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
              'تم حفظ سياسات الدوام وقواعد الطلبات وإعدادات الشات بنجاح.',
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCheckoutPolicyCard(theme),
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
