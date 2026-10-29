import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/remote_work_models.dart';
import '../../domain/repositories/remote_work_repository.dart';

export 'remote_day_state.dart';
import 'remote_day_state.dart';

final class RemoteDayCubit extends Cubit<RemoteDayState> {
  RemoteDayCubit({required RemoteWorkRepository repository})
      : _repository = repository,
        super(const RemoteDayState());

  final RemoteWorkRepository _repository;

  Future<void> loadDay({
    required String employeeId,
    required DateTime date,
  }) async {
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    try {
      final eligibility = await _repository.evaluateEligibility(
        employeeId: employeeId,
        date: date,
      );
      if (eligibility.eligible) {
        emit(
          state.copyWith(
            status: RemoteDayStatus.eligible,
            eligibility: eligibility,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: RemoteDayStatus.ineligible,
            eligibility: eligibility,
            errorMessage: _formatIneligibleReason(eligibility.reason),
          ),
        );
      }
    } on RemoteWorkDomainException catch (e) {
      emit(
        state.copyWith(
          status: e.code == 'mode_locked'
              ? RemoteDayStatus.modeLocked
              : RemoteDayStatus.error,
          errorMessage: e.messageAr,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: 'تعذر التحقق من أهلية العمل عن بُعد. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> performCheckIn({
    required String employeeId,
    required DateTime date,
    required RemoteProof proof,
  }) async {
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    final dateKey = _formatDateKey(date);
    final command = RemoteCommand(
      operationId: 'cin-$employeeId-$dateKey-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'check_in',
      date: dateKey,
      payload: {},
      proof: proof,
    );
    try {
      final receipt = await _repository.submitAttendanceCommand(command);
      emit(
        state.copyWith(
          status: RemoteDayStatus.checkedIn,
          receipt: receipt,
          attendanceId: receipt.attendanceId,
          sessionId: receipt.sessionId,
        ),
      );
    } on RemoteWorkDomainException catch (e) {
      emit(
        state.copyWith(
          status: e.code == 'mode_locked'
              ? RemoteDayStatus.modeLocked
              : RemoteDayStatus.error,
          errorMessage: e.messageAr,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: 'تعذر تسجيل الحضور عن بُعد. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> performCheckOut({
    required String employeeId,
    required DateTime date,
    required RemoteProof proof,
    String? summary,
  }) async {
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    final dateKey = _formatDateKey(date);
    final command = RemoteCommand(
      operationId: 'cout-$employeeId-$dateKey-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'check_out',
      date: dateKey,
      sessionId: state.sessionId,
      payload: summary != null ? {'summary': summary} : {},
      proof: proof,
    );
    try {
      final receipt = await _repository.submitAttendanceCommand(command);
      emit(
        state.copyWith(
          status: RemoteDayStatus.checkedOut,
          receipt: receipt,
          summary: summary,
        ),
      );
    } on RemoteWorkDomainException catch (e) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: e.messageAr,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: 'تعذر تسجيل الانصراف عن بُعد. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> savePlan({
    required String employeeId,
    required List<String> goals,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    final command = RemoteCommand(
      operationId: 'plan-$sessionId-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'save_plan',
      sessionId: sessionId,
      payload: {'goals': goals},
    );
    try {
      await _repository.submitSessionCommand(command);
      emit(state.copyWith(status: RemoteDayStatus.checkedIn, goals: goals));
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: 'تعذر حفظ خطة العمل. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> saveSummary({
    required String employeeId,
    required String summary,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    final command = RemoteCommand(
      operationId: 'sum-$sessionId-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'save_summary',
      sessionId: sessionId,
      payload: {'summary': summary},
    );
    try {
      await _repository.submitSessionCommand(command);
      emit(state.copyWith(status: RemoteDayStatus.checkedIn, summary: summary));
    } catch (_) {
      emit(
        state.copyWith(
          status: RemoteDayStatus.error,
          errorMessage: 'تعذر حفظ ملخص الإنجاز. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> submitCheckpointUpdate({
    required String checkpointId,
    required String text,
    int? slotIndex,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    emit(state.copyWith(status: RemoteDayStatus.loading, errorMessage: null));
    final command = RemoteCommand(
      operationId: 'upd-$sessionId-$checkpointId-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'submit_update',
      sessionId: sessionId,
      payload: {'checkpointId': checkpointId, 'updateText': text, if (slotIndex != null) 'slotIndex': slotIndex},
    );
    try {
      await _repository.submitSessionCommand(command);
      final next = Map<String, String>.from(state.checkpointUpdates)..[checkpointId] = text;
      emit(state.copyWith(status: RemoteDayStatus.checkedIn, checkpointUpdates: next));
    } on RemoteWorkDomainException catch (e) {
      emit(state.copyWith(status: RemoteDayStatus.checkedIn, errorMessage: e.messageAr));
    } catch (_) {
      emit(state.copyWith(status: RemoteDayStatus.checkedIn, errorMessage: 'تعذر إرسال المتابعة. تأكد من الوقت وحاول مجدداً.'));
    }
  }

  static String _formatDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _formatIneligibleReason(String reason) {
    switch (reason) {
      case 'weekly_allowance_conflict':
        return 'تم استنفاد أيام العمل عن بُعد المتاحة لهذا الأسبوع.';
      case 'weekday_not_allowed':
        return 'هذا اليوم غير مخصص للعمل عن بُعد وفق جدولك المعتمد.';
      case 'company_holiday':
        return 'اليوم عطلة رسمية للشركة.';
      case 'employee_rest_day':
        return 'اليوم يوم راحة أسبوعية للموظف.';
      case 'approved_leave':
        return 'لديك إجازة معتمدة مسجلة في هذا اليوم.';
      case 'probation_ineligible':
        return 'العمل عن بُعد غير متاح خلال فترة التجربة.';
      case 'remote_work_disabled':
        return 'سياسة العمل عن بُعد غير مفعلة حالياً.';
      default:
        return 'غير مؤهل للعمل عن بُعد في هذا اليوم.';
    }
  }
}
