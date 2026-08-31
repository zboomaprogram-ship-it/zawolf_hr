import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/it_operations_repository.dart';

sealed class ItTicketQueueState {
  const ItTicketQueueState();
}

final class ItTicketQueueLoading extends ItTicketQueueState {
  const ItTicketQueueLoading();
}

final class ItTicketQueueReady extends ItTicketQueueState {
  const ItTicketQueueReady(this.items);
  final List<ItTicket> items;
}

final class ItTicketQueueFailure extends ItTicketQueueState {
  const ItTicketQueueFailure(this.message);
  final String message;
}

final class ItTicketQueueCubit extends Cubit<ItTicketQueueState> {
  ItTicketQueueCubit(this._repository) : super(const ItTicketQueueLoading());
  final ItOperationsRepository _repository;
  ItOperationsRepository get repository => _repository;
  Future<void> load() async {
    emit(const ItTicketQueueLoading());
    try {
      emit(ItTicketQueueReady((await _repository.tickets()).items));
    } catch (_) {
      emit(const ItTicketQueueFailure('تعذر تحميل تذاكر الدعم. أعد المحاولة.'));
    }
  }
}
