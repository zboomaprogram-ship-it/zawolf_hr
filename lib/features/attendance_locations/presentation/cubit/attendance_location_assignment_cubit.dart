import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/attendance_location_assignment_repository.dart';
import '../../domain/entities/attendance_location_assignment.dart';

enum AttendanceLocationAssignmentPhase {
  editing,
  previewing,
  previewed,
  applying,
  applied,
  failure,
}

class AttendanceLocationAssignmentState {
  const AttendanceLocationAssignmentState({
    this.phase = AttendanceLocationAssignmentPhase.editing,
    this.preview = const {},
    this.activeAssignments = const [],
    this.message,
  });

  final AttendanceLocationAssignmentPhase phase;
  final Map<String, dynamic> preview;
  final List<AttendanceLocationAssignment> activeAssignments;
  final String? message;

  bool get busy =>
      phase == AttendanceLocationAssignmentPhase.previewing ||
      phase == AttendanceLocationAssignmentPhase.applying;
}

class AttendanceLocationAssignmentCubit
    extends Cubit<AttendanceLocationAssignmentState> {
  AttendanceLocationAssignmentCubit(this._repository)
    : super(const AttendanceLocationAssignmentState());

  final AttendanceLocationAdministrationRepository _repository;

  Future<void> loadActiveAssignments() async {
    try {
      final assignments = await _repository.listAllAssignments();
      emit(AttendanceLocationAssignmentState(activeAssignments: assignments));
    } catch (_) {
      emit(
        const AttendanceLocationAssignmentState(
          message: 'تعذر تحميل الإسنادات الحالية. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> preview({
    required List<String> employeeUids,
    required List<String> locationIds,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  }) async {
    emit(
      const AttendanceLocationAssignmentState(
        phase: AttendanceLocationAssignmentPhase.previewing,
      ),
    );
    try {
      final result = await _repository.previewAssignments(
        employeeUids: employeeUids,
        locationIds: locationIds,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        defaultLocationId: defaultLocationId,
        remove: remove,
      );
      emit(
        AttendanceLocationAssignmentState(
          phase: AttendanceLocationAssignmentPhase.previewed,
          preview: result,
        ),
      );
    } catch (error) {
      emit(
        AttendanceLocationAssignmentState(
          phase: AttendanceLocationAssignmentPhase.failure,
          message: _safe(error),
        ),
      );
    }
  }

  Future<void> apply({
    required List<String> employeeUids,
    required List<String> locationIds,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? defaultLocationId,
    bool remove = false,
  }) async {
    remove = remove || state.preview['mode'] == 'remove';
    final token = '${state.preview['previewToken'] ?? ''}';
    if (token.isEmpty) return;
    final operationId =
        'attendance-location-${DateTime.now().microsecondsSinceEpoch}';
    emit(
      AttendanceLocationAssignmentState(
        phase: AttendanceLocationAssignmentPhase.applying,
        preview: state.preview,
      ),
    );
    try {
      final receipt = await _repository.applyAssignments(
        operationId: operationId,
        previewToken: token,
        employeeUids: employeeUids,
        locationIds: locationIds,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        defaultLocationId: defaultLocationId,
        remove: remove,
      );
      emit(
        AttendanceLocationAssignmentState(
          phase: AttendanceLocationAssignmentPhase.applied,
          preview: receipt,
          activeAssignments: await _repository.listAllAssignments(),
          message: 'تم حفظ إسنادات المواقع وتسجيل العملية بنجاح.',
        ),
      );
    } catch (error) {
      emit(
        AttendanceLocationAssignmentState(
          phase: AttendanceLocationAssignmentPhase.failure,
          preview: state.preview,
          message: _safe(error),
        ),
      );
    }
  }

  void edit() => emit(const AttendanceLocationAssignmentState());

  String _safe(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
