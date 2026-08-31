import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/employee_portal_repository.dart';

sealed class TicketDetailState {
  const TicketDetailState();
}

final class TicketDetailLoading extends TicketDetailState {
  const TicketDetailLoading();
}

final class TicketDetailReady extends TicketDetailState {
  const TicketDetailReady(this.ticket);
  final ItTicket ticket;
}

final class TicketDetailFailure extends TicketDetailState {
  const TicketDetailFailure();
}

final class TicketDetailCubit extends Cubit<TicketDetailState> {
  TicketDetailCubit(this._repository) : super(const TicketDetailLoading());
  final EmployeePortalRepository _repository;
  Future<void> load(String ticketId) async {
    try {
      emit(TicketDetailReady(await _repository.ticket(ticketId)));
    } catch (_) {
      emit(const TicketDetailFailure());
    }
  }
}
