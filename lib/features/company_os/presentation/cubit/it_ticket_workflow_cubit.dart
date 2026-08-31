import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class ItTicketWorkflowState {
  const ItTicketWorkflowState();
}

final class ItTicketWorkflowIdle extends ItTicketWorkflowState {
  const ItTicketWorkflowIdle();
}

final class ItTicketWorkflowSaving extends ItTicketWorkflowState {
  const ItTicketWorkflowSaving();
}

final class ItTicketWorkflowSaved extends ItTicketWorkflowState {
  const ItTicketWorkflowSaved();
}

final class ItTicketWorkflowFailure extends ItTicketWorkflowState {
  const ItTicketWorkflowFailure(this.message);
  final String message;
}

final class ItTicketWorkflowCubit extends Cubit<ItTicketWorkflowState> {
  ItTicketWorkflowCubit(this._repository) : super(const ItTicketWorkflowIdle());
  final ItOperationsRepository _repository;
  Future<void> assign(ItTicket ticket, String uid, String operationId) => _save(
    () => _repository.assignTicket(
      ticketId: ticket.id,
      assigneeUid: uid,
      operationId: operationId,
      expectedVersion: ticket.version,
    ),
  );
  Future<void> transition(
    ItTicket ticket,
    ItTicketStatus status,
    String operationId, {
    String? resolution,
  }) => _save(
    () => _repository.transitionTicket(
      ticketId: ticket.id,
      status: status,
      operationId: operationId,
      expectedVersion: ticket.version,
      resolutionSummary: resolution,
    ),
  );
  Future<void> privateNote(ItTicket ticket, String body, String operationId) =>
      _save(
        () => _repository.addPrivateNote(
          ticketId: ticket.id,
          operationId: operationId,
          body: body,
        ),
      );
  Future<void> _save(Future<void> Function() action) async {
    emit(const ItTicketWorkflowSaving());
    try {
      await action();
      emit(const ItTicketWorkflowSaved());
    } catch (_) {
      emit(
        const ItTicketWorkflowFailure(
          'تعذر حفظ التغيير. حدّث البيانات ثم أعد المحاولة.',
        ),
      );
    }
  }
}
