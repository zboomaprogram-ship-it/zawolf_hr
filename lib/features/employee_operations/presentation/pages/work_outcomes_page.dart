import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
import '../../domain/entities/work_outcome.dart';
import '../../domain/repositories/work_outcome_repository.dart';
import '../cubit/work_outcome_cubit.dart';

enum WorkOutcomesPageMode { employee, manager }

final class WorkOutcomesPage extends StatelessWidget {
  const WorkOutcomesPage({
    required this.actorUserId,
    required this.repository,
    this.mode = WorkOutcomesPageMode.employee,
    super.key,
  });

  final String actorUserId;
  final WorkOutcomeRepository repository;
  final WorkOutcomesPageMode mode;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = WorkOutcomeCubit(repository);
      if (mode == WorkOutcomesPageMode.employee) {
        cubit.watchEmployee(actorUserId);
      } else {
        cubit.watchOwned(actorUserId);
      }
      return cubit;
    },
    child: _WorkOutcomesView(mode: mode),
  );
}

final class _WorkOutcomesView extends StatelessWidget {
  const _WorkOutcomesView({required this.mode});

  final WorkOutcomesPageMode mode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        mode == WorkOutcomesPageMode.employee
            ? 'نتائج عملي'
            : 'نتائج عمل الفريق',
      ),
    ),
    body: BlocConsumer<WorkOutcomeCubit, WorkOutcomeState>(
      listenWhen: (previous, current) =>
          previous.messageAr != current.messageAr && current.messageAr != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.messageAr!)));
      },
      builder: (context, state) => switch (state.status) {
        WorkOutcomeViewStatus.initial || WorkOutcomeViewStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        WorkOutcomeViewStatus.empty => const _Message(
          icon: Icons.track_changes,
          text: 'لا توجد نتائج عمل مسندة حالياً.',
        ),
        WorkOutcomeViewStatus.failure when state.items.isEmpty =>
          const _Message(
            icon: Icons.cloud_off_outlined,
            text: 'تعذر تحميل نتائج العمل الآن. حاول مرة أخرى.',
          ),
        _ => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _OutcomeCard(
            outcome: state.items[index],
            editable: mode == WorkOutcomesPageMode.employee,
            busy: state.status == WorkOutcomeViewStatus.updating,
          ),
        ),
      },
    ),
  );
}

final class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.outcome,
    required this.editable,
    required this.busy,
  });

  final WorkOutcome outcome;
  final bool editable;
  final bool busy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(outcome.titleAr, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: outcome.progressRatio),
          const SizedBox(height: 8),
          Text(
            '${_number(outcome.progressValue)} من ${_number(outcome.targetValue)}',
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            'الموعد: ${DateFormat('yyyy/MM/dd').format(outcome.dueDate)} · الحالة: ${_statusAr(outcome.status)}',
            style: const TextStyle(color: ZaWolfColors.textMuted),
          ),
          if (outcome.evidenceReference?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            SelectableText('الدليل: ${outcome.evidenceReference}'),
          ],
          if (editable && !outcome.isComplete) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تحديث التقدم'),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<({double value, String? evidence})>(
      context: context,
      builder: (_) => _ProgressDialog(outcome: outcome),
    );
    if (result == null || !context.mounted) return;
    await context.read<WorkOutcomeCubit>().updateProgress(
      outcome: outcome,
      value: result.value,
      evidenceReference: result.evidence,
    );
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static String _statusAr(WorkOutcomeStatus status) => switch (status) {
    WorkOutcomeStatus.planned => 'مخطط',
    WorkOutcomeStatus.inProgress => 'قيد التنفيذ',
    WorkOutcomeStatus.submitted => 'مرسل للمراجعة',
    WorkOutcomeStatus.accepted => 'معتمد',
    WorkOutcomeStatus.returned => 'معاد للتعديل',
    WorkOutcomeStatus.cancelled => 'ملغي',
  };
}

final class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.outcome});

  final WorkOutcome outcome;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

final class _ProgressDialogState extends State<_ProgressDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _evidenceController;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: '${widget.outcome.progressValue}',
    );
    _evidenceController = TextEditingController(
      text: widget.outcome.evidenceReference,
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تحديث التقدم'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('work-outcome-progress'),
          controller: _valueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'القيمة حتى ${widget.outcome.targetValue}',
          ),
        ),
        TextField(
          controller: _evidenceController,
          decoration: const InputDecoration(
            labelText: 'رابط أو مرجع الدليل (اختياري)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        key: const Key('save-work-outcome-progress'),
        onPressed: () {
          final value = double.tryParse(_valueController.text.trim());
          if (value == null) return;
          final evidence = _evidenceController.text.trim();
          Navigator.pop(context, (
            value: value,
            evidence: evidence.isEmpty ? null : evidence,
          ));
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

final class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 48), const SizedBox(height: 12), Text(text)],
    ),
  );
}
