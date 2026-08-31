import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/unified_operational_request.dart';
import '../../domain/repositories/operational_request_repository.dart';

sealed class OperationalRequestListState {
  const OperationalRequestListState();
}

final class OperationalRequestListLoading extends OperationalRequestListState {
  const OperationalRequestListLoading();
}

final class OperationalRequestListReady extends OperationalRequestListState {
  const OperationalRequestListReady(this.items);
  final List<UnifiedOperationalRequest> items;
}

final class OperationalRequestListFailure extends OperationalRequestListState {
  const OperationalRequestListFailure(this.message);
  final String message;
}

final class OperationalRequestListCubit
    extends Cubit<OperationalRequestListState> {
  OperationalRequestListCubit(this._repository)
    : super(const OperationalRequestListLoading());
  final OperationalRequestRepository _repository;

  Future<void> load() async {
    emit(const OperationalRequestListLoading());
    try {
      final page = await _repository.requests();
      emit(OperationalRequestListReady(page.items));
    } catch (_) {
      emit(
        const OperationalRequestListFailure(
          'تعذر تحميل الطلبات الآن. أعد المحاولة بعد لحظات.',
        ),
      );
    }
  }
}
