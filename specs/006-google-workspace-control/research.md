# Research: Controlled Google Workspace

## Decision: Govern all employee workspace operations through ZaWolf

**Rationale**: The company requires employee-specific authorization and an attributable audit trail. A browser link or direct Google sharing cannot make ZaWolf the enforcement point or prove an employee’s cell-level action.

**Alternatives considered**:

- Direct Google Drive/Sheets sharing: rejected because it bypasses ZaWolf permissions and gives incomplete employee activity evidence.
- Iframe of Google Sheets: rejected because it cannot provide a dependable ZaWolf-owned authorization/audit boundary and does not meet the no-separate-Google-session objective.

## Decision: Use a custom full-page spreadsheet experience for supported work

**Rationale**: The Sheets operations needed for ordinary company use—tab, row/column, value/formula, formatting, validation, copy/paste, and protection behavior—must be performed through the controlled system in order to be authorized, retried, and audited. The controlled editor gives a familiar spreadsheet workflow without exposing Google credentials.

**Alternatives considered**:

- Keep the current limited table/editor: rejected because it causes the known issues of small layout, insufficient navigation, and non-native editing.
- Promise all native Google capabilities immediately: rejected because unsupported object types can lose semantics and cannot be audited safely.

## Decision: Declare capability compatibility per workbook/content type

**Rationale**: A controlled editor must never silently flatten charts, third-party add-ons, scripts, external connectors, or other advanced content. Each resource declares editable, read-only, unsupported, or migration-required capabilities before any destructive action.

## Decision: Append-only ZaWolf audit plus external reconciliation

**Rationale**: Every action that enters through ZaWolf can be attributed to an authenticated employee and given an operation ID. File-level changes found outside ZaWolf may be useful for reconciliation, but cannot safely be assigned to an employee without a verified actor.

## Decision: Report by business-effective period and make report jobs idempotent

**Rationale**: HR records must appear in the period to which attendance, request, or deduction applies—not simply when someone generated a report. One report identity per type/scope/period prevents duplicate official reports when the scheduler or a user retries.

## Decision: Use one scheduler owner and manual recovery paths

**Rationale**: The repository already operates distributed scheduling. Report generation and external reconciliation must each have one live owner, recorded run state, bounded workload, and manual recovery only; duplicate schedulers would create duplicate reports and unnecessary reads.

## Decision: Use queued retry-safe client operations for mutable actions

**Rationale**: A local operation record tracks pending, acknowledged, rejected, or conflict state. The server accepts a stable operation identity and returns a previous result for retries, preventing duplicate rows, files, grants, or reports.
