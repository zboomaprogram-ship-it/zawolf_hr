import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/developer_api_client.dart';
import '../../domain/repositories/developer_api_repository.dart';

enum DeveloperApiAdminStatus { loading, ready, saving, issued, failure }

final class DeveloperApiAdminState {
  const DeveloperApiAdminState({
    this.status = DeveloperApiAdminStatus.loading,
    this.clients = const [],
    this.issued,
  });

  final DeveloperApiAdminStatus status;
  final List<DeveloperApiClient> clients;
  final IssuedDeveloperApiClient? issued;

  DeveloperApiAdminState copyWith({
    DeveloperApiAdminStatus? status,
    List<DeveloperApiClient>? clients,
    IssuedDeveloperApiClient? issued,
    bool clearIssued = false,
  }) => DeveloperApiAdminState(
    status: status ?? this.status,
    clients: clients ?? this.clients,
    issued: clearIssued ? null : issued ?? this.issued,
  );
}

final class DeveloperApiAdminCubit extends Cubit<DeveloperApiAdminState> {
  DeveloperApiAdminCubit(this._repository) : super(const DeveloperApiAdminState());
  final DeveloperApiRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: DeveloperApiAdminStatus.loading, clearIssued: true));
    try {
      emit(state.copyWith(status: DeveloperApiAdminStatus.ready, clients: await _repository.listClients()));
    } catch (_) {
      emit(state.copyWith(status: DeveloperApiAdminStatus.failure));
    }
  }

  Future<void> create({required String name, required DateTime expiresAt}) async {
    if (name.trim().isEmpty || !expiresAt.isAfter(DateTime.now())) {
      emit(state.copyWith(status: DeveloperApiAdminStatus.failure));
      return;
    }
    emit(state.copyWith(status: DeveloperApiAdminStatus.saving, clearIssued: true));
    try {
      final issued = await _repository.createClient(name: name, expiresAt: expiresAt);
      emit(state.copyWith(status: DeveloperApiAdminStatus.issued, issued: issued, clients: [issued.client, ...state.clients]));
    } catch (_) {
      emit(state.copyWith(status: DeveloperApiAdminStatus.failure));
    }
  }

  Future<void> revoke({required String clientId, required String reason}) async {
    if (reason.trim().isEmpty) return;
    emit(state.copyWith(status: DeveloperApiAdminStatus.saving));
    try {
      await _repository.revokeClient(clientId: clientId, reason: reason);
      await load();
    } catch (_) {
      emit(state.copyWith(status: DeveloperApiAdminStatus.failure));
    }
  }
}
