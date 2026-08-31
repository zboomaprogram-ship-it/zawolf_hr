import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/work_outcome.dart';
import '../../domain/repositories/work_outcome_repository.dart';

enum WorkOutcomeViewStatus {
  initial,
  loading,
  ready,
  empty,
  updating,
  conflict,
  failure,
}

final class WorkOutcomeState {
  const WorkOutcomeState({
    this.status = WorkOutcomeViewStatus.initial,
    this.items = const <WorkOutcome>[],
    this.messageAr,
  });

  final WorkOutcomeViewStatus status;
  final List<WorkOutcome> items;
  final String? messageAr;

  WorkOutcomeState copyWith({
    WorkOutcomeViewStatus? status,
    List<WorkOutcome>? items,
    String? messageAr,
    bool clearMessage = false,
  }) => WorkOutcomeState(
    status: status ?? this.status,
    items: items ?? this.items,
    messageAr: clearMessage ? null : messageAr ?? this.messageAr,
  );
}

final class WorkOutcomeCubit extends Cubit<WorkOutcomeState> {
  WorkOutcomeCubit(this._repository) : super(const WorkOutcomeState());

  final WorkOutcomeRepository _repository;
  StreamSubscription<List<WorkOutcome>>? _subscription;

  void watchEmployee(String employeeUserId) =>
      _watch(_repository.watchForEmployee(employeeUserId));

  void watchOwned(String ownerUserId) =>
      _watch(_repository.watchOwnedBy(ownerUserId));

  void _watch(Stream<List<WorkOutcome>> stream) {
    _subscription?.cancel();
    emit(const WorkOutcomeState(status: WorkOutcomeViewStatus.loading));
    _subscription = stream.listen(
      (items) => emit(
        WorkOutcomeState(
          status: items.isEmpty
              ? WorkOutcomeViewStatus.empty
              : WorkOutcomeViewStatus.ready,
          items: items,
        ),
      ),
      onError: (_, __) => emit(
        const WorkOutcomeState(
          status: WorkOutcomeViewStatus.failure,
          messageAr: 'تعذر تحميل نتائج العمل الآن. حاول مرة أخرى.',
        ),
      ),
    );
  }

  Future<void> updateProgress({
    required WorkOutcome outcome,
    required double value,
    String? evidenceReference,
  }) async {
    if (state.status == WorkOutcomeViewStatus.updating) return;
    emit(
      state.copyWith(
        status: WorkOutcomeViewStatus.updating,
        clearMessage: true,
      ),
    );
    try {
      await _repository.updateProgress(
        outcome: outcome,
        progressValue: value,
        evidenceReference: evidenceReference,
      );
      emit(state.copyWith(status: WorkOutcomeViewStatus.ready));
    } on StateError catch (error) {
      emit(
        state.copyWith(
          status: WorkOutcomeViewStatus.conflict,
          messageAr: error.message.toString(),
        ),
      );
    } on ArgumentError catch (error) {
      emit(
        state.copyWith(
          status: WorkOutcomeViewStatus.failure,
          messageAr: error.message?.toString() ?? 'قيمة التقدم غير صحيحة.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: WorkOutcomeViewStatus.failure,
          messageAr: 'لم يتم حفظ التقدم. تحقق من الاتصال ثم أعد المحاولة.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
