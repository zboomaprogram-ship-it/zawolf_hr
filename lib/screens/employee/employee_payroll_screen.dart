import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/payroll_run_model.dart';
import '../../services/auth_service.dart';
import '../../services/payroll_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class EmployeePayrollScreen extends StatelessWidget {
  const EmployeePayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final monthKey = PayrollCycle.keyFor(DateTime.now());
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
        title: Text('راتبي', style: theme.textTheme.headlineMedium),
      ),
      body: StreamBuilder<PayrollRunModel?>(
        stream: PayrollService().watchMyPayroll(user.uid, monthKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final run = snapshot.data;
          if (run == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لم يتم إصدار ملخص راتب شهر $monthKey بعد',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WolfCard(
                hasBorderGlow: true,
                child: Column(
                  children: [
                    Text('صافي الراتب', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: ZaWolfColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(PayrollStatus.arabicLabel(run.status)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PayrollLine(
                label: 'الراتب الأساسي',
                value: run.baseSalary,
                currency: run.currency,
                color: Colors.white,
              ),
              _PayrollLine(
                label: 'خصومات الحضور المعتمدة',
                value: run.attendanceDeductions,
                currency: run.currency,
                color: ZaWolfColors.error,
              ),
              _PayrollLine(
                label: 'المكافآت والبونص',
                value: run.rewardsBonus,
                currency: run.currency,
                color: ZaWolfColors.success,
              ),
              WolfCard(
                child: Column(
                  children: [
                    _MetricLine(
                      label: 'عدد الخصومات',
                      value: '${run.approvedDeductionCount}',
                    ),
                    _MetricLine(
                      label: 'عدد سجلات المكافأة',
                      value: '${run.bonusRecordCount}',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayrollLine extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;

  const _PayrollLine({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WolfCard(
        child: Row(
          children: [
            Text(
              '${value.toStringAsFixed(2)} $currency',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(color: ZaWolfColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(value, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: ZaWolfColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
