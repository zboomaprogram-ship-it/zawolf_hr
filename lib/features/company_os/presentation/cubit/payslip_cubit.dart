import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/payslip_summary.dart';
import '../../domain/repositories/finance_repository.dart';

sealed class PayslipState {
  const PayslipState();
}

final class PayslipLoading extends PayslipState {
  const PayslipLoading();
}

final class PayslipReady extends PayslipState {
  const PayslipReady(this.payslip);
  final PayslipSummary? payslip;
}

final class PayslipFailure extends PayslipState {
  const PayslipFailure(this.message);
  final String message;
}

final class PayslipCubit extends Cubit<PayslipState> {
  PayslipCubit(this._repository) : super(const PayslipLoading());
  final FinanceRepository _repository;

  Future<void> load({required String period, String? employeeUid}) async {
    emit(const PayslipLoading());
    try {
      emit(
        PayslipReady(
          await _repository.payslip(period: period, employeeUid: employeeUid),
        ),
      );
    } catch (_) {
      emit(const PayslipFailure('تعذر تحميل قسيمة الراتب حالياً.'));
    }
  }
}
