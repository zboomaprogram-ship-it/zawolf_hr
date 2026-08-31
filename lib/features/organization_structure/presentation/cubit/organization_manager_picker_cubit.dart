import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/organization_membership.dart';
import '../../domain/repositories/organization_structure_repository.dart';

sealed class OrganizationManagerPickerState {
  const OrganizationManagerPickerState();
}

final class OrganizationManagerPickerIdle
    extends OrganizationManagerPickerState {
  const OrganizationManagerPickerIdle();
}

final class OrganizationManagerPickerLoading
    extends OrganizationManagerPickerState {
  const OrganizationManagerPickerLoading();
}

final class OrganizationManagerPickerReady
    extends OrganizationManagerPickerState {
  const OrganizationManagerPickerReady(this.items);
  final List<OrganizationMembership> items;
}

final class OrganizationManagerPickerFailure
    extends OrganizationManagerPickerState {
  const OrganizationManagerPickerFailure();
}

final class OrganizationManagerPickerCubit
    extends Cubit<OrganizationManagerPickerState> {
  OrganizationManagerPickerCubit(this._repository)
    : super(const OrganizationManagerPickerIdle());
  final OrganizationStructureRepository _repository;
  OrganizationStructureRepository get repository => _repository;
  Future<void> search(String query) async {
    emit(const OrganizationManagerPickerLoading());
    try {
      emit(
        OrganizationManagerPickerReady(
          await _repository.searchEmployees(query),
        ),
      );
    } catch (_) {
      emit(const OrganizationManagerPickerFailure());
    }
  }
}
