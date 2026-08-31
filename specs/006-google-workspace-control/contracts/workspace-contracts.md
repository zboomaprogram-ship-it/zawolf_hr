# Controlled Workspace Contracts

These contracts define behavior at the ZaWolf boundary. They do not expose provider credentials, root IDs, or unrestricted external URLs.

## Authorization Contract

Every operation takes the current authenticated ZaWolf identity and a stable internal resource ID. The server resolves effective access on each request.

**Inputs**: actor identity, resource ID, requested action, optional path/tab/range, operation ID for mutations.

**Outputs**: allowed capability set and safe resource data, or an Arabic access-denied result with no protected resource detail.

## Resource Navigation Contract

Lists one permitted directory page at a time, returning only resources the actor may discover. It includes a continuation cursor/progress state for large hierarchies, current path, and scoped actions.

## Spreadsheet Read Contract

Reads a viewport/selected range and its compatible metadata: tab list, cells, formulas, display values, dimensions, validation, labels, notes, hyperlinks, formats, merges, and supported protections. It includes a version token and capability declaration.

## Spreadsheet Mutation Contract

Accepts one or batched authorized operation with operation ID, expected version, target range/structure, and requested content/format. It returns exactly one of acknowledged, pending-safe-retry, conflict, denied, validation failure, or temporary-unavailable. Every final result is tied to an audit event.

## Drive Mutation Contract

Supports authorized create/upload/download/rename/move/copy/trash/restore and folder creation using stable operation IDs. A retry returns the same final resource identity rather than creating another resource.

## Access Administration Contract

Allows only current Super Admins and dynamic IT Managers to create, narrow, revoke, and inspect grants. It records who changed access, why, and when. An access change becomes effective before the next protected action.

## Report Contract

Accepts an authorized report type, scope, and Cairo business period. It returns a report-run identity and state. A repeated submission of the same report key returns the existing official report or a controlled replacement version. It never returns an unscoped raw export.

## Safe Error Contract

All user-visible failures map to Arabic status families: saved, pending sync, retry now, check status, access denied, validation correction, conflict review, or administrator action required. Technical provider messages remain server diagnostic data only.
