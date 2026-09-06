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
    this.entitlements = const [],
    this.selectedEmployee,
  });
  final DeveloperToolsAdminStatus status;
  final List<DeveloperToolsEmployee> employees;
  final List<DeveloperToolsEntitlement> entitlements;
  final DeveloperToolsEmployee? selectedEmployee;

  DeveloperToolsAdminState copyWith({
    DeveloperToolsAdminStatus? status,
    List<DeveloperToolsEmployee>? employees,
    List<DeveloperToolsEntitlement>? entitlements,
    DeveloperToolsEmployee? selectedEmployee,
    bool clearSelectedEmployee = false,
  }) => DeveloperToolsAdminState(
    status: status ?? this.status,
    employees: employees ?? this.employees,
    entitlements: entitlements ?? this.entitlements,
    selectedEmployee:
        clearSelectedEmployee
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
      List<DeveloperToolsEntitlement> entitlements = const [];
      try {
        entitlements = await _repository.loadActiveEntitlements();
      } catch (_) {
        // Keep grant/revoke available while a staged Hostinger deployment is
        // still missing the optional listing endpoint.
      }
      emit(
        state.copyWith(
          status: DeveloperToolsAdminStatus.ready,
          employees: employees,
          entitlements: entitlements,
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
      var entitlements = state.entitlements;
      try {
        entitlements = await _repository.loadActiveEntitlements();
      } catch (_) {
        // The server already confirmed the grant. Do not present it as a
        // failure solely because an older backend cannot list grants yet.
      }
      emit(
        state.copyWith(
          status: DeveloperToolsAdminStatus.saved,
          entitlements: entitlements,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
    }
  }

  Future<void> revoke([String? employeeUserId]) async {
    final selectedId = employeeUserId ?? state.selectedEmployee?.userId;
    if (selectedId == null || selectedId.isEmpty) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
      return;
    }
    emit(state.copyWith(status: DeveloperToolsAdminStatus.saving));
    try {
      await _repository.revoke(selectedId);
      var entitlements = state.entitlements;
      try {
        entitlements = await _repository.loadActiveEntitlements();
      } catch (_) {
        // A confirmed revoke remains successful even during a listing outage.
        entitlements = entitlements
            .where((entitlement) => entitlement.employeeUserId != selectedId)
            .toList(growable: false);
      }
      emit(
        state.copyWith(
          status: DeveloperToolsAdminStatus.saved,
          entitlements: entitlements,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: DeveloperToolsAdminStatus.failure));
    }
  }
}
