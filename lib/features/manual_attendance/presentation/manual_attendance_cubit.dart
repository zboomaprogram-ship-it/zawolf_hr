import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/manual_attendance_repository.dart';
import '../../../utils/user_facing_error.dart';

class ManualAttendanceState {
  const ManualAttendanceState({
    this.employees = const [],
    this.loadingEmployees = false,
    this.submitting = false,
    this.error,
    this.success,
  });

  final List<ManualAttendanceEmployee> employees;
  final bool loadingEmployees;
  final bool submitting;
  final String? error;
  final String? success;

  ManualAttendanceState copyWith({
    List<ManualAttendanceEmployee>? employees,
    bool? loadingEmployees,
    bool? submitting,
    String? error,
    String? success,
    bool clearError = false,
    bool clearSuccess = false,
  }) => ManualAttendanceState(
    employees: employees ?? this.employees,
    loadingEmployees: loadingEmployees ?? this.loadingEmployees,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : error ?? this.error,
    success: clearSuccess ? null : success ?? this.success,
  );
}

class ManualAttendanceCubit extends Cubit<ManualAttendanceState> {
  ManualAttendanceCubit(this._repository)
    : super(const ManualAttendanceState());

  final ManualAttendanceRepository _repository;

  Future<void> search(String query) async {
    emit(state.copyWith(loadingEmployees: true, clearError: true));
    try {
      emit(
        state.copyWith(
          employees: await _repository.findEmployees(query),
          loadingEmployees: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingEmployees: false,
          error:
              'تعذر تحميل الموظفين. تحقق من اتصال الإنترنت وصلاحية حساب HR ثم أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> submit({
    required ManualAttendanceEmployee employee,
    required String eventType,
    required DateTime effectiveAt,
    required String reason,
  }) async {
    emit(
      state.copyWith(submitting: true, clearError: true, clearSuccess: true),
    );
    try {
      await _repository.record(
        employeeId: employee.id,
        eventType: eventType,
        effectiveAt: effectiveAt,
        reason: reason,
      );
      final updatedEmployees = await _repository.findEmployees('');
      final actionLabel = switch (eventType) {
        'checkIn' => 'الحضور اليدوي',
        'checkOut' => 'الانصراف اليدوي',
        'disableCheckOut' => 'إلغاء شرط الانصراف اليومي',
        _ => 'العملية اليدوية',
      };
      emit(
        state.copyWith(
          submitting: false,
          employees: updatedEmployees,
          success: 'تم تسجيل $actionLabel بنجاح وإشعار الموظف.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          submitting: false,
          error: userFacingError(
            error,
            fallback: 'تعذر تسجيل العملية اليدوية. أعد المحاولة.',
          ),
        ),
      );
    }
  }
}
