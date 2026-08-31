# Data Model: Controlled Google Workspace

## Workspace Source

Represents an approved company root or logical area such as a department, HR, employee, or Reports.

| Field | Rules |
|---|---|
| id | Stable internal identity; never derived from a client-supplied provider ID. |
| name, type, parent | Required hierarchy and display information. |
| owner scope | Identifies controller/department/HR ownership. |
| connection state | Configured, syncing, ready, degraded, or disabled. |
| capability profile | Declares editable/read-only/unsupported content features. |
| version | Used for safe changes and reconciliation. |

## Workspace Resource

Represents a folder, file, spreadsheet, tab, or generated report exposed inside ZaWolf.

| Field | Rules |
|---|---|
| id | Stable internal resource ID. |
| source and parent | Must form a valid governed hierarchy. |
| kind and external reference | Provider reference remains server-side. |
| name, state, timestamps | Safe metadata for the allowed user scope. |
| classification | Department, employee, HR, report, or shared-company scope. |
| capability profile | Inherited and optionally narrowed from source policy. |

## Workspace Access Grant

Represents a revocable policy assignment.

| Field | Rules |
|---|---|
| subject | One employee, team, department, or role scope. |
| target | One source/resource/subtree. |
| capability | View, download, comment, edit, manage-content, or manage-access. |
| status and validity | Active/revoked, optional effective period. |
| granted/revoked evidence | Actor, time, policy reason, operation identity. |

Effective access is evaluated on every sensitive request. A more specific deny or revoked state takes precedence over an inherited grant.

## Spreadsheet Operation

Represents an intended read or mutation initiated from ZaWolf.

| Field | Rules |
|---|---|
| operation ID | Client-generated/retry-safe identity; unique per intended action. |
| actor and permission snapshot | Captured at authorization time. |
| target | Resource, tab, range, folder/file where applicable. |
| action | Read, edit, paste, format, structure, tab, file, access, or report action. |
| state | Pending, acknowledged, rejected, conflict, or abandoned. |
| expected version | Required for mutable conflict-aware operations. |
| result/evidence | Safe success result or user-facing remediation, never a raw secret. |

State transitions: `pending → acknowledged`, `pending → rejected`, or `pending → conflict`; a controlled retry may re-enter `pending` with the same operation ID only where it is safe.

## Workspace Audit Event

An append-only record generated for each ZaWolf-originated action and separately for external observations.

| Field | Rules |
|---|---|
| event ID and time | Immutable event identity and Cairo-displayable timestamp. |
| attribution | ZaWolf-verified actor or external/unattributed status. |
| action and outcome | Required taxonomy and success/failure/pending result. |
| target | Resource, tab, range, and path only within permitted audit scope. |
| safe diff summary | Before/after summary or protected hash; never exposes unapproved sensitive content. |
| operation ID | Required for deduplication of ZaWolf-originated events. |

## Report Run and Report Resource

Represents one governed report generation outcome.

| Field | Rules |
|---|---|
| report key | Unique by report type, authorized scope, business period, and version. |
| period | Daily, weekly, monthly, or custom start/end in Cairo time. |
| data family | Workspace activity, attendance, request, or deduction. |
| state | Queued, generating, ready, failed-retryable, or superseded. |
| output resource | Protected report resource inside the appropriate Reports/HR Reports hierarchy. |
| generation audit | Actor/schedule identity, inputs summary, completion time, and retry evidence. |

## Compatibility Capability

Defines an operation or content element as editable, read-only, unsupported, or migration-required. It is evaluated before mutations and shown to users in clear Arabic rather than silently changing document content.

## Relationships

```text
Workspace Source 1 ── * Workspace Resource
Workspace Resource 1 ── * Workspace Access Grant
Workspace Resource 1 ── * Spreadsheet Operation
Spreadsheet Operation 1 ── 1..* Workspace Audit Event
Report Run 1 ── 1 Workspace Resource
Workspace Activity / HR data ── * Report Run
```
