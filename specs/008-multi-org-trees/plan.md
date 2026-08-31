# Implementation Plan: Multiple Organization Trees

**Branch**: `008-multi-org-trees` | **Date**: 2026-08-24 | **Spec**: [spec.md](spec.md)

## Summary

Extend the Phase 005 organization slice beside the current single-tree model.
Introduce tree-scoped units and many-to-many employee memberships, while one
primary membership maintains the current user department/manager projection.
All changes use authenticated, versioned Hostinger operations, a local outbox,
bounded reads, safe Arabic states, audit events, and a disabled-by-default flag.

## Technical Context

**Language/Version**: Dart 3.9 / Flutter 3.x; Node.js JavaScript on Hostinger  
**Dependencies**: BLoC/Cubit, Drift, authenticated operation client, Firestore Admin  
**Storage**: Firestore canonical aggregates; Drift UI cache/outbox  
**Testing**: flutter_test, Node test runner, architecture/query guards  
**Platforms**: Android, iOS, responsive web  
**Performance**: bounded pages up to 100; usable state within 10 seconds  
**Constraints**: no production rule change, no destructive migration, old approval
plans immutable, primary routing deterministic, Arabic RTL, no raw provider errors

## Constitution Check

- **Strangler Fig**: PASS — `company_os_multi_tree_v1` selects the additive slice.
- **Layer boundaries**: PASS — domain owns tree/membership contracts.
- **Focused Cubits**: PASS — selector, hierarchy, memberships, and mutation state are separate.
- **Payroll/attendance safety**: PASS — only the existing canonical projection is
  changed atomically; calculations and history are untouched.
- **Test first**: PASS — current single-tree routing and projection get characterization tests first.
- **Offline/sync**: PASS — writes use operation ID, expected version, outbox, and visible state.

## Architecture and Migration

```text
Tree selector/editor Cubits
        -> domain use cases
        -> repository + Drift cache/outbox
        -> authenticated organization API
        -> trees / units / memberships / audit
                     |
          primary projection transaction
                     |
            existing users manager fields
```

The migration dry run creates a default tree and maps current units and employees.
Apply writes new records and compatibility projections but deletes nothing. Reads
fall back to the Phase 005 single-tree repository while the flag is off. Rollback
disables the route and keeps the new data dormant.

## Project Structure

```text
lib/features/organization_structure/
  data/{local,remote,repositories}/
  domain/{entities,repositories,services,use_cases}/
  presentation/{cubit,pages,widgets}/
scripts/company-os/
test/features/organization_structure/
scripts/test/
specs/008-multi-org-trees/
```

## Verification and Rollout

1. Characterize current hierarchy, manager projection, and request routing.
2. Add domain model and server contract tests.
3. Add API and local outbox adapters.
4. Add tree selector and editor behind the flag.
5. Run dry-run migration and non-production role/routing matrix.
6. Pilot one secondary tree; verify reads, audit, conflicts, and rollback.
7. Owner-approved default switch; retire legacy only in a later reviewed change.

No constitution exceptions are required.

