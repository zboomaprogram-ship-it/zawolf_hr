import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/warning_reward_model.dart';
import '../../services/auth_service.dart';
import '../../services/warning_reward_service.dart';
import '../../theme/theme.dart';

class EmployeeWarningsRewardsScreen extends StatelessWidget {
  const EmployeeWarningsRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإنذارات والمكافآت',
          style: theme.textTheme.headlineMedium,
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
            return Center(
              child: Text(
                'لا توجد سجلات حتى الآن',
                style: theme.textTheme.titleMedium,
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
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
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
