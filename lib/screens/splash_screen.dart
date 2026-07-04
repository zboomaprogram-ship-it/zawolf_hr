import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Wait for splash animation / load
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // Check authentication
    if (authService.isAuthenticated) {
      final user = authService.currentUser;
      if (user != null) {
        try {
          await PermissionService().checkAndResetMonthlyPermissionQuota(user);
        } catch (e) {
          debugPrint('Failed to reset monthly quota: $e');
        }
      }

      if (!mounted) return;
      final role = authService.currentUser?.role;
      if (role == 'hr_admin') {
        context.go('/hr/dashboard');
      } else if (role == 'manager') {
        context.go('/manager/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background grid styling (simulating cyber grid)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/wolf_head_geometric.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ZaWolfColors.primaryCyan,
                          blurRadius: 30,
                          spreadRadius: 2,
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
                ),
                const SizedBox(height: 32),
                Text(
                  'ZaWolf HR',
                  style: theme.textTheme.displayMedium!.copyWith(
                    color: Colors.white,
                    letterSpacing: 2.0,
                    fontFamily: 'Rajdhani',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intelligent HR. Unleashed.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: ZaWolfColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    color: ZaWolfColors.primaryCyan,
                    backgroundColor: ZaWolfColors.surface02,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
