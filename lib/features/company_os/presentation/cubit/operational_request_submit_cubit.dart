import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/operational_request_repository.dart';
import '../../domain/entities/company_os_attachment_reference.dart';

sealed class OperationalRequestSubmitState {
  const OperationalRequestSubmitState();
}

final class OperationalRequestSubmitIdle extends OperationalRequestSubmitState {
  const OperationalRequestSubmitIdle();
}

final class OperationalRequestSubmitting extends OperationalRequestSubmitState {
  const OperationalRequestSubmitting();
}

final class OperationalRequestSubmitted extends OperationalRequestSubmitState {
  const OperationalRequestSubmitted(this.message);
  final String message;
}

final class OperationalRequestSubmitFailure
    extends OperationalRequestSubmitState {
  const OperationalRequestSubmitFailure(this.message);
  final String message;
}

final class OperationalRequestSubmitCubit
    extends Cubit<OperationalRequestSubmitState> {
  OperationalRequestSubmitCubit(this._repository)
    : super(const OperationalRequestSubmitIdle());
  final OperationalRequestRepository _repository;

  Future<void> submit({
    required String requestType,
    required String businessReason,
    required DateTime executionDate,
    num? amount,
    String? currency,
    List<CompanyOsAttachmentReference> attachments = const [],
  }) async {
    if (state is OperationalRequestSubmitting) return;
    emit(const OperationalRequestSubmitting());
    try {
      await _repository.create(
        operationId: 'request-create-${DateTime.now().microsecondsSinceEpoch}',
        requestType: requestType,
        businessReason: businessReason,
        executionDate: executionDate,
        amount: amount,
        currency: currency,
        attachments: attachments,
      );
      emit(const OperationalRequestSubmitted('تم حفظ الطلب وإرساله للمراجعة.'));
    } catch (_) {
      emit(
        const OperationalRequestSubmitFailure(
          'تعذر إرسال الطلب. تحقق من البيانات ثم أعد المحاولة.',
        ),
      );
    }
  }
}
