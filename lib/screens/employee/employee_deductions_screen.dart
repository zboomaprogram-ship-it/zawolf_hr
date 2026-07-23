import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../services/auth_service.dart';
import '../../services/employee_deduction_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class EmployeeDeductionsScreen extends StatefulWidget {
  const EmployeeDeductionsScreen({super.key});

  @override
  State<EmployeeDeductionsScreen> createState() =>
      _EmployeeDeductionsScreenState();
}

class _EmployeeDeductionsScreenState extends State<EmployeeDeductionsScreen> {
  final EmployeeDeductionService _service = EmployeeDeductionService();
  late DateTime _cycleDate;

  @override
  void initState() {
    super.initState();
    _cycleDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final cycle = PayrollCycle.forDate(_cycleDate);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('خصوماتي')),
      body: StreamBuilder<List<EmployeeDeductionEntry>>(
        stream: _service.watchForCycle(userId: user.uid, monthKey: cycle.key),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.cloud_off_outlined,
              text: 'تعذر تحميل الخصومات. أعد المحاولة.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }

          final entries = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CycleSelector(
                cycle: cycle,
                onPrevious: () => setState(
                  () => _cycleDate = DateTime(
                    _cycleDate.year,
                    _cycleDate.month - 1,
                    15,
                  ),
                ),
                onNext: () => setState(
                  () => _cycleDate = DateTime(
                    _cycleDate.year,
                    _cycleDate.month + 1,
                    15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Summary(entries: entries),
              const SizedBox(height: 18),
              Text(
                'تفاصيل الخصومات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const _Message(
                  icon: Icons.verified_outlined,
                  text: 'لا توجد خصومات مسجلة في هذه الدورة.',
                )
              else
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeductionTile(entry: entry),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycle,
    required this.onPrevious,
    required this.onNext,
  });

  final PayrollCycle cycle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      child: Row(
        children: [
          IconButton(
            tooltip: 'الدورة السابقة',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'دورة ${cycle.key}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(cycle.arabicRangeLabel, textAlign: TextAlign.center),
              ],
            ),
          ),
          IconButton(
            tooltip: 'الدورة التالية',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.entries});

  final List<EmployeeDeductionEntry> entries;

  @override
  Widget build(BuildContext context) {
    double totalFor(String status) => entries
        .where((item) => item.approvalStatus == status)
        .fold(0, (sum, item) => sum + item.dayFraction);

    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            label: 'ألغاه HR',
            value: _days(totalFor('rejected')),
            color: ZaWolfColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryItem(
            label: 'قيد المراجعة',
            value: _days(totalFor('pending_hr')),
            color: ZaWolfColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryItem(
            label: 'معتمد',
            value: _days(totalFor('approved')),
            color: ZaWolfColors.error,
          ),
        ),
      ],
    );
  }

  String _days(double value) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '$text يوم';
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DeductionTile extends StatelessWidget {
  const _DeductionTile({required this.entry});

  final EmployeeDeductionEntry entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (entry.approvalStatus) {
      'approved' => ZaWolfColors.error,
      'rejected' => ZaWolfColors.success,
      _ => ZaWolfColors.warning,
    };
    final parsedDate = DateTime.tryParse(entry.date);

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  entry.approvalLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                entry.fractionLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(entry.reasonLabel, textAlign: TextAlign.right),
          const SizedBox(height: 6),
          Text(
            '${entry.sourceLabel} · ${parsedDate == null ? entry.date : DateFormat('d MMMM yyyy', 'ar').format(parsedDate)}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: ZaWolfColors.textSecondary),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
