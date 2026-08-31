import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/financial_ledger_entry.dart';
import '../../domain/repositories/finance_repository.dart';

sealed class FinanceLedgerState {
  const FinanceLedgerState();
}

final class FinanceLedgerLoading extends FinanceLedgerState {
  const FinanceLedgerLoading();
}

final class FinanceLedgerReady extends FinanceLedgerState {
  const FinanceLedgerReady(this.items);
  final List<FinancialLedgerEntry> items;
}

final class FinanceLedgerFailure extends FinanceLedgerState {
  const FinanceLedgerFailure(this.message);
  final String message;
}

final class FinanceLedgerCubit extends Cubit<FinanceLedgerState> {
  FinanceLedgerCubit(this._repository) : super(const FinanceLedgerLoading());
  final FinanceRepository _repository;

  Future<void> load({
    required DateTime from,
    required DateTime to,
    String? employeeUid,
  }) async {
    emit(const FinanceLedgerLoading());
    try {
      final page = await _repository.ledger(
        from: from,
        to: to,
        employeeUid: employeeUid,
      );
      emit(FinanceLedgerReady(page.items));
    } catch (_) {
      emit(const FinanceLedgerFailure('تعذر تحميل السجل المالي حالياً.'));
    }
  }
}
