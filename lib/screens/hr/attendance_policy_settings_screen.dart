import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/attendance_policy.dart';
import '../../services/attendance_policy_service.dart';
import '../../services/app_security_policy_service.dart';
import '../../theme/theme.dart';

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
  bool _loading = true;
  bool _saving = false;
  AttendancePolicyConfig _loadedPolicy = const AttendancePolicyConfig();
  String _attendanceVerificationMode = 'location_only';
  bool _forceUpdateEnabled = false;
  bool _enforceSecureAttendance = false;
  bool _blockAndroidDeveloperOptions = true;
  int _currentBuild = 0;

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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      AttendancePolicyService().getPolicyConfig(),
      AppSecurityPolicyService.instance.loadStatus(),
    ]);
    final policy = results[0] as AttendancePolicyConfig;
    final securityStatus = results[1] as AppSecurityStatus;
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
    setState(() => _loading = false);
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
    final policy = AttendancePolicyConfig(
      checkInOpenTime: _checkInOpen.text.trim(),
      defaultStartTime: _start.text.trim(),
      defaultEndTime: _end.text.trim(),
      latestCheckoutTime: _latestCheckout.text.trim(),
      graceMinutes: grace,
      quarterDayUntilMinutes: quarter,
      halfDayUntilMinutes: half,
      payrollWorkDaysPerMonth: _loadedPolicy.payrollWorkDaysPerMonth,
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
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text(
              'تم حفظ سياسة الدوام. تُستخدم التغييرات في الحضور والتنبيهات القادمة.',
            ),
          ),
        );
      }
    } catch (error) {
      _showError(
        'تعذر حفظ الإعدادات: ${error.toString().replaceFirst('Exception: ', '')}',
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
        title: Text(
          'سياسة الدوام والحضور',
          style: theme.textTheme.headlineMedium,
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
                    label: const Text('حفظ سياسة الدوام'),
                  ),
                ],
              ),
            ),
    );
  }
}
