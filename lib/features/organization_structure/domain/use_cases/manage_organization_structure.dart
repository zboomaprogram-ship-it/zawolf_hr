import '../entities/organization_change_set.dart';
import '../entities/organization_snapshot.dart';
import '../repositories/organization_structure_repository.dart';

final class LoadOrganizationHierarchy {
  const LoadOrganizationHierarchy(this.repository);
  final OrganizationStructureRepository repository;
  Future<OrganizationSnapshot> call({bool includeArchived = false}) =>
      repository.loadHierarchy(includeArchived: includeArchived);
}

final class PreviewOrganizationChange {
  const PreviewOrganizationChange(this.repository);
  final OrganizationStructureRepository repository;
  Future<OrganizationImpactPreview> call(OrganizationChangeSet change) =>
      repository.preview(change);
}

final class ApplyOrganizationChange {
  const ApplyOrganizationChange(this.repository);
  final OrganizationStructureRepository repository;
  Future<void> call(OrganizationChangeSet change) async {
    await repository.apply(change);
  }
}
