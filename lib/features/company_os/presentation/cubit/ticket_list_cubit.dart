import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/employee_portal_repository.dart';

sealed class TicketListState {
  const TicketListState();
}

final class TicketListLoading extends TicketListState {
  const TicketListLoading();
}

final class TicketListReady extends TicketListState {
  const TicketListReady(this.items);
  final List<ItTicket> items;
}

final class TicketListFailure extends TicketListState {
  const TicketListFailure(this.message);
  final String message;
}

final class TicketListCubit extends Cubit<TicketListState> {
  TicketListCubit(this._repository) : super(const TicketListLoading());
  final EmployeePortalRepository _repository;
  Future<void> load() async {
    emit(const TicketListLoading());
    try {
      emit(TicketListReady((await _repository.ownTickets()).items));
    } catch (_) {
      emit(const TicketListFailure('تعذر تحميل التذاكر. أعد المحاولة.'));
    }
  }
}
