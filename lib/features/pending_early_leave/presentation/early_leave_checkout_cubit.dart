import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/user_model.dart';
import '../domain/early_leave_checkout_repository.dart';
import 'early_leave_checkout_state.dart';

final class EarlyLeaveCheckoutCubit extends Cubit<EarlyLeaveCheckoutState> {
  EarlyLeaveCheckoutCubit(this._repository)
    : super(const EarlyLeaveCheckoutState());

  final EarlyLeaveCheckoutRepository _repository;
  StreamSubscription<Object?>? _subscription;
  String? _scope;

  Future<void> watch(UserModel employee) async {
    final now = DateTime.now();
    final scope = '${employee.uid}:${now.year}-${now.month}-${now.day}';
    if (_scope == scope && _subscription != null) return;
    _scope = scope;
    await _subscription?.cancel();
    emit(state.copyWith(status: EarlyLeaveCheckoutViewStatus.loading));
    _subscription = _repository
        .watchForToday(employee)
        .listen(
          (eligibility) => emit(
            EarlyLeaveCheckoutState(
              status:
                  eligibility == null
                      ? EarlyLeaveCheckoutViewStatus.unavailable
                      : EarlyLeaveCheckoutViewStatus.ready,
              eligibility: eligibility,
            ),
          ),
          onError:
              (_) => emit(
                state.copyWith(
                  status: EarlyLeaveCheckoutViewStatus.error,
                  message: 'تعذر التحقق من طلب المغادرة المبكرة حالياً.',
                ),
              ),
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
