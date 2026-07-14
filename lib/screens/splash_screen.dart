import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/employee_role.dart';
import '../theme/theme.dart';
import '../services/notification_service.dart';

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
    // Give the brand animation a moment, but never make app navigation depend
    // on an external service completing.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        authService.loading &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;

    // Check authentication
    if (authService.isAuthenticated) {
      if (!mounted) return;
      final role = authService.currentUser?.role;

      final initialRoute = NotificationService.instance.initialRoute;
      if (initialRoute != null && initialRoute.isNotEmpty) {
        NotificationService.instance.initialRoute = null; // consume it
        context.go(initialRoute);
        return;
      }

      if (role == EmployeeRole.superAdmin || role == EmployeeRole.hrAdmin) {
        context.go('/hr/dashboard');
      } else if (role == EmployeeRole.manager) {
        context.go('/manager/dashboard');
      } else if (role == EmployeeRole.teamLeader) {
        context.go('/team-leader/dashboard');
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
