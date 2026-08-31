import '../entities/organization_snapshot.dart';
import '../entities/organization_tree.dart';
import '../entities/organization_tree_bootstrap.dart';

abstract interface class MultiTreeOrganizationRepository {
  Future<List<OrganizationTree>> loadTrees({bool includeArchived = false});

  Future<OrganizationSnapshot> loadTreeSnapshot(String treeId);

  /// Previews the additive import of the legacy hierarchy. The preview's
  /// fingerprint must be echoed to [applyLegacyBootstrap].
  Future<OrganizationTreeBootstrapPreview> previewLegacyBootstrap();

  Future<void> applyLegacyBootstrap({
    required String operationId,
    required String approvedFingerprint,
  });
}
