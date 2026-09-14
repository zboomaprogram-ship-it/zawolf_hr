import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/payroll_run_model.dart';
import '../../services/auth_service.dart';
import '../../services/payroll_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

class EmployeePayrollScreen extends StatefulWidget {
  const EmployeePayrollScreen({super.key});

  @override
  State<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends State<EmployeePayrollScreen> {
  late String _monthKey;

  @override
  void initState() {
    super.initState();
    _monthKey = PayrollCycle.keyFor(DateTime.now());
  }

  void _changeMonth(int deltaMonths) {
    final parts = _monthKey.split('-');
    if (parts.length != 2) return;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final targetDate = DateTime(year, month + deltaMonths, 1);
    setState(() {
      _monthKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickMonth() async {
    final parts = _monthKey.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final month = int.tryParse(parts.last) ?? DateTime.now().month;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(year, month, 1),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _monthKey =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

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

    final cycle = PayrollCycle.forKey(_monthKey);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Scaffold(
            appBar: AppBar(
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: Icon(RtlNavigation.backIcon(context)),
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: ZaWolfColors.primaryCyan, size: 24),
                  const SizedBox(width: 8),
                  Text('مسير الراتب ومستحقاتي',
                      style: theme.textTheme.headlineMedium),
                ],
              ),
              actions: [
                _buildCycleSelector(isDesktop: isDesktop),
                const SizedBox(width: 12),
              ],
            ),
            body: StreamBuilder<PayrollRunModel?>(
              stream: PayrollService().watchMyPayroll(user.uid, _monthKey),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: SkeletonList(itemCount: 4, itemHeight: 110),
                  );
                }
                final run = snapshot.data;
                if (run == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: ZaWolfColors.primaryCyan
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_empty_rounded,
                              color: ZaWolfColors.textMuted,
                              size: 56,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'لم يتم إصدار أو احتساب مسير راتب لشهر $_monthKey بعد',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: ZaWolfColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'دورة الرواتب: ${cycle.arabicRangeLabel}',
                            style: const TextStyle(
                              color: ZaWolfColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (isDesktop) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Hero Net Salary and Summary Card
                        SizedBox(
                          width: 360,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroCard(run, cycle, isDesktop: true),
                              const SizedBox(height: 16),
                              _buildReviewMetadataCard(run),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right: Bento Breakdown Grid & Equation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBentoGrid(run, isDesktop: true),
                              const SizedBox(height: 20),
                              _buildEquationCard(run),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mobile Layout
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeroCard(run, cycle, isDesktop: false),
                    const SizedBox(height: 16),
                    _buildBentoGrid(run, isDesktop: false),
                    const SizedBox(height: 16),
                    _buildEquationCard(run),
                    if (run.reviewedBy != null || run.calculatedAt != null) ...[
                      const SizedBox(height: 16),
                      _buildReviewMetadataCard(run),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCycleSelector({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'الشهر السابق',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _changeMonth(-1),
          ),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month,
                      color: ZaWolfColors.primaryCyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _monthKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ZaWolfColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'الشهر التالي',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    PayrollRunModel run,
    PayrollCycle cycle, {
    required bool isDesktop,
  }) {
    final statusColor = run.status == PayrollStatus.locked
        ? ZaWolfColors.primaryCyan
        : run.status == PayrollStatus.reviewed
            ? ZaWolfColors.success
            : ZaWolfColors.warning;

    return WolfCard(
      hasBorderGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صافي المستحق للصرف',
                style: TextStyle(
                  color: ZaWolfColors.textSecondary,
                  fontSize: isDesktop ? 15 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      run.status == PayrollStatus.locked
                          ? Icons.lock_outline
                          : run.status == PayrollStatus.reviewed
                              ? Icons.check_circle_outline
                              : Icons.edit_note,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      PayrollStatus.arabicLabel(run.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
            style: TextStyle(
              fontSize: isDesktop ? 34 : 28,
              fontWeight: FontWeight.w900,
              color: ZaWolfColors.success,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface01,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_outlined,
                    size: 14, color: ZaWolfColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  cycle.arabicRangeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZaWolfColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(PayrollRunModel run, {required bool isDesktop}) {
    final items = [
      _BentoItem(
        title: 'الراتب الأساسي',
        amount: run.baseSalary,
        currency: run.currency,
        icon: Icons.account_balance_wallet_outlined,
        color: ZaWolfColors.primaryCyan,
        subtitle: 'الراتب التعاقدي المعتمد',
      ),
      _BentoItem(
        title: 'خصومات الحضور والغياب',
        amount: run.attendanceDeductions,
        currency: run.currency,
        icon: Icons.trending_down_rounded,
        color: ZaWolfColors.error,
        subtitle: '${run.approvedDeductionCount} خصم معتمد',
        isNegative: true,
      ),
      _BentoItem(
        title: 'المكافآت والحوافز',
        amount: run.rewardsBonus,
        currency: run.currency,
        icon: Icons.card_giftcard_outlined,
        color: ZaWolfColors.success,
        subtitle: '${run.bonusRecordCount} مكافأة معتمدة',
      ),
      _BentoItem(
        title: 'السلف المستردة',
        amount: run.advances,
        currency: run.currency,
        icon: Icons.money_off_rounded,
        color: ZaWolfColors.warning,
        subtitle: '${run.advanceRecordCount} سلفة مستقطعة',
        isNegative: true,
      ),
    ];

    if (isDesktop) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
        children: items.map((item) => _buildBentoCard(item)).toList(),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBentoCard(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBentoCard(_BentoItem item) {
    return WolfCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ZaWolfColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.isNegative && item.amount > 0 ? '-' : ''}${item.amount.toStringAsFixed(2)} ${item.currency}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ZaWolfColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquationCard(PayrollRunModel run) {
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calculate_outlined,
                  color: ZaWolfColors.primaryCyan, size: 18),
              SizedBox(width: 8),
              Text(
                'معادلة احتساب صافي الراتب',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: ZaWolfColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface01,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _equationPart(
                  label: 'الأساسي',
                  val: run.baseSalary.toStringAsFixed(2),
                  color: ZaWolfColors.textPrimary,
                ),
                const Text('+',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ZaWolfColors.textMuted)),
                _equationPart(
                  label: 'المكافآت',
                  val: run.rewardsBonus.toStringAsFixed(2),
                  color: ZaWolfColors.success,
                ),
                const Text('-',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ZaWolfColors.textMuted)),
                _equationPart(
                  label: 'الخصومات',
                  val: run.attendanceDeductions.toStringAsFixed(2),
                  color: ZaWolfColors.error,
                ),
                const Text('-',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ZaWolfColors.textMuted)),
                _equationPart(
                  label: 'السلف',
                  val: run.advances.toStringAsFixed(2),
                  color: ZaWolfColors.warning,
                ),
                const Text('=',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ZaWolfColors.primaryCyan)),
                _equationPart(
                  label: 'الصافي',
                  val: '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                  color: ZaWolfColors.primaryCyan,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _equationPart({
    required String label,
    required String val,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: ZaWolfColors.textMuted),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewMetadataCard(PayrollRunModel run) {
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline,
                  size: 16, color: ZaWolfColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'بيانات التدقيق والاعتماد',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: ZaWolfColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (run.calculatedAt != null)
            _metaRow(
              'تاريخ الحساب',
              '${run.calculatedAt!.year}-${run.calculatedAt!.month.toString().padLeft(2, '0')}-${run.calculatedAt!.day.toString().padLeft(2, '0')}',
            ),
          if (run.calculatedBy.isNotEmpty)
            _metaRow('تم الحساب بواسطة', run.calculatedBy),
          if (run.reviewedBy != null && run.reviewedBy!.isNotEmpty)
            _metaRow('تمت المراجعة والاعتماد بواسطة', run.reviewedBy!),
          if (run.reviewedAt != null)
            _metaRow(
              'تاريخ الاعتماد',
              '${run.reviewedAt!.year}-${run.reviewedAt!.month.toString().padLeft(2, '0')}-${run.reviewedAt!.day.toString().padLeft(2, '0')}',
            ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: ZaWolfColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BentoItem {
  final String title;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isNegative;

  const _BentoItem({
    required this.title,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.isNegative = false,
  });
}

