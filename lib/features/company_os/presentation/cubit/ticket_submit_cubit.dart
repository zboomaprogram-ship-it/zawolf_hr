import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/entities/company_os_safe_error.dart';
import '../../domain/entities/company_os_sync_state.dart';
import '../../domain/use_cases/submit_it_ticket.dart';

enum TicketSubmitStatus {
  idle,
  submitting,
  pendingSync,
  saved,
  conflict,
  failed,
}

final class TicketSubmitState {
  const TicketSubmitState(this.status, {this.message});
  final TicketSubmitStatus status;
  final String? message;
}

final class TicketSubmitCubit extends Cubit<TicketSubmitState> {
  TicketSubmitCubit(this._submit)
    : super(const TicketSubmitState(TicketSubmitStatus.idle));
  final SubmitItTicket _submit;

  Future<void> submit({
    required String operationId,
    required String subject,
    required String description,
    required String category,
    required ItTicketPriority priority,
  }) async {
    emit(const TicketSubmitState(TicketSubmitStatus.submitting));
    try {
      final receipt = await _submit(
        operationId: operationId,
        subject: subject,
        description: description,
        category: category,
        priority: priority,
      );
      final status = switch (receipt.status) {
        CompanyOsSyncState.synced => TicketSubmitStatus.saved,
        CompanyOsSyncState.pending ||
        CompanyOsSyncState.syncing ||
        CompanyOsSyncState.needsStatusCheck => TicketSubmitStatus.pendingSync,
        CompanyOsSyncState.conflict => TicketSubmitStatus.conflict,
      };
      final message = switch (status) {
        TicketSubmitStatus.saved => 'تم حفظ التذكرة.',
        TicketSubmitStatus.pendingSync =>
          'تم حفظ الطلب على الجهاز وسيتم تأكيد المزامنة تلقائياً.',
        TicketSubmitStatus.conflict =>
          'تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.',
        _ => null,
      };
      emit(TicketSubmitState(status, message: message));
    } on CompanyOsSafeError catch (error) {
      emit(
        TicketSubmitState(
          error.code == CompanyOsSafeCode.conflict
              ? TicketSubmitStatus.conflict
              : TicketSubmitStatus.failed,
          message: error.arabicMessage,
        ),
      );
    } catch (_) {
      emit(
        const TicketSubmitState(
          TicketSubmitStatus.failed,
          message: 'تعذر الإرسال الآن. أعد المحاولة من دون إنشاء طلب جديد.',
        ),
      );
    }
  }
}
