import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/developer_tools_entitlement.dart';
import '../../domain/entities/developer_tools_employee.dart';
import '../../domain/repositories/developer_tools_directory_repository.dart';
import '../../domain/repositories/developer_tools_repository.dart';

enum DeveloperToolsAdminStatus { loading, ready, saving, saved, failure }

final class DeveloperToolsAdminState {
  const DeveloperToolsAdminState({
    this.status = DeveloperToolsAdminStatus.loading,
    this.employees = const [],
    this.selectedEmployee,
  });
  final DeveloperToolsAdminStatus status;
  final List<DeveloperToolsEmployee> employees;
  final DeveloperToolsEmployee? selectedEmployee;

  DeveloperToolsAdminState copyWith({
    DeveloperToolsAdminStatus? status,
    List<DeveloperToolsEmployee>? employees,
    DeveloperToolsEmployee? selectedEmployee,
    bool clearSelectedEmployee = false,
  }) => DeveloperToolsAdminState(
    status: status ?? this.status,
    employees: employees ?? this.employees,
    selectedEmployee: clearSelectedEmployee
        ? null
        : selectedEmployee ?? this.selectedEmployee,
  );
}

final class DeveloperToolsAdminCubit extends Cubit<DeveloperToolsAdminState> {
  DeveloperToolsAdminCubit(this._repository, this._directoryRepository)
    : super(const DeveloperToolsAdminState());
  final DeveloperToolsRepository _repository;
  final DeveloperToolsDirectoryRepository _directoryRepository;

  Future<void> load() async {
    emit(state.copyWith(status: DeveloperToolsAdminStatus.loading));
    try {
      final employees = await _directoryRepository.loadActiveEmployees();
      emit(
        state.copyWith(
          status: DeveloperToolsAdminStatus.ready,
          employees: employees,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
    }
  }

  void selectEmployee(DeveloperToolsEmployee? employee) {
    emit(
      state.copyWith(
        status: DeveloperToolsAdminStatus.ready,
        selectedEmployee: employee,
        clearSelectedEmployee: employee == null,
      ),
    );
  }

  Future<void> grant({DateTime? expiresAt, bool permanent = false}) async {
    final employee = state.selectedEmployee;
    if (employee == null) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
      return;
    }
    emit(state.copyWith(status: DeveloperToolsAdminStatus.saving));
    try {
      await _repository.grant(
        employeeUserId: employee.userId,
        expiresAt: expiresAt,
        permanent: permanent || expiresAt == null,
        scopes: DeveloperToolScope.values.toSet(),
      );
      emit(state.copyWith(status: DeveloperToolsAdminStatus.saved));
    } catch (_) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
    }
  }

  Future<void> revoke() async {
    final employee = state.selectedEmployee;
    if (employee == null) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
      return;
    }
    emit(state.copyWith(status: DeveloperToolsAdminStatus.saving));
    try {
      await _repository.revoke(employee.userId);
      emit(state.copyWith(status: DeveloperToolsAdminStatus.saved));
    } catch (_) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
    }
  }
}
