import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/organization_tree.dart';
import '../../domain/entities/organization_tree_bootstrap.dart';
import '../../domain/repositories/multi_tree_organization_repository.dart';

sealed class OrganizationTreeSelectorState {
  const OrganizationTreeSelectorState();
}

final class OrganizationTreeSelectorLoading
    extends OrganizationTreeSelectorState {
  const OrganizationTreeSelectorLoading();
}

final class OrganizationTreeSelectorReady
    extends OrganizationTreeSelectorState {
  const OrganizationTreeSelectorReady(this.trees, this.selectedTreeId);
  final List<OrganizationTree> trees;
  final String? selectedTreeId;
}

final class OrganizationTreeSelectorFailure
    extends OrganizationTreeSelectorState {
  const OrganizationTreeSelectorFailure();
}

final class OrganizationTreeSelectorCubit
    extends Cubit<OrganizationTreeSelectorState> {
  OrganizationTreeSelectorCubit(this._repository)
    : super(const OrganizationTreeSelectorLoading());

  final MultiTreeOrganizationRepository _repository;

  Future<void> load() async {
    emit(const OrganizationTreeSelectorLoading());
    try {
      final trees = await _repository.loadTrees(includeArchived: true);
      OrganizationTree? selectedTree;
      for (final tree in trees) {
        if (tree.isDefault) {
          selectedTree = tree;
          break;
        }
      }
      selectedTree ??= trees.isEmpty ? null : trees.first;
      final selected = selectedTree?.id;
      emit(OrganizationTreeSelectorReady(trees, selected));
    } catch (_) {
      emit(const OrganizationTreeSelectorFailure());
    }
  }

  void select(String treeId) {
    final current = state;
    if (current is OrganizationTreeSelectorReady &&
        current.trees.any((tree) => tree.id == treeId)) {
      emit(OrganizationTreeSelectorReady(current.trees, treeId));
    }
  }

  Future<OrganizationTreeBootstrapPreview> previewLegacyBootstrap() =>
      _repository.previewLegacyBootstrap();

  Future<void> applyLegacyBootstrap(String fingerprint) =>
      _repository.applyLegacyBootstrap(
        operationId:
            'organization-bootstrap-${DateTime.now().microsecondsSinceEpoch}',
        approvedFingerprint: fingerprint,
      );
}
