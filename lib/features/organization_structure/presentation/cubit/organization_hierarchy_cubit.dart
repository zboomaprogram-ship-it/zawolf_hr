import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/organization_snapshot.dart';
import '../../domain/repositories/organization_structure_repository.dart';
import '../../domain/repositories/multi_tree_organization_repository.dart';

sealed class OrganizationHierarchyState {
  const OrganizationHierarchyState();
}

final class OrganizationHierarchyLoading extends OrganizationHierarchyState {
  const OrganizationHierarchyLoading();
}

final class OrganizationHierarchyReady extends OrganizationHierarchyState {
  const OrganizationHierarchyReady(this.snapshot, {this.query = ''});
  final OrganizationSnapshot snapshot;
  final String query;
}

final class OrganizationHierarchyEmpty extends OrganizationHierarchyState {
  const OrganizationHierarchyEmpty();
}

final class OrganizationHierarchyFailure extends OrganizationHierarchyState {
  const OrganizationHierarchyFailure(this.message);
  final String message;
}

final class OrganizationHierarchyCubit
    extends Cubit<OrganizationHierarchyState> {
  OrganizationHierarchyCubit(this._repository)
    : super(const OrganizationHierarchyLoading());
  final OrganizationStructureRepository _repository;

  Future<void> load({bool includeArchived = false}) async {
    emit(const OrganizationHierarchyLoading());
    try {
      final snapshot = await _repository.loadHierarchy(
        includeArchived: includeArchived,
      );
      emit(
        snapshot.units.isEmpty
            ? const OrganizationHierarchyEmpty()
            : OrganizationHierarchyReady(snapshot),
      );
    } catch (_) {
      emit(
        const OrganizationHierarchyFailure(
          'تعذر تحميل الهيكل الوظيفي. أعد المحاولة.',
        ),
      );
    }
  }

  Future<void> loadTree(String treeId) async {
    final repository = _repository;
    if (repository is! MultiTreeOrganizationRepository) return;
    emit(const OrganizationHierarchyLoading());
    try {
      final snapshot = await (repository as MultiTreeOrganizationRepository)
          .loadTreeSnapshot(treeId);
      emit(OrganizationHierarchyReady(snapshot));
    } catch (_) {
      emit(
        const OrganizationHierarchyFailure(
          'تعذر تحميل الشجرة التنظيمية. أعد المحاولة.',
        ),
      );
    }
  }

  /// A multi-tree workspace with no tree must not remain on a perpetual
  /// spinner. The selector calls this while the administrator creates the
  /// first organization tree.
  void showEmpty() => emit(const OrganizationHierarchyEmpty());

  void search(String query) {
    final current = state;
    if (current is OrganizationHierarchyReady) {
      emit(OrganizationHierarchyReady(current.snapshot, query: query.trim()));
    }
  }
}
