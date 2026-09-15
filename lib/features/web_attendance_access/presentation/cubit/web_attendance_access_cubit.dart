import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/web_attendance_access_grant.dart';
import '../../domain/repositories/web_attendance_access_repository.dart';

class WebAttendanceAccessState {
  const WebAttendanceAccessState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.grants = const [],
    this.employees = const [],
  });
  final bool loading, saving;
  final String? error;
  final List<WebAttendanceAccessGrant> grants;
  final List<WebAttendanceEmployee> employees;
  WebAttendanceAccessState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    List<WebAttendanceAccessGrant>? grants,
    List<WebAttendanceEmployee>? employees,
  }) => WebAttendanceAccessState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    grants: grants ?? this.grants,
    employees: employees ?? this.employees,
  );
}

class WebAttendanceAccessCubit extends Cubit<WebAttendanceAccessState> {
  WebAttendanceAccessCubit(this._repository)
    : super(const WebAttendanceAccessState());
  final WebAttendanceAccessRepository _repository;
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.listGrants(),
        _repository.listActiveEmployees(),
      ]);
      emit(
        state.copyWith(
          loading: false,
          grants: results[0] as List<WebAttendanceAccessGrant>,
          employees: results[1] as List<WebAttendanceEmployee>,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<bool> save({
    required String employeeId,
    required String scope,
    bool allowAnyLocation = false,
    String? startDate,
    String? endDate,
    String? note,
  }) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.saveGrant(
        employeeId: employeeId,
        scope: scope,
        allowAnyLocation: allowAnyLocation,
        startDate: startDate,
        endDate: endDate,
        note: note,
      );
      emit(state.copyWith(saving: false));
      await load();
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          saving: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return false;
    }
  }

  Future<void> revoke(String employeeId) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.revokeGrant(employeeId: employeeId);
      emit(state.copyWith(saving: false));
      await load();
    } catch (e) {
      emit(
        state.copyWith(
          saving: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}
