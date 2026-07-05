import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      body: Stack(
        children: [
          // Cybertech background grid simulation
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/wolf_head_geometric.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ZaWolfColors.primaryCyan,
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/wolf_head_geometric.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'مرحباً بعودتك',
                      style: theme.textTheme.displaySmall!.copyWith(
                        color: Colors.white,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Welcome Back',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: ZaWolfColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Error message alert
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.error.withValues(alpha: 0.5),
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

                    // Login Form Panel
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface01,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZaWolfColors.surface02),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email/Username Input
                            WolfInputField(
                              controller: _emailController,
                              labelText: 'البريد الإلكتروني / اسم المستخدم',
                              englishLabel: 'Email / Username',
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
                            const SizedBox(height: 20),

                            // Password Input
                            WolfInputField(
                              controller: _passwordController,
                              labelText: 'كلمة المرور',
                              englishLabel: 'Password',
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
                            const SizedBox(height: 16),

                            // Remember Me Checkbox
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: ZaWolfColors.primaryCyan,
                                        onChanged: (val) {
                                          setState(() {
                                            _rememberMe = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تذكرني / Remember Me',
                                      style: theme.textTheme.bodySmall!
                                          .copyWith(
                                            color: ZaWolfColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                                // Text indicating admin reset
                                Text(
                                  'لا تملك حساباً؟ تواصل مع الإدارة',
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: ZaWolfColors.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Submit Button
                            WolfButton(
                              onPressed: _handleLogin,
                              text: 'دخول',
                              secondaryText: 'LOGIN',
                              loading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ZaWolf HR Ecosystem © 2026',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: ZaWolfColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
