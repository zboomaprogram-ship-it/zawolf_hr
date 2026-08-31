import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/assistant_exchange.dart';
import '../../domain/repositories/assistant_repository.dart';

enum EmployeeAssistantStatus { ready, asking, answered, unavailable }

final class EmployeeAssistantState {
  const EmployeeAssistantState({
    this.status = EmployeeAssistantStatus.ready,
    this.answer,
  });

  final EmployeeAssistantStatus status;
  final AssistantAnswer? answer;
}

final class EmployeeAssistantCubit extends Cubit<EmployeeAssistantState> {
  EmployeeAssistantCubit(this._repository)
    : super(const EmployeeAssistantState());

  final AssistantRepository _repository;

  Future<void> ask(String text) async {
    if (state.status == EmployeeAssistantStatus.asking) return;
    emit(const EmployeeAssistantState(status: EmployeeAssistantStatus.asking));
    try {
      final answer = await _repository.ask(
        AssistantQuestion(
          textAr: text,
          operationId: 'help:${DateTime.now().toUtc().microsecondsSinceEpoch}',
        ),
      );
      emit(
        EmployeeAssistantState(
          status: EmployeeAssistantStatus.answered,
          answer: answer,
        ),
      );
    } catch (_) {
      emit(
        const EmployeeAssistantState(
          status: EmployeeAssistantStatus.unavailable,
        ),
      );
    }
  }
}
