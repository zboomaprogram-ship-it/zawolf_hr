import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';
import '../components/wolf_card.dart';
import '../components/wolf_button.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final Widget? bottomNavigationBar;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: ZaWolfColors.error),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [ZaWolfColors.wolfGlow],
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/wolf_head_geometric.png'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '🐺 ZaWolf HR — $title',
                style: theme.textTheme.headlineMedium!.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (user != null)
                WolfCard(
                  hasBorderGlow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Profile Info:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Divider(color: ZaWolfColors.surface02),
                      Text('Name: ${user.displayName}'),
                      Text('Email: ${user.email}'),
                      Text('Role: ${user.role}'),
                      Text('Employee ID: ${user.employeeId}'),
                      Text('Location: ${user.locationName}'),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              WolfButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Feature coming in subsequent Phase execution',
                      ),
                    ),
                  );
                },
                text: 'إجراء افتراضي',
                secondaryText: 'DEFAULT ACTION',
                variant: WolfButtonVariant.outline,
                width: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
