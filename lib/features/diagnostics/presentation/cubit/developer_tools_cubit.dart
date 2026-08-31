import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/developer_tools_entitlement.dart';
import '../../domain/repositories/developer_tools_repository.dart';

enum DeveloperToolsStatus { initial, loading, available, unavailable, failure }

final class DeveloperToolsState {
  const DeveloperToolsState({
    this.status = DeveloperToolsStatus.initial,
    this.entitlement,
  });

  final DeveloperToolsStatus status;
  final DeveloperToolsEntitlement? entitlement;

  bool get canShowMenu =>
      status == DeveloperToolsStatus.available &&
      (entitlement?.isActive ?? false);
}

final class DeveloperToolsCubit extends Cubit<DeveloperToolsState> {
  DeveloperToolsCubit(this._repository) : super(const DeveloperToolsState());

  final DeveloperToolsRepository _repository;

  Future<void> load() async {
    emit(const DeveloperToolsState(status: DeveloperToolsStatus.loading));
    try {
      final entitlement = await _repository.loadMyEntitlement();
      emit(
        DeveloperToolsState(
          status: entitlement?.isActive == true
              ? DeveloperToolsStatus.available
              : DeveloperToolsStatus.unavailable,
          entitlement: entitlement,
        ),
      );
    } catch (_) {
      emit(const DeveloperToolsState(status: DeveloperToolsStatus.failure));
    }
  }
}
