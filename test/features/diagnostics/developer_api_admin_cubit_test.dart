import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/developer_api_client.dart';
import 'package:zawolf_hr/features/diagnostics/domain/repositories/developer_api_repository.dart';
import 'package:zawolf_hr/features/diagnostics/presentation/cubit/developer_api_admin_cubit.dart';

void main() {
  test('issues a one-time directory credential and places it in the client list', () async {
    final repository = _FakeDeveloperApiRepository();
    final cubit = DeveloperApiAdminCubit(repository);
    final expiry = DateTime.now().add(const Duration(days: 30));

    await cubit.create(name: 'Partner', expiresAt: expiry);

    expect(cubit.state.status, DeveloperApiAdminStatus.issued);
    expect(cubit.state.issued?.secret, 'zwh_once');
    expect(cubit.state.clients.single.name, 'Partner');
    await cubit.close();
  });

  test('does not create a credential with an empty integration name', () async {
    final cubit = DeveloperApiAdminCubit(_FakeDeveloperApiRepository());
    await cubit.create(name: ' ', expiresAt: DateTime.now().add(const Duration(days: 1)));
    expect(cubit.state.status, DeveloperApiAdminStatus.failure);
    await cubit.close();
  });
}

final class _FakeDeveloperApiRepository implements DeveloperApiRepository {
  @override
  Future<IssuedDeveloperApiClient> createClient({required String name, required DateTime expiresAt, Set<String> scopes = const {'directory.read'}}) async => IssuedDeveloperApiClient(
    client: DeveloperApiClient(id: 'client', name: name, scopes: scopes.toList(), status: 'active', expiresAt: expiresAt),
    secret: 'zwh_once',
  );

  @override
  Future<List<DeveloperApiClient>> listClients() async => const [];

  @override
  Future<void> revokeClient({required String clientId, required String reason}) async {}
}
