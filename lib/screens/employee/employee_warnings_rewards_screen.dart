import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../components/wolf_card.dart';
import '../../models/warning_reward_model.dart';
import '../../services/auth_service.dart';
import '../../services/warning_reward_service.dart';
import '../../theme/theme.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

class EmployeeWarningsRewardsScreen extends StatelessWidget {
  const EmployeeWarningsRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (user == null) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 5, itemHeight: 84),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'سجل الإنذارات والمكافآت',
            style: theme.textTheme.headlineMedium,
          ),
        ),
      ),
      body: StreamBuilder<List<WarningRewardModel>>(
        stream: WarningRewardService().watchMyRecords(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final records = snapshot.data ?? [];
          final visible = records
              .where((record) => record.status != WarningRewardStatus.suggested)
              .toList();
          if (visible.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: ZaWolfColors.success,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'سجل وظيفي منضبط ونظيف 🌟',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: ZaWolfColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'لا توجد أي إنذارات أو مخالفات مسجلة في ملفك. التزامك وحسن أدائك محل تقدير إدارة الشركة!',
                        style: TextStyle(
                          color: ZaWolfColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      WolfCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'سجلاتك التشغيلية الأخرى في النظام:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.assignment_outlined,
                                    color: ZaWolfColors.primaryCyan, size: 20),
                              ),
                              title: const Text('سجل الطلبات والإجازات'),
                              subtitle: const Text(
                                  'متابعة حالة الإجازات والأذونات والسلف'),
                              trailing: const Icon(Icons.chevron_left,
                                  color: ZaWolfColors.textMuted,
                                  textDirection: TextDirection.ltr),
                              onTap: () => context.push('/employee/requests'),
                            ),
                            const Divider(color: ZaWolfColors.surface03),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.warning
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.money_off_csred_outlined,
                                    color: ZaWolfColors.warning, size: 20),
                              ),
                              title: const Text('سجل الخصومات والتأخيرات'),
                              subtitle:
                                  const Text('سجل الخصومات التلقائية واليدوية'),
                              trailing: const Icon(Icons.chevron_left,
                                  color: ZaWolfColors.textMuted,
                                  textDirection: TextDirection.ltr),
                              onTap: () =>
                                  context.push('/employee/deductions'),
                            ),
                            const Divider(color: ZaWolfColors.surface03),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.dayoffPurple
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.task_alt_outlined,
                                    color: ZaWolfColors.dayoffPurple,
                                    size: 20),
                              ),
                              title: const Text('سجل المهام والأداء'),
                              subtitle:
                                  const Text('متابعة المهام المنجزة والجارية'),
                              trailing: const Icon(Icons.chevron_left,
                                  color: ZaWolfColors.textMuted,
                                  textDirection: TextDirection.ltr),
                              onTap: () => context.push('/employee/tasks'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: visible
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EmployeeRecordCard(
                      record: record,
                      userId: user.uid,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _EmployeeRecordCard extends StatelessWidget {
  final WarningRewardModel record;
  final String userId;

  const _EmployeeRecordCard({required this.record, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _recordColor(record.type);
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(
                text: WarningRewardStatus.arabicLabel(record.status),
                color: color,
              ),
              const Spacer(),
              Text(
                WarningRewardType.arabicLabel(record.type),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: ZaWolfColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(record.description, textDirection: TextDirection.rtl),
          if (record.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('yyyy/MM/dd').format(record.createdAt!),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          ],
          if (record.status == WarningRewardStatus.issued) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  WarningRewardService().acknowledge(record.recordId, userId),
              icon: const Icon(Icons.visibility),
              label: const Text('تم الاطلاع'),
            ),
          ],
        ],
      ),
    );
  }

  Color _recordColor(String type) {
    switch (type) {
      case WarningRewardType.reward:
      case WarningRewardType.bonusRecommendation:
        return ZaWolfColors.success;
      case WarningRewardType.followUp:
        return ZaWolfColors.warning;
      case WarningRewardType.notice:
        return ZaWolfColors.primaryBlue;
      default:
        return ZaWolfColors.error;
    }
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
