import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../components/performance_badges_widget.dart';
import '../../services/auth_service.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../services/personal_alarm_service.dart';
import '../../services/required_attendance_alarm_service.dart';
import '../../services/automatic_attendance_service.dart';
import '../../services/performance_badge_service.dart';
import '../../utils/user_facing_error.dart';
import '../../navigation/developer_tools_entry.dart';
import '../shared/performance_badges_overview_screen.dart';
import '../../features/profile_images/presentation/employee_avatar.dart';

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
  bool _profilePhotoBusy = false;
  bool _showPasswordForm = false;
  String _passwordStrength =
      'ضعيف'; // ضعيف (Weak) | متوسط (Medium) | قوي (Strong)
  Color _passwordStrengthColor = ZaWolfColors.error;

  // Preferences visual triggers
  PersonalAlarmSettings _personalAlarm = const PersonalAlarmSettings.disabled();
  String? _personalAlarmUserId;
  bool _loadingPersonalAlarm = false;
  bool _savingPersonalAlarm = false;
  PersonalAlarmCapability? _personalAlarmCapability;
  bool _automaticAttendanceEnabled = false;
  bool _loadingAutomaticAttendance = false;
  Future<bool>? _developerToolsAvailable;

  // The application is Arabic-first. These rows always open a deeper page,
  // so their affordance belongs on the left and must point left. Do not use a
  // direction-sensitive icon here: this screen can be embedded by an LTR
  // route on web/native and that used to mirror the chevron incorrectly.
  static const _detailsChevron = Icon(
    Icons.chevron_left,
    textDirection: TextDirection.ltr,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService>(context).currentUser;
    if (user != null && _personalAlarmUserId != user.uid) {
      _loadPersonalAlarm(user.uid);
      if (AutomaticAttendanceService.instance.isSupported) {
        _loadAutomaticAttendance(user.uid);
      }
      _developerToolsAvailable ??=
          DeveloperToolsAccess.isAvailableForCurrentUser();
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
    if (enabled && !await _confirmAutomaticAttendanceDisclosure()) {
      return;
    }
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
          content: Text(
            userFacingError(
              error,
              fallback: 'تعذر تحديث إعداد الحضور التلقائي الآن. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingAutomaticAttendance = false);
    }
  }

  /// Google Play requires this disclosure to be shown in the feature flow
  /// before the Android runtime background-location request. The operating
  /// system prompt remains the employee's permission decision.
  Future<bool> _confirmAutomaticAttendanceDisclosure() async {
    final continueToPermission = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('إفصاح عن استخدام الموقع'),
            content: const Text(
              'يجمع ZaWolf HR بيانات الموقع لتفعيل الحضور التلقائي حتى عندما '
              'يكون التطبيق مغلقاً أو غير مستخدم. يستخدم الموقع فقط لمراقبة '
              'حدود موقع العمل المعيّن وتسجيل الدخول أو الخروج، ولا يستخدم '
              'للإعلانات أو لتتبع مسار تنقلك. يمكنك إيقاف الميزة في أي وقت.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ليس الآن'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('متابعة'),
              ),
            ],
          ),
    );
    return continueToPermission ?? false;
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

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('اختيار من الصور'),
                    onTap:
                        () =>
                            Navigator.of(sheetContext).pop(ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('التقاط صورة'),
                    onTap:
                        () =>
                            Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
    );
    if (source == null || !mounted) return;
    setState(() => _profilePhotoBusy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 68,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      final encoded = 'data:$mimeType;base64,${base64Encode(bytes)}';
      if (encoded.length > 300000) {
        throw ArgumentError('profile_image_too_large');
      }
      if (!mounted) return;
      await context.read<AuthService>().updateProfilePhoto(encoded);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة الشخصية.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'تعذر تحديث الصورة. حاول بصورة أصغر.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _profilePhotoBusy = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    setState(() => _profilePhotoBusy = true);
    try {
      await context.read<AuthService>().updateProfilePhoto(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إزالة الصورة الشخصية.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'تعذر إزالة الصورة. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _profilePhotoBusy = false);
    }
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
        // The manual alarm is deliberately an alternative to the
        // date-aware attendance alarm.  Keeping both caused two alerts at
        // the same work-start time for some employees.
        await RequiredAttendanceAlarmService.instance.disable(userId);
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
          () =>
              _personalAlarm = PersonalAlarmSettings(
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
            content: Text(
              userFacingError(
                error,
                fallback: 'تعذر حفظ إعداد المنبه الآن. حاول مرة أخرى.',
              ),
            ),
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
        await RequiredAttendanceAlarmService.instance.disable(userId);
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

    final joinDateStr =
        user.joinDate != null
            ? DateFormat('yyyy-MM-dd').format(user.joinDate!)
            : 'غير متوفر';
    final mustChangeDefaultPassword = user.passwordChangedAt == null;

    // Keep every list-row affordance in Arabic RTL, even when this screen is
    // reached from a route whose inherited direction is temporarily LTR.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const SizedBox(width: 100, height: 100),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [ZaWolfColors.wolfGlow],
                            ),
                            child: EmployeeAvatar(
                              name: user.displayName,
                              photoUrl: user.photoURL,
                              size: 100,
                              ringColor: ZaWolfColors.primaryCyan,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: -4,
                          bottom: -4,
                          child: PopupMenuButton<String>(
                            tooltip: 'تغيير الصورة الشخصية',
                            onSelected: (value) {
                              if (value == 'change') {
                                _changeProfilePhoto();
                              } else {
                                _removeProfilePhoto();
                              }
                            },
                            itemBuilder:
                                (_) => [
                                  const PopupMenuItem(
                                    value: 'change',
                                    child: Text('تغيير الصورة'),
                                  ),
                                  if ((user.photoURL ?? '').isNotEmpty)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('إزالة الصورة'),
                                    ),
                                ],
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: ZaWolfColors.primaryBlue,
                              child:
                                  _profilePhotoBusy
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.camera_alt_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.displayName,
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: ZaWolfColors.textPrimary,
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
                          color: ZaWolfColors.textPrimary,
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
                        color: ZaWolfColors.textPrimary,
                      ),
                    ),
                    const Divider(color: ZaWolfColors.surface02, height: 20),
                    _buildProfileRow(
                      'الرقم الوظيفي (ID)',
                      user.employeeId,
                      theme,
                    ),
                    _buildProfileRow('البريد الإلكتروني', user.email, theme),
                    _buildProfileRow(
                      'الفرع / الموقع',
                      user.locationName,
                      theme,
                    ),
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
                    _buildProfileRow('تاريخ التعيين', joinDateStr, theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildLeaveBalanceCard(user, theme),
              const SizedBox(height: 20),
              WolfCard(
                padding: EdgeInsets.zero,
                onTap: () => context.push('/employee/requests?view=history'),
                child: ListTile(
                  leading: const Icon(
                    Icons.history_outlined,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  title: const Text('سجل طلباتي'),
                  subtitle: const Text(
                    'عرض الطلبات السابقة ومسار الموافقات وحالة كل طلب',
                  ),
                  trailing: _detailsChevron,
                ),
              ),
              const SizedBox(height: 20),
              WolfCard(
                padding: EdgeInsets.zero,
                onTap: () => context.go('/employee/deductions'),
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  title: const Text('خصوماتي'),
                  subtitle: const Text(
                    'عرض الخصومات بالأيام وحالة مراجعة HR بدون مبالغ مالية',
                  ),
                  trailing: _detailsChevron,
                ),
              ),
              StreamBuilder<Set<String>>(
                stream: PerformanceBadgeService.instance.watchAwardedBadgeIds(
                  user.uid,
                ),
                builder: (context, snapshot) {
                  final ids = snapshot.data ?? const <String>{};
                  return PerformanceBadgesWidget(awardedBadgeIds: ids);
                },
              ),
              if (EmployeeRole.hasTeamScope(user.role)) ...[
                WolfCard(
                  padding: EdgeInsets.zero,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => PerformanceBadgesOverviewScreen(
                                viewerId: user.uid,
                                canViewAll: EmployeeRole.isHr(user.role),
                              ),
                        ),
                      ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.emoji_events_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: const Text('شارات فريق العمل'),
                    subtitle: const Text(
                      'عرض الموظفين الذين حصلوا على شارات التميز',
                    ),
                    trailing: const Icon(
                      Icons.chevron_left,
                      size: 18,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 14),

              const SizedBox(height: 20),

              // Settings Panels
              Text(
                'الإعدادات العامة / Preferences',
                style: theme.textTheme.titleMedium!.copyWith(
                  color: ZaWolfColors.textPrimary,
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
                    if (AutomaticAttendanceService.instance.isSupported) ...[
                      ListTile(
                        leading: const Icon(
                          Icons.location_searching,
                          color: ZaWolfColors.primaryCyan,
                        ),
                        title: const Text('الحضور التلقائي بالموقع'),
                        subtitle: const Text(
                          'اختياري: يستخدم نطاق فرعك فقط لتسجيل الدخول والخروج، ولا يتتبع مسارك المستمر. يتطلب إذن الموقع دائماً ويمكن إيقافه في أي وقت.',
                        ),
                        trailing:
                            _loadingAutomaticAttendance
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : Switch(
                                  value: _automaticAttendanceEnabled,
                                  activeThumbColor: ZaWolfColors.primaryCyan,
                                  inactiveThumbColor: ZaWolfColors.textPrimary,
                                  inactiveTrackColor: ZaWolfColors.surface03,
                                  onChanged: _setAutomaticAttendanceEnabled,
                                ),
                      ),
                      const Divider(color: ZaWolfColors.surface02, height: 1),
                    ],
                    ListTile(
                      leading: const Icon(
                        Icons.notifications_none,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      title: const Text('مركز الإشعارات'),
                      subtitle: const Text('عرض التنبيهات والإعلانات السابقة'),
                      trailing: _detailsChevron,
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(color: ZaWolfColors.surface02, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.alarm,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      title: const Text('منبه دوام يدوي'),
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
                            : 'غير مفعّل — يستخدم منبه الحضور الذكي إن كان مفعّلاً',
                      ),
                      trailing:
                          _savingPersonalAlarm || _loadingPersonalAlarm
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Switch(
                                value: _personalAlarm.enabled,
                                activeThumbColor: ZaWolfColors.primaryCyan,
                                inactiveThumbColor: ZaWolfColors.textPrimary,
                                inactiveTrackColor: ZaWolfColors.surface03,
                                onChanged:
                                    (value) => _setPersonalAlarmEnabled(
                                      user.uid,
                                      value,
                                    ),
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
                        onPressed:
                            _savingPersonalAlarm || _loadingPersonalAlarm
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
                      trailing: _detailsChevron,
                      onTap: () => context.push('/privacy'),
                    ),
                    const Divider(color: ZaWolfColors.surface02, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.gavel_outlined,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      title: const Text('الشروط والأحكام'),
                      subtitle: const Text(
                        'قواعد استخدام النظام ومسؤوليات الحساب',
                      ),
                      trailing: _detailsChevron,
                      onTap: () => context.push('/terms'),
                    ),
                    FutureBuilder<bool>(
                      future: _developerToolsAvailable,
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            const Divider(
                              color: ZaWolfColors.surface02,
                              height: 1,
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.developer_mode_outlined,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              title: const Text('أدوات المطوّر'),
                              subtitle: const Text(
                                'أدوات فحص داخل التطبيق بصلاحية مؤقتة',
                              ),
                              trailing: _detailsChevron,
                              onTap: () => context.push('/developer-tools'),
                            ),
                          ],
                        );
                      },
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
                      color:
                          _showPasswordForm
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
                              color: ZaWolfColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _showPasswordForm
                            ? Icons.expand_less
                            : Icons.expand_more,
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
                          validator:
                              (val) =>
                                  val == null || val.isEmpty
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
                color: ZaWolfColors.textPrimary,
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
      (label: 'عارضة', value: balance.casual, color: ZaWolfColors.warning),
      (
        label: 'الرصيد الكلي',
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
                  color: ZaWolfColors.textPrimary,
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
