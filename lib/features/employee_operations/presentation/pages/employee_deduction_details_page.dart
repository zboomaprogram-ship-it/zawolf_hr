import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../components/wolf_card.dart';
import '../../../../theme/theme.dart';
import '../../domain/entities/attendance_correction_draft.dart';
import '../../domain/entities/deduction_explanation.dart';
import '../../domain/repositories/employee_operations_repository.dart';
import '../cubit/attendance_correction_cubit.dart';
import '../cubit/deduction_details_cubit.dart';
import '../widgets/late_correction_shortcut.dart';

/// Flagged replacement for the legacy employee deduction list. The employee
/// identity is injected by the composition root and cannot be selected here.
final class EmployeeDeductionDetailsPage extends StatefulWidget {
  const EmployeeDeductionDetailsPage({
    required this.employeeUserId,
    required this.repository,
    this.initialCycleKey,
    super.key,
  });

  final String employeeUserId;
  final EmployeeOperationsRepository repository;
  final String? initialCycleKey;

  @override
  State<EmployeeDeductionDetailsPage> createState() =>
      _EmployeeDeductionDetailsPageState();
}

final class _EmployeeDeductionDetailsPageState
    extends State<EmployeeDeductionDetailsPage> {
  late final DeductionDetailsCubit _detailsCubit;
  late final AttendanceCorrectionCubit _correctionCubit;
  late DateTime _cycleDate;

  String get _cycleKey =>
      '${_cycleDate.year.toString().padLeft(4, '0')}-${_cycleDate.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _cycleDate = _parseCycle(widget.initialCycleKey) ?? DateTime.now();
    _detailsCubit = DeductionDetailsCubit(widget.repository);
    _correctionCubit = AttendanceCorrectionCubit(widget.repository);
    _watch();
  }

  @override
  void dispose() {
    _detailsCubit.close();
    _correctionCubit.close();
    super.dispose();
  }

  void _watch() => _detailsCubit.watch(
    employeeUserId: widget.employeeUserId,
    effectiveCycleKey: _cycleKey,
  );

  void _moveCycle(int months) {
    setState(() {
      _cycleDate = DateTime(_cycleDate.year, _cycleDate.month + months, 1);
    });
    _watch();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _detailsCubit),
        BlocProvider.value(value: _correctionCubit),
      ],
      child: BlocListener<AttendanceCorrectionCubit, AttendanceCorrectionState>(
        listener: (context, state) {
          final message = switch (state.status) {
            AttendanceCorrectionStatus.submitted =>
              'تم إرسال طلب التصحيح بنجاح.',
            AttendanceCorrectionStatus.pending =>
              'الطلب مسجل مسبقاً وقيد المراجعة.',
            AttendanceCorrectionStatus.checkStatus =>
              'تعذر تأكيد النتيجة الآن. راجع حالة طلباتك قبل إعادة الإرسال.',
            _ => null,
          };
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('تفاصيل خصوماتي')),
          body: BlocBuilder<DeductionDetailsCubit, DeductionDetailsState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CycleSelector(
                  cycleKey: _cycleKey,
                  onPrevious: () => _moveCycle(-1),
                  onNext: () => _moveCycle(1),
                ),
                const SizedBox(height: 16),
                switch (state.status) {
                  DeductionDetailsStatus.initial ||
                  DeductionDetailsStatus.loading => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  DeductionDetailsStatus.failure => _StateMessage(
                    icon: Icons.cloud_off_outlined,
                    message: 'تعذر تحميل الخصوم مؤقتاً. أعد المحاولة.',
                    actionLabel: 'إعادة المحاولة',
                    onAction: _watch,
                  ),
                  DeductionDetailsStatus.empty => const _StateMessage(
                    icon: Icons.verified_outlined,
                    message: 'لا توجد خصوم مسجلة في هذه الدورة.',
                  ),
                  DeductionDetailsStatus.ready => Column(
                    children: [
                      for (final item in state.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DeductionCard(
                            item: item,
                            onCorrection: () => _openCorrection(item),
                          ),
                        ),
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCorrection(DeductionExplanation item) async {
    final original = item.originalCheckIn;
    if (original == null) return;
    final reasonController = TextEditingController();
    final timeController = TextEditingController(
      text: DateFormat('HH:mm').format(original),
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب تصحيح وقت الحضور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('correction-time'),
              controller: timeController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'الوقت الصحيح (HH:mm)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('correction-reason'),
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'سبب التصحيح'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('submit-correction'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      return;
    }
    try {
      final parts = timeController.text.trim().split(':');
      if (parts.length != 2) throw const FormatException();
      final requested = DateTime(
        original.year,
        original.month,
        original.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final draft = AttendanceCorrectionDraft.create(
        attendanceId: item.attendanceId,
        originalCheckIn: original,
        requestedCheckIn: requested,
        reason: reasonController.text,
        operationId:
            'attendance-correction:${item.attendanceId}:${requested.toUtc().millisecondsSinceEpoch}',
      );
      await _correctionCubit.submit(
        employeeUserId: widget.employeeUserId,
        draft: draft,
      );
    } on FormatException {
      _showValidation('اكتب الوقت بالصيغة HH:mm.');
    } on ArgumentError catch (error) {
      _showValidation(error.message?.toString() ?? 'راجع بيانات الطلب.');
    }
  }

  void _showValidation(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static DateTime? _parseCycle(String? value) {
    final parts = value?.split('-');
    if (parts == null || parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }
}

final class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycleKey,
    required this.onPrevious,
    required this.onNext,
  });

  final String cycleKey;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => WolfCard(
    child: Directionality(
      textDirection: TextDirection.rtl,
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
                const Text('دورة الخصم حسب تاريخ الحدث'),
                SelectableText(
                  cycleKey,
                  key: const ValueKey('effective-cycle-key'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
    ),
  );
}

final class _DeductionCard extends StatelessWidget {
  const _DeductionCard({required this.item, required this.onCorrection});

  final DeductionExplanation item;
  final VoidCallback onCorrection;

  @override
  Widget build(BuildContext context) => WolfCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StatusChip(status: item.status),
            const Spacer(),
            Text(_fractionLabel(item.fraction)),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          item.reasonAr,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        SelectableText(
          '${item.sourceLabelAr} · ${DateFormat('d MMMM yyyy', 'ar').format(item.effectiveDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SelectableText('دورة الاستحقاق: ${item.effectiveCycleKey}'),
        if (item.amount != null)
          SelectableText(
            'قيمة الخصم: ${item.amount!.toStringAsFixed(2)} ${item.currency ?? ''}',
          ),
        if (item.reviewedAt != null)
          SelectableText(
            'تاريخ المراجعة: ${DateFormat('d MMMM yyyy', 'ar').format(item.reviewedAt!)}',
          ),
        const SizedBox(height: 8),
        LateCorrectionShortcut(explanation: item, onPressed: onCorrection),
      ],
    ),
  );

  static String _fractionLabel(double fraction) {
    final value = fraction == fraction.roundToDouble()
        ? fraction.toInt().toString()
        : fraction.toStringAsFixed(2);
    return '$value يوم';
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DeductionReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DeductionReviewStatus.approved => ('معتمد', ZaWolfColors.error),
      DeductionReviewStatus.rejected => ('مرفوض', ZaWolfColors.success),
      DeductionReviewStatus.cancelled => ('ملغى', ZaWolfColors.success),
      DeductionReviewStatus.pending => ('قيد المراجعة', ZaWolfColors.warning),
    };
    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
    );
  }
}

final class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 42, color: ZaWolfColors.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onAction != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
