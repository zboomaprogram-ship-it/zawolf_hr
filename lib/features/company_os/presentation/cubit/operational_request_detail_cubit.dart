import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/unified_operational_request.dart';
import '../../domain/repositories/operational_request_repository.dart';

sealed class OperationalRequestDetailState {
  const OperationalRequestDetailState();
}

final class OperationalRequestDetailLoading
    extends OperationalRequestDetailState {
  const OperationalRequestDetailLoading();
}

final class OperationalRequestDetailReady
    extends OperationalRequestDetailState {
  const OperationalRequestDetailReady(this.request, {this.saving = false});
  final UnifiedOperationalRequest request;
  final bool saving;
}

final class OperationalRequestDetailFailure
    extends OperationalRequestDetailState {
  const OperationalRequestDetailFailure(this.message);
  final String message;
}

final class OperationalRequestDetailCubit
    extends Cubit<OperationalRequestDetailState> {
  OperationalRequestDetailCubit(this._repository, this.requestId)
    : super(const OperationalRequestDetailLoading());
  final OperationalRequestRepository _repository;
  final String requestId;

  Future<void> load() async {
    emit(const OperationalRequestDetailLoading());
    try {
      emit(OperationalRequestDetailReady(await _repository.request(requestId)));
    } catch (_) {
      emit(const OperationalRequestDetailFailure('تعذر تحميل تفاصيل الطلب.'));
    }
  }

  Future<void> decide({required bool approved, required String reason}) =>
      _save(
        (request) => _repository.decide(
          requestId: request.id,
          operationId:
              'request-decision-${DateTime.now().microsecondsSinceEpoch}',
          expectedVersion: request.version,
          approved: approved,
          reason: reason,
        ),
      );

  Future<void> payment(String reference) => _save(
    (request) => _repository.completePayment(
      requestId: request.id,
      operationId: 'request-payment-${DateTime.now().microsecondsSinceEpoch}',
      expectedVersion: request.version,
      reference: reference,
    ),
  );

  Future<void> completeClosure(
    String note, {
    bool accessProvisioning = false,
  }) => _save(
    (request) => _repository.completeClosure(
      requestId: request.id,
      operationId: 'request-close-${DateTime.now().microsecondsSinceEpoch}',
      expectedVersion: request.version,
      note: note,
      accessProvisioning: accessProvisioning,
    ),
  );

  Future<void> _save(
    Future<Object?> Function(UnifiedOperationalRequest) action,
  ) async {
    final current = state;
    if (current is! OperationalRequestDetailReady || current.saving) return;
    emit(OperationalRequestDetailReady(current.request, saving: true));
    try {
      await action(current.request);
      await load();
    } catch (_) {
      emit(
        const OperationalRequestDetailFailure(
          'تعذر حفظ الإجراء. حدّث الطلب ثم أعد المحاولة.',
        ),
      );
    }
  }
}
