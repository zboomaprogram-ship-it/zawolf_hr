import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/finance_repository.dart';
import '../cubit/finance_ledger_cubit.dart';
import '../cubit/payslip_cubit.dart';

class EmployeeFinancePage extends StatelessWidget {
  const EmployeeFinancePage({super.key, required this.repository});
  final FinanceRepository repository;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              FinanceLedgerCubit(repository)
                ..load(from: DateTime(now.year, now.month, 1), to: now),
        ),
        BlocProvider(
          create: (_) => PayslipCubit(repository)..load(period: period),
        ),
      ],
      child: const _FinanceView(),
    );
  }
}

class _FinanceView extends StatelessWidget {
  const _FinanceView();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('السجل المالي')),
      body: Column(
        children: [
          const _PayslipCard(),
          Expanded(
            child: BlocBuilder<FinanceLedgerCubit, FinanceLedgerState>(
              builder: (context, state) => switch (state) {
                FinanceLedgerLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                FinanceLedgerFailure(:final message) => Center(
                  child: Text(message),
                ),
                FinanceLedgerReady(items: final items) when items.isEmpty =>
                  const Center(
                    child: Text('لا توجد حركات مالية في هذه الفترة.'),
                  ),
                FinanceLedgerReady(items: final items) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.description),
                      subtitle: Text(
                        '${item.effectiveDate.toLocal().toIso8601String().split('T').first} · ${item.status}',
                      ),
                      trailing: Text('${item.amount} ${item.currency}'),
                    );
                  },
                ),
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard();

  @override
  Widget build(BuildContext context) => BlocBuilder<PayslipCubit, PayslipState>(
    builder: (context, state) => switch (state) {
      PayslipLoading() => const LinearProgressIndicator(),
      PayslipFailure(:final message) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
      PayslipReady(payslip: null) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('لا توجد قسيمة راتب منشورة لهذه الفترة.'),
      ),
      PayslipReady(payslip: final payslip?) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('قسيمة راتب ${payslip.period}'),
              const SizedBox(height: 8),
              Text('الإجمالي: ${payslip.gross} ${payslip.currency}'),
              Text('الخصومات: ${payslip.deductions} ${payslip.currency}'),
              Text('الصافي: ${payslip.net} ${payslip.currency}'),
            ],
          ),
        ),
      ),
    },
  );
}
