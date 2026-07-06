import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/user_model.dart';
import '../../models/warning_reward_model.dart';
import '../../services/auth_service.dart';
import '../../services/warning_reward_service.dart';
import '../../theme/theme.dart';

class WarningsRewardsManagementScreen extends StatefulWidget {
  const WarningsRewardsManagementScreen({super.key});

  @override
  State<WarningsRewardsManagementScreen> createState() =>
      _WarningsRewardsManagementScreenState();
}

class _WarningsRewardsManagementScreenState
    extends State<WarningsRewardsManagementScreen> {
  final WarningRewardService _service = WarningRewardService();
  final String _monthKey = DateFormat('yyyy-MM').format(DateTime.now());
  bool _generating = false;

  Future<void> _generate(UserModel reviewer) async {
    setState(() => _generating = true);
    try {
      final count = await _service.generateSuggestions(
        reviewer: reviewer,
        monthKey: _monthKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم إنشاء $count اقتراح جديد.')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (reviewer == null) {
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
        actions: [
          IconButton(
            tooltip: 'اقتراحات تلقائية',
            onPressed: _generating ? null : () => _generate(reviewer),
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, color: ZaWolfColors.perfGold),
          ),
          IconButton(
            tooltip: 'إضافة سجل',
            onPressed: () => _showCreateSheet(context, reviewer),
            icon: const Icon(Icons.add, color: ZaWolfColors.primaryCyan),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, reviewer),
        backgroundColor: ZaWolfColors.primaryCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('سجل جديد'),
      ),
      body: StreamBuilder<List<WarningRewardModel>>(
        stream: _service.watchManagedRecords(reviewer),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return Center(
              child: Text(
                'لا توجد إنذارات أو مكافآت بعد',
                style: theme.textTheme.titleMedium,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: records
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ManagerRecordCard(
                      record: record,
                      reviewer: reviewer,
                      service: _service,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, UserModel reviewer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _CreateRecordSheet(reviewer: reviewer, service: _service),
    );
  }
}

class _ManagerRecordCard extends StatelessWidget {
  final WarningRewardModel record;
  final UserModel reviewer;
  final WarningRewardService service;

  const _ManagerRecordCard({
    required this.record,
    required this.reviewer,
    required this.service,
  });

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
              if (record.source == 'productivity_auto') ...[
                const SizedBox(width: 8),
                const _Chip(text: 'تلقائي', color: ZaWolfColors.perfGold),
              ],
              const Spacer(),
              Text(
                record.employeeName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.title,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(record.description, textDirection: TextDirection.rtl),
          if (record.productivityScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Productivity: ${record.productivityScore!.toStringAsFixed(1)}%',
              style: const TextStyle(color: ZaWolfColors.primaryCyan),
              textAlign: TextAlign.right,
            ),
          ],
          if (record.amount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'القيمة: ${record.amount.toStringAsFixed(2)} ${record.currency}',
              style: const TextStyle(color: ZaWolfColors.success),
              textAlign: TextAlign.right,
            ),
          ],
          if (record.status == WarningRewardStatus.suggested) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        service.dismissSuggestion(record.recordId, reviewer),
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        service.issueSuggestedRecord(record.recordId, reviewer),
                    icon: const Icon(Icons.check),
                    label: const Text('إصدار'),
                  ),
                ),
              ],
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
      default:
        return ZaWolfColors.error;
    }
  }
}

class _CreateRecordSheet extends StatefulWidget {
  final UserModel reviewer;
  final WarningRewardService service;

  const _CreateRecordSheet({required this.reviewer, required this.service});

  @override
  State<_CreateRecordSheet> createState() => _CreateRecordSheetState();
}

class _CreateRecordSheetState extends State<_CreateRecordSheet> {
  late final Future<List<UserModel>> _employeesFuture;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController(text: '0');
  UserModel? _employee;
  String _type = WarningRewardType.followUp;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.service.loadAssignableEmployees(widget.reviewer);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سجل إداري جديد',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<UserModel>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                final employees = snapshot.data ?? [];
                return DropdownButtonFormField<UserModel>(
                  initialValue: _employee,
                  decoration: const InputDecoration(labelText: 'الموظف'),
                  items: employees
                      .map(
                        (user) => DropdownMenuItem(
                          value: user,
                          child: Text(
                            '${user.displayName} · ${user.department}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _employee = value),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: const [
                DropdownMenuItem(
                  value: WarningRewardType.warning,
                  child: Text('إنذار'),
                ),
                DropdownMenuItem(
                  value: WarningRewardType.followUp,
                  child: Text('متابعة'),
                ),
                DropdownMenuItem(
                  value: WarningRewardType.reward,
                  child: Text('مكافأة'),
                ),
                DropdownMenuItem(
                  value: WarningRewardType.bonusRecommendation,
                  child: Text('ترشيح بونص'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            WolfInputField(controller: _title, labelText: 'العنوان'),
            const SizedBox(height: 12),
            WolfInputField(
              controller: _description,
              labelText: 'التفاصيل',
              maxLines: 3,
            ),
            if (_type == WarningRewardType.reward ||
                _type == WarningRewardType.bonusRecommendation) ...[
              const SizedBox(height: 12),
              WolfInputField(
                controller: _amount,
                labelText: 'قيمة المكافأة',
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ وإرسال'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final employee = _employee;
    if (employee == null || _title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الموظف واكتب عنواناً واضحاً.')),
      );
      return;
    }
    await widget.service.createRecord(
      creator: widget.reviewer,
      employee: employee,
      type: _type,
      title: _title.text,
      description: _description.text,
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      currency: employee.salaryCurrency,
    );
    if (mounted) Navigator.pop(context);
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
