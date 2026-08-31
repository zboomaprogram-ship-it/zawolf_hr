import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/organization_membership.dart';
import '../../domain/repositories/organization_structure_repository.dart';

final class OrganizationMembershipState {
  const OrganizationMembershipState({
    this.loading = false,
    this.items = const [],
    this.selected = const {},
    this.message,
  });
  final bool loading;
  final List<OrganizationMembership> items;
  final Set<String> selected;
  final String? message;
}

final class OrganizationMembershipCubit
    extends Cubit<OrganizationMembershipState> {
  OrganizationMembershipCubit(this._repository)
    : super(const OrganizationMembershipState());
  final OrganizationStructureRepository _repository;
  OrganizationStructureRepository get repository => _repository;
  Future<void> search(String query) async {
    emit(
      OrganizationMembershipState(
        loading: true,
        items: state.items,
        selected: state.selected,
      ),
    );
    try {
      emit(
        OrganizationMembershipState(
          items: await _repository.searchEmployees(query),
          selected: state.selected,
        ),
      );
    } catch (_) {
      emit(
        OrganizationMembershipState(
          items: state.items,
          selected: state.selected,
          message: 'تعذر تحميل الموظفين.',
        ),
      );
    }
  }

  void toggle(String uid) {
    final selected = {...state.selected};
    selected.contains(uid) ? selected.remove(uid) : selected.add(uid);
    emit(OrganizationMembershipState(items: state.items, selected: selected));
  }

  void setSelection(Set<String> selected) => emit(
    OrganizationMembershipState(
      items: state.items,
      selected: Set.unmodifiable(selected),
    ),
  );

  void clear() => emit(OrganizationMembershipState(items: state.items));
}
