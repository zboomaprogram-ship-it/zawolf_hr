import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_role.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';
import '../components/wolf_button.dart';
import '../components/wolf_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const _rememberAccountKey = 'login_remember_account';
  static const _rememberedEmailKey = 'login_remembered_email';

  @override
  void initState() {
    super.initState();
    _loadRememberedAccount();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberAccountKey) ?? false;
    final email = prefs.getString(_rememberedEmailKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remembered;
      if (remembered && email.isNotEmpty) {
        _emailController.text = email;
      }
    });
  }

  Future<void> _saveRememberedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberAccountKey, true);
      await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
    } else {
      await prefs.setBool(_rememberAccountKey, false);
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await _saveRememberedAccount();

      if (!mounted) return;

      final user = authService.currentUser;
      if (user != null && !user.isActive) {
        await authService.signOut();
        setState(() {
          _errorMessage =
              'عذراً، هذا الحساب تم تعطيله من قبل إدارة شؤون الموظفين.';
          _isLoading = false;
        });
        return;
      }

      // Navigate based on role
      final role = user?.role;
      if (role == EmployeeRole.superAdmin || role == EmployeeRole.hrAdmin) {
        context.go('/hr/dashboard');
      } else if (role == EmployeeRole.manager) {
        context.go('/manager/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'فشل تسجيل الدخول. يرجى التحقق من البيانات والمحاولة مرة أخرى.';
        // Optional english message:
        // _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 18.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/wolf_head_geometric.png',
                    width: 78,
                    height: 78,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'هل أنت مستعد لقيادة النظام؟',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بوابة حضور وموارد بشرية مصممة للفرق التي تعمل بدقة.',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: ZaWolfColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ZaWolfColors.error.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: ZaWolfColors.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: ZaWolfColors.error,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface01,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZaWolfColors.surface03),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.26),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          WolfInputField(
                            controller: _emailController,
                            labelText: 'البريد الإلكتروني',
                            hintText: 'user@zawolf.com',
                            prefixIcon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'يرجى إدخال البريد الإلكتروني';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          WolfInputField(
                            controller: _passwordController,
                            labelText: 'كلمة المرور',
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            textDirection: TextDirection.ltr,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'يرجى إدخال كلمة المرور';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'لا تملك حساباً؟ تواصل مع الإدارة',
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: ZaWolfColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'تذكرني',
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: ZaWolfColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: ZaWolfColors.primaryCyan,
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? false;
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          WolfButton(
                            onPressed: _handleLogin,
                            text: 'نعم، دخول النظام',
                            secondaryText: 'SIGN IN',
                            loading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ZaWolf HR',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: ZaWolfColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
