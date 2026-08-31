# Current-State Audit: Company Workspace

**Audited**: 2026-08-20  
**Purpose**: Establish a non-destructive migration baseline for Phase 006.

## Current client surface

| Surface | Current file | Observed behavior / limitation |
|---|---|---|
| Workspace landing/admin center | `lib/screens/shared/company_workspace_center_screen.dart` | Uses direct service calls and local `StatefulWidget` state; mixes resource management, access, discovery, bootstrap, audit and UI. |
| Folder browser | `lib/screens/shared/workspace_folder_browser_screen.dart` | Opens folder and file resources from a legacy model. |
| Sheet editor | `lib/screens/shared/workspace_sheet_editor_screen.dart` | Uses `PlutoGrid`, reads up to 500 rows and 702 columns, then sends row-oriented updates/individual operations. It is not a feature-first Cubit slice and has known desktop/full-page interaction limitations. |
| HR Sheets export | `lib/screens/hr/sheets_export_screen.dart` | Legacy report/test integration that must be retained until V2 report parity. |
| Legacy models/service | `lib/models/company_workspace_models.dart`, `lib/services/company_workspace_service.dart`, `lib/services/google_workspace_service.dart` | Direct Firestore and HTTP dependencies from legacy UI/service paths. |
| Route | `lib/navigation/router.dart` | `CompanyWorkspaceCenterScreen` is the existing public Company Files route target. |

## Current server/integration surface

| Capability | Current location | Observed behavior / limitation |
|---|---|---|
| Google connector | `scripts/google-sheets-integration.js` | Provides Drive/Sheets integration, discovery, structure setup, sheet reads, formatting, structure and tab changes. |
| HTTP router | `scripts/notification-web.js` | Hosts Company Workspace endpoints inside a large notification runtime router. |
| Authorization | `workspaceResourceFor` in `scripts/notification-web.js` | Evaluates resource/controller/manager/direct grant on requests, but only supports legacy permission values and resource model. |
| Audit | `recordWorkspaceAudit` in `scripts/notification-web.js` | Append-only Firestore write exists but action taxonomy/deduplication/attribution-confidence are incomplete. |
| Discovery/bootstrap | `syncCompanyWorkspace` and `bootstrapCompanyWorkspace` in `scripts/notification-web.js` | Uses full tree/discovery routines, root config, lock, resources/secrets/grants. Must be bounded/progress-resumable before large production syncs. |
| Sheet delivery | `handleCompanyWorkspace` in `scripts/notification-web.js` | Reads a single sheet response capped to 500 rows; mutations are operation-specific and do not take a stable client operation ID/version token. |
| Reports | `/company-workspace/reports/audit` in `scripts/notification-web.js` | Audit report exists; daily/weekly/monthly workspace + HR reports and durable report-run identities do not yet exist. |

## Firestore data and rule baseline

| Collection / rule | Evidence | Migration rule |
|---|---|---|
| `workspaceResources` | `company_workspace_service.dart`, `firestore.rules` | Preserve existing resources; V2 adds compatibility/source/version metadata non-destructively. |
| `workspaceResourceSecrets` | `notification-web.js` | Keep provider IDs server-side. Never return them to the Flutter client. |
| `workspaceAccessGrants` | `company_workspace_service.dart`, `firestore.rules` | Keep legacy direct grants readable; introduce a V2 effective-policy model alongside them before switching. |
| `workspaceAuditLogs` | `company_workspace_service.dart`, `notification-web.js`, `firestore.rules` | Preserve legacy audit history; append V2 taxonomy, operation ID, attribution confidence, and safe diff fields. |
| `workspaceSchemaProfiles` / templates | `company_workspace_service.dart` | Continue compatibility mapping during transition; do not force a profile on every existing spreadsheet. |

## Scheduler ownership baseline

The existing Company Workspace actions are request-driven in
`scripts/notification-web.js`. Audit reporting is explicitly requested by the
client; no dedicated, documented scheduler owns recurring Workspace or HR
reports. Phase 006 must introduce exactly one owner for recurring report and
external-activity reconciliation jobs, with persistent run identity and manual
recovery paths. It must not add a second GitHub/Hostinger schedule for the same
responsibility.

## Known gaps that V2 closes

1. No clean feature-first boundary or focused Cubits.
2. Limited Sheet viewport/editor interaction and no capability compatibility
   declaration for advanced content.
3. No stable operation ID, outbox, version conflict contract, or reliable
   deduplicated retry for every mutation.
4. Direct-grant-only permission model; no full dynamic role/team/department
   policy evaluation.
5. Audit events are not complete enough for all required action categories and
   cannot distinguish verified ZaWolf work from external Google activity.
6. No idempotent daily/weekly/monthly/custom Workspace and HR report runs.
7. Discovery can do broad work; the migrated implementation must page, resume,
   report progress, and receive a read-budget test.

## Migration invariants

- Legacy routes, resource IDs, grants, secrets, and audit events remain intact
  until V2 parity, pilot evidence, rollback testing, and explicit owner approval.
- No credential, root ID, unrestricted external link, or unscoped provider
  metadata is returned to employees.
- V2 must reject unauthorized requests server-side even when an old client
  retains cached route/resource data.
- Attendance, requests, payroll, and deductions are read-only inputs for V2
  reports; their business calculations and approval behavior are not changed.
