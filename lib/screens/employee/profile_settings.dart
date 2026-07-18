import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../services/auth_service.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../services/onesignal_service.dart';
import '../../services/personal_alarm_service.dart';
import '../../services/automatic_attendance_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKeyPassword = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showPasswordForm = false;
  String _passwordStrength =
      'ضعيف'; // ضعيف (Weak) | متوسط (Medium) | قوي (Strong)
  Color _passwordStrengthColor = ZaWolfColors.error;

  // Preferences visual triggers
  bool _notificationBanners = true;
  String _appLanguage = 'ar'; // ar | en
  bool _registeringNotifications = false;
  PersonalAlarmSettings _personalAlarm = const PersonalAlarmSettings.disabled();
  String? _personalAlarmUserId;
  bool _loadingPersonalAlarm = false;
  bool _savingPersonalAlarm = false;
  PersonalAlarmCapability? _personalAlarmCapability;
  bool _automaticAttendanceEnabled = false;
  bool _loadingAutomaticAttendance = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService>(context).currentUser;
    if (user != null && _personalAlarmUserId != user.uid) {
      _loadPersonalAlarm(user.uid);
      if (AutomaticAttendanceService.instance.isSupported) {
        _loadAutomaticAttendance(user.uid);
      }
    }
  }

  Future<void> _loadAutomaticAttendance(String userId) async {
    setState(() => _loadingAutomaticAttendance = true);
    try {
      final enabled = await AutomaticAttendanceService.instance.isEnabledFor(
        userId,
      );
      if (mounted) setState(() => _automaticAttendanceEnabled = enabled);
    } finally {
      if (mounted) setState(() => _loadingAutomaticAttendance = false);
    }
  }

  Future<void> _setAutomaticAttendanceEnabled(bool enabled) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() => _loadingAutomaticAttendance = true);
    try {
      if (enabled) {
        await AutomaticAttendanceService.instance.enableFor(user);
      } else {
        await AutomaticAttendanceService.instance.disable(user.uid);
      }
      if (!mounted) return;
      setState(() => _automaticAttendanceEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'تم تفعيل الحضور التلقائي. سيعمل عند دخول أو مغادرة نطاق الفرع في الوقت المناسب.'
                : 'تم إيقاف الحضور التلقائي. يمكنك استخدام تسجيل الحضور اليدوي.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingAutomaticAttendance = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 'ضعيف';
        _passwordStrengthColor = ZaWolfColors.error;
      });
      return;
    }

    // Simple password strength calculation
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    setState(() {
      if (score >= 4) {
        _passwordStrength = 'قوي جداً';
        _passwordStrengthColor = ZaWolfColors.success;
      } else if (score >= 2) {
        _passwordStrength = 'متوسط';
        _passwordStrengthColor = ZaWolfColors.warning;
      } else {
        _passwordStrength = 'ضعيف';
        _passwordStrengthColor = ZaWolfColors.error;
      }
    });
  }

  Future<void> _changePassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;

    setState(() => _loading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text('تم تغيير كلمة المرور بنجاح ✅'),
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _showPasswordForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل تغيير كلمة المرور: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enablePushNotifications(String uid) async {
    setState(() => _registeringNotifications = true);
    try {
      final state = await OneSignalService.instance.ensureRegistered(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: state.isReady
              ? ZaWolfColors.success
              : ZaWolfColors.warning,
          content: Text(
            state.isReady
                ? 'تم تفعيل الإشعارات وربط هذا الجهاز بالحساب.'
                : 'لم يكتمل التفعيل. اسمح بالإشعارات من إعدادات الهاتف ثم حاول مرة أخرى.',
          ),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text(
            'تعذر ربط الإشعارات: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _registeringNotifications = false);
    }
  }

  Future<void> _loadPersonalAlarm(String userId) async {
    _personalAlarmUserId = userId;
    setState(() => _loadingPersonalAlarm = true);
    try {
      final results = await Future.wait<dynamic>([
        PersonalAlarmService.instance.load(userId),
        PersonalAlarmService.instance.capability(),
      ]);
      final settings = results[0] as PersonalAlarmSettings;
      final capability = results[1] as PersonalAlarmCapability;
      try {
        await PersonalAlarmService.instance.repairEnabledAlarmIfNeeded(
          userId,
          settings,
          capability,
        );
      } catch (_) {
        // Keep the existing local reminder if AlarmKit authorization is denied.
      }
      if (mounted && _personalAlarmUserId == userId) {
        setState(() {
          _personalAlarm = settings;
          _personalAlarmCapability = capability;
        });
      }
    } finally {
      if (mounted && _personalAlarmUserId == userId) {
        setState(() => _loadingPersonalAlarm = false);
      }
    }
  }

  Future<void> _setPersonalAlarmEnabled(String userId, bool enabled) async {
    setState(() => _savingPersonalAlarm = true);
    try {
      if (enabled) {
        final settings = await PersonalAlarmService.instance.enable(
          userId: userId,
          hour: _personalAlarm.hour,
          minute: _personalAlarm.minute,
        );
        if (!mounted) return;
        setState(() => _personalAlarm = settings);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PersonalAlarmService.instance.usesAndroidClock
                  ? 'تم تفعيل منبه الدوام اليومي. سيستمر بالرنين حتى تضغط إيقاف المنبه.'
                  : _personalAlarmCapability?.nativeSystemAlarm == true
                  ? 'تم تفعيل منبه iPhone في الساعة ${settings.formattedTime}.'
                  : 'تم تفعيل تذكير iPhone بالصوت في الساعة ${settings.formattedTime}. الإصدارات الأقل من iOS 26 لا تدعم منبه النظام الكامل.',
            ),
          ),
        );
      } else {
        await PersonalAlarmService.instance.disable(userId);
        if (!mounted) return;
        setState(
          () => _personalAlarm = PersonalAlarmSettings(
            enabled: false,
            hour: _personalAlarm.hour,
            minute: _personalAlarm.minute,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PersonalAlarmService.instance.usesAndroidClock
                  ? 'تم إيقاف منبه الدوام.'
                  : 'تم إيقاف منبه الدوام.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPersonalAlarm = false);
    }
  }

  Future<void> _choosePersonalAlarmTime(String userId) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _personalAlarm.hour,
        minute: _personalAlarm.minute,
      ),
    );
    if (chosen == null) return;

    setState(() => _savingPersonalAlarm = true);
    try {
      final settings = PersonalAlarmSettings(
        enabled: _personalAlarm.enabled,
        hour: chosen.hour,
        minute: chosen.minute,
      );
      if (settings.enabled) {
        await PersonalAlarmService.instance.enable(
          userId: userId,
          hour: settings.hour,
          minute: settings.minute,
        );
      } else {
        await PersonalAlarmService.instance.saveTime(
          userId: userId,
          enabled: false,
          hour: settings.hour,
          minute: settings.minute,
        );
      }
      if (!mounted) return;
      setState(() => _personalAlarm = settings);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ وقت المنبه. أعد المحاولة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPersonalAlarm = false);
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

    final joinDateStr = user.joinDate != null
        ? DateFormat('yyyy-MM-dd').format(user.joinDate!)
        : 'غير متوفر';
    final mustChangeDefaultPassword = user.passwordChangedAt == null;
    final pushState = OneSignalService.instance.registrationState();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'حسابي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: ZaWolfColors.error),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar Card with glow ring
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZaWolfColors.primaryCyan,
                        width: 3,
                      ),
                      boxShadow: const [ZaWolfColors.wolfGlow],
                    ),
                    child: ClipOval(
                      child: user.photoURL != null && user.photoURL!.isNotEmpty
                          ? Image.network(user.photoURL!, fit: BoxFit.cover)
                          : Image.asset(
                              'assets/images/wolf_head_geometric.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: ZaWolfColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getRoleLabel(user.role),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (mustChangeDefaultPassword) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZaWolfColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ZaWolfColors.warning.withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  'تنبيه أمان: كلمة المرور الافتراضية للحسابات الجديدة هي ZW@0000. يرجى تغييرها من هنا في أقرب وقت.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: ZaWolfColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Profile info details card
            WolfCard(
              hasBorderGlow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'البيانات الشخصية / Personal Info',
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: ZaWolfColors.surface02, height: 20),
                  _buildProfileRow(
                    'الرقم الوظيفي (ID)',
                    user.employeeId,
                    theme,
                  ),
                  _buildProfileRow('البريد الإلكتروني', user.email, theme),
                  _buildProfileRow('الفرع / الموقع', user.locationName, theme),
                  _buildProfileRow('القسم / الإدارة', user.department, theme),
                  _buildProfileRow('المسمى الوظيفي', user.position, theme),
                  _buildProfileRow(
                    'الراتب الأساسي',
                    '${user.baseMonthlySalary.toStringAsFixed(2)} ${user.salaryCurrency}',
                    theme,
                  ),
                  _buildProfileRow(
                    'المدير المباشر',
                    user.managerNames.isNotEmpty
                        ? user.managerNames.join('، ')
                        : (user.managerName ?? 'لا يوجد مدير مباشر مسند'),
                    theme,
                  ),
                  if (user.teamLeaderName != null &&
                      user.teamLeaderName!.isNotEmpty)
                    _buildProfileRow(
                      'قائد الفريق',
                      user.teamLeaderName!,
                      theme,
                    ),
                  _buildProfileRow('تاريخ الانضمام', joinDateStr, theme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildLeaveBalanceCard(user, theme),
            const SizedBox(height: 20),

            // Settings Panels
            Text(
              'الإعدادات العامة / Preferences',
              style: theme.textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZaWolfColors.surface02),
              ),
              child: Column(
                children: [
                  // Language Toggle Switch
                  ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('لغة التطبيق / Language'),
                    subtitle: Text(
                      _appLanguage == 'ar' ? 'العربية' : 'English',
                    ),
                    trailing: Switch(
                      value: _appLanguage == 'ar',
                      activeThumbColor: ZaWolfColors.primaryCyan,
                      onChanged: (val) {
                        setState(() {
                          _appLanguage = val ? 'ar' : 'en';
                        });
                      },
                    ),
                  ),
                  if (AutomaticAttendanceService.instance.isSupported) ...[
                    const Divider(color: ZaWolfColors.surface02, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.location_searching,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      title: const Text('الحضور التلقائي بالموقع'),
                      subtitle: const Text(
                        'يسجل الحضور عند دخول الفرع والانصراف عند المغادرة بعد وقت الدوام. يتطلب إذن الموقع دائماً.',
                      ),
                      trailing: _loadingAutomaticAttendance
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: _automaticAttendanceEnabled,
                              activeThumbColor: ZaWolfColors.primaryCyan,
                              onChanged: _setAutomaticAttendanceEnabled,
                            ),
                    ),
                  ],
                  const Divider(color: ZaWolfColors.surface02, height: 1),

                  // Notifications Toggle Switch
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('إشعارات فورية (Foreground)'),
                    subtitle: const Text(
                      'عرض إشعارات تفاعلية أثناء فتح التطبيق',
                    ),
                    trailing: Switch(
                      value: _notificationBanners,
                      activeThumbColor: ZaWolfColors.primaryCyan,
                      onChanged: (val) {
                        setState(() {
                          _notificationBanners = val;
                        });
                      },
                    ),
                  ),
                  const Divider(color: ZaWolfColors.surface02, height: 1),
                  ListTile(
                    leading: Icon(
                      pushState.isReady
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: pushState.isReady
                          ? ZaWolfColors.success
                          : ZaWolfColors.warning,
                    ),
                    title: const Text('إشعارات الهاتف'),
                    subtitle: Text(
                      !pushState.configured
                          ? 'غير مفعلة في نسخة التطبيق الحالية'
                          : pushState.isReady
                          ? 'مفعلة ومرتبطة بهذا الحساب'
                          : 'تحتاج إلى تفعيل أو إعادة ربط',
                    ),
                    trailing: _registeringNotifications
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'تفعيل الإشعارات',
                            onPressed: () => _enablePushNotifications(user.uid),
                            icon: const Icon(Icons.refresh),
                          ),
                  ),
                  const Divider(color: ZaWolfColors.surface02, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.alarm,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('منبه الدوام'),
                    subtitle: Text(
                      _loadingPersonalAlarm
                          ? 'جارٍ التحميل'
                          : _personalAlarm.enabled
                          ? PersonalAlarmService.instance.usesAndroidClock
                                ? 'مفعّل في ${_personalAlarm.formattedTime}'
                                : _personalAlarmCapability?.nativeSystemAlarm ==
                                      true
                                ? 'منبه iPhone مفعّل في ${_personalAlarm.formattedTime}'
                                : 'تذكير iPhone بالصوت مفعّل في ${_personalAlarm.formattedTime}'
                          : 'غير مفعّل',
                    ),
                    trailing: _savingPersonalAlarm || _loadingPersonalAlarm
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: _personalAlarm.enabled,
                            activeThumbColor: ZaWolfColors.primaryCyan,
                            onChanged: (value) =>
                                _setPersonalAlarmEnabled(user.uid, value),
                          ),
                  ),
                  ListTile(
                    enabled: !_savingPersonalAlarm && !_loadingPersonalAlarm,
                    leading: const Icon(
                      Icons.schedule,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('وقت منبه الدوام'),
                    trailing: TextButton(
                      onPressed: _savingPersonalAlarm || _loadingPersonalAlarm
                          ? null
                          : () => _choosePersonalAlarmTime(user.uid),
                      child: Text(_personalAlarm.formattedTime),
                    ),
                  ),
                  const Divider(color: ZaWolfColors.surface02, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('سياسة الخصوصية'),
                    subtitle: const Text('اعرف كيف نستخدم بياناتك ونحميها'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push('/privacy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Change Password Collapsible Card
            InkWell(
              onTap: () {
                setState(() {
                  _showPasswordForm = !_showPasswordForm;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface01,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _showPasswordForm
                        ? ZaWolfColors.primaryCyan.withValues(alpha: 0.3)
                        : ZaWolfColors.surface02,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.lock_outline,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'تغيير كلمة المرور',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showPasswordForm ? Icons.expand_less : Icons.expand_more,
                      color: ZaWolfColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // Password change form inside
            if (_showPasswordForm) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface01,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ZaWolfColors.surface02),
                ),
                child: Form(
                  key: _formKeyPassword,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WolfInputField(
                        controller: _currentPasswordController,
                        labelText: 'كلمة المرور الحالية',
                        englishLabel: 'Current Password',
                        isPassword: true,
                        validator: (val) => val == null || val.isEmpty
                            ? 'يرجى إدخال كلمة المرور الحالية'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      WolfInputField(
                        controller: _newPasswordController,
                        labelText: 'كلمة المرور الجديدة',
                        englishLabel: 'New Password',
                        isPassword: true,
                        onChanged: _checkPasswordStrength,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'يرجى إدخال كلمة المرور الجديدة';
                          }
                          if (val.length < 6) {
                            return 'يجب ألا تقل عن 6 أحرف أو أرقام';
                          }
                          return null;
                        },
                      ),

                      // Password Strength Indicator Row
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'قوة كلمة المرور:',
                            style: TextStyle(
                              fontSize: 12,
                              color: ZaWolfColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _passwordStrengthColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _passwordStrength,
                              style: TextStyle(
                                color: _passwordStrengthColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      WolfInputField(
                        controller: _confirmPasswordController,
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        englishLabel: 'Confirm Password',
                        isPassword: true,
                        validator: (val) {
                          if (val != _newPasswordController.text) {
                            return 'كلمتا المرور غير متطابقتين';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      WolfButton(
                        onPressed: _changePassword,
                        text: 'حفظ التحديث',
                        secondaryText: 'UPDATE PASSWORD',
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: ZaWolfColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard(UserModel user, ThemeData theme) {
    final balance = user.leaveBalance;
    final items = <({String label, int value, Color color})>[
      (label: 'سنوية', value: balance.annual, color: ZaWolfColors.primaryCyan),
      (label: 'مرضية', value: balance.sick, color: ZaWolfColors.permissionTeal),
      (label: 'عارضة', value: balance.casual, color: ZaWolfColors.warning),
      (
        label: 'أيام إجازة',
        value: balance.daysOff,
        color: ZaWolfColors.dayoffPurple,
      ),
    ];

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: ZaWolfColors.primaryCyan,
              ),
              const SizedBox(width: 10),
              Text(
                'رصيد الإجازات المتبقي',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item.color.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: theme.textTheme.bodySmall),
                    Text(
                      '${item.value}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    return EmployeeRole.arabicLabel(role);
  }
}
