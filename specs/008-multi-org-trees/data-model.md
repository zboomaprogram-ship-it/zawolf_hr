# Data Model: Multiple Organization Trees

## OrganizationTree

- `id`, `name`, `purpose`, `status` (`draft|active|archived`)
- `rootLeaderUid?`, `version`, `order`, `createdAt`, `updatedAt`
- `isDefault` identifies the compatibility/default tree; exactly one active default

## OrganizationTreeUnit

- `id`, `treeId`, `type` (`sector|department`), `parentUnitId?`
- `name`, `managerUid?`, `memberCount`, `order`, `status`, `version`
- Unit IDs are opaque; uniqueness of names is scoped to sibling units in a tree.

## OrganizationTreeMembership

- `id = treeId_employeeUid_unitId`
- `treeId`, `employeeUid`, `unitId`, `directManagerUid?`, `title?`
- `isPrimary`, `status`, `effectiveFrom`, `effectiveTo?`, `version`
- At most one active primary membership exists per employee across all trees.

## TreeLeadershipAssignment

- `id`, `treeId`, `employeeUid`, `kind` (`root|administrator`)
- `effectiveFrom`, `effectiveTo?`, `grantedBy`, `version`

## Compatibility Projection

The primary membership transaction projects `departmentUnitId`, `departmentId`,
`managerId`, and ordered `managerIds` to the existing user record. It records the
source membership and version so retries converge and stale changes conflict.

## Invariants

1. A unit belongs to one tree; a department parent belongs to the same tree.
2. A membership references an active employee and a unit in the same tree.
3. Root leadership and tree administration never imply primary membership.
4. Primary replacement and compatibility projection commit atomically.
5. Materialized approval plans are never rewritten.

