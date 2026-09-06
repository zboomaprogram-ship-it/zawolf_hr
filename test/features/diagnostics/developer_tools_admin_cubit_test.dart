import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/developer_tools_employee.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/developer_tools_entitlement.dart';
import 'package:zawolf_hr/features/diagnostics/domain/repositories/developer_tools_directory_repository.dart';
import 'package:zawolf_hr/features/diagnostics/domain/repositories/developer_tools_repository.dart';
import 'package:zawolf_hr/features/diagnostics/presentation/cubit/developer_tools_admin_cubit.dart';

void main() {
  test(
    'grant uses the selected system employee rather than free-text input',
    () async {
      final repository = _FakeRepository();
      final cubit = DeveloperToolsAdminCubit(
        repository,
        _FakeDirectoryRepository(),
      );
      await cubit.load();
      cubit.selectEmployee(cubit.state.employees.single);

      await cubit.grant(
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(repository.grantedEmployeeId, 'employee-1');
      expect(cubit.state.status, DeveloperToolsAdminStatus.saved);
      await cubit.close();
    },
  );

  test('grant fails safely if no employee is selected', () async {
    final cubit = DeveloperToolsAdminCubit(
      _FakeRepository(),
      _FakeDirectoryRepository(),
    );

    await cubit.grant(expiresAt: DateTime.now().add(const Duration(hours: 2)));

    expect(cubit.state.status, DeveloperToolsAdminStatus.failure);
    await cubit.close();
  });

  test(
    'saved active grants remain visible after the admin page reloads',
    () async {
      final repository =
          _FakeRepository()
            ..activeEntitlements = const [
              DeveloperToolsEntitlement(
                employeeUserId: 'employee-1',
                scopes: {DeveloperToolScope.appDiagnostics},
                permanent: true,
                grantedByUserId: 'hr-1',
              ),
            ];
      final cubit = DeveloperToolsAdminCubit(
        repository,
        _FakeDirectoryRepository(),
      );

      await cubit.load();

      expect(cubit.state.entitlements, hasLength(1));
      expect(cubit.state.entitlements.single.employeeUserId, 'employee-1');
      await cubit.close();
    },
  );
}

final class _FakeDirectoryRepository
    implements DeveloperToolsDirectoryRepository {
  @override
  Future<List<DeveloperToolsEmployee>> loadActiveEmployees() async => const [
    DeveloperToolsEmployee(
      userId: 'employee-1',
      displayName: 'موظف تجريبي',
      employeeCode: 'TEST-001',
      department: 'Testing',
    ),
  ];
}

final class _FakeRepository implements DeveloperToolsRepository {
  String? grantedEmployeeId;
  List<DeveloperToolsEntitlement> activeEntitlements = const [];

  @override
  Future<void> grant({
    required String employeeUserId,
    required Set<DeveloperToolScope> scopes,
    DateTime? expiresAt,
    bool permanent = false,
  }) async {
    grantedEmployeeId = employeeUserId;
  }

  @override
  Future<DeveloperToolsEntitlement?> loadMyEntitlement() async => null;

  @override
  Future<List<DeveloperToolsEntitlement>> loadActiveEntitlements() async =>
      activeEntitlements;

  @override
  Future<void> revoke(String employeeUserId) async {}
}
