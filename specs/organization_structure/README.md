# organization_structure

Specification source of truth: the reviewed phase documents under
`specs/007-employee-operations/` and `.specify/memory/constitution.md`
governing organizational hierarchy (roles, departments, manager chains).

This pointer directory exists so the architecture guard
(`test/architecture_guard_test.dart`, "every migrated feature has a
specification directory") can bind `lib/features/organization_structure` to
its reviewed specification without moving numbered spec directories.
