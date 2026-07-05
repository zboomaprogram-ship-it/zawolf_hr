import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _employeesCount = 0;
  int _locationsCount = 0;
  bool _loadingCounts = true;

  @override
  void initState() {
    super.initState();
    _fetchSummaryCounts();
  }

  Future<void> _fetchSummaryCounts() async {
    try {
      final results = await Future.wait([
        _db.collection('users').get(),
        _db.collection('locations').where('isActive', isEqualTo: true).get(),
      ]);

      if (mounted) {
        setState(() {
          _employeesCount = results[0].docs.length;
          _locationsCount = results[1].docs.length;
          _loadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCounts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hrAdmin = authService.currentUser;
    final theme = Theme.of(context);

    if (hrAdmin == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة الموارد البشرية (HR)',
          style: theme.textTheme.headlineMedium,
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZaWolfColors.surface03),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/wolf_head_geometric.png',
                    width: 46,
                    height: 46,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'مرحباً، ${hrAdmin.displayName}',
                          style: theme.textTheme.headlineSmall!.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                        Text(
                          'التحكم العام بالمنظومة · ${hrAdmin.locationName}',
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Counts Grid Overview
            if (!_loadingCounts)
              Row(
                children: [
                  Expanded(
                    child: _buildCountCard(
                      'إجمالي الفروع النشطة',
                      _locationsCount.toString(),
                      Icons.domain,
                      theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCountCard(
                      'إجمالي الموظفين',
                      _employeesCount.toString(),
                      Icons.people_alt_outlined,
                      theme,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // HR Administrative Quick Actions Grid
            Text(
              'عمليات الموارد البشرية المتاحة',
              style: theme.textTheme.titleLarge!.copyWith(color: Colors.white),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildHRActionCard(
                  'إدارة الموظفين',
                  'إضافة موظف وتعديل بياناته وصلاحياته',
                  Icons.person_add_alt_1,
                  () => context.go('/hr/employees'),
                  theme,
                ),
                _buildHRActionCard(
                  'إدارة الفروع والمواقع',
                  'تحديد النطاقات الجغرافية ومطابقة الحضور',
                  Icons.map_outlined,
                  () => context.go('/hr/locations'),
                  theme,
                ),
                _buildHRActionCard(
                  'تصدير التقارير',
                  'تصدير الحضور والإجازات مباشرة لـ Google Sheets',
                  Icons.file_download_outlined,
                  () => context.go('/hr/reports'),
                  theme,
                ),
                _buildHRActionCard(
                  'بث الإعلانات العامة',
                  'نشر إشعار إداري لجميع موظفي المنظومة',
                  Icons.campaign_outlined,
                  () => context.go('/hr/announcements'),
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCard(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHRActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return WolfCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall!.copyWith(
              fontSize: 10,
              color: ZaWolfColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
