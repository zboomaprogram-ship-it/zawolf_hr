# Feature Specification: Controlled Google Workspace

**Feature Branch**: `006-google-workspace-control`  
**Created**: 2026-08-20  
**Status**: Draft — awaiting owner review before planning  
**Input**: Build ZaWolf as the company’s governed Google Sheets and Google Drive workplace. Employees work through ZaWolf rather than visiting Google in a browser; authorized administrators control access; every in-system action is auditable; daily, weekly, monthly, and HR operational reports are saved as Sheets in the company report folders.

## User Scenarios & Testing

### User Story 1 - Work only in assigned company files (Priority: P1)

An active employee opens **Company Files** in ZaWolf and can browse only folders and files assigned to them. They can create, upload, download, rename, move, copy, and delete items only where their granted access permits it. They do not need or receive direct access to the company’s Google Drive or Sheets in a separate browser session.

**Why this priority**: This is the essential security boundary: ZaWolf must become the employee’s controlled entry point to company documents.

**Independent Test**: Grant one employee access to one department folder and one spreadsheet, then verify they can complete allowed actions while another employee cannot discover, open, download, or modify either resource.

**Acceptance Scenarios**:

1. **Given** an employee has a view-only grant to a file, **When** they open Company Files, **Then** they can view and download only that allowed file and cannot modify it.
2. **Given** an employee has an editor grant to a department folder, **When** they create, upload, move, rename, copy, or delete a permitted item, **Then** the action succeeds once, is visible after refresh, and has an audit event tied to that employee.
3. **Given** an employee has no grant to a resource, **When** they search, guess a URL, or use a previously opened link, **Then** no resource details, contents, or download are exposed.

---

### User Story 2 - Use a reliable spreadsheet workspace (Priority: P1)

An employee with editor access opens a Sheet in a full-page ZaWolf spreadsheet workspace. They work directly in cells, select one or more cells/rows/columns, use keyboard copy/paste and search, manage rows, columns, tabs, formulas, data validation, labels, notes, and normal formatting without a dialog for each ordinary cell edit. The workspace accurately reflects saved content and clearly tells the employee whether a change is saved, pending, or needs attention.

**Why this priority**: The company cannot stop using direct Google Sheets unless everyday spreadsheet work is practical, familiar, and reliable in ZaWolf.

**Independent Test**: An editor opens an assigned Sheet, adds a second tab, pastes a multi-cell range, inserts a row and column, changes a cell format and formula, filters/searches values, saves, reopens the Sheet, and sees the same result.

**Acceptance Scenarios**:

1. **Given** a Sheet editor, **When** they change one or many selected cells, **Then** the change is saved as one attributable operation or is shown as pending for safe retry; it is never silently lost.
2. **Given** a selected range, **When** the editor inserts or removes permitted rows, columns, or tabs, **Then** surrounding data and formulas remain consistent with the selected structural operation.
3. **Given** a Sheet with supported labels, checkboxes, validation choices, notes, hyperlinks, formulas, merged cells, and formatting, **When** it opens in ZaWolf, **Then** those elements render meaningfully and remain usable according to the employee’s access level.
4. **Given** a keyboard user, **When** they use common selection, copy, paste, undo/redo, and find commands inside the spreadsheet workspace, **Then** the command affects the intended spreadsheet content and does not unexpectedly leave the application.

---

### User Story 3 - Control company access centrally (Priority: P1)

A Super Admin or an active IT Manager controls the company folder hierarchy, connects existing company folders and files, assigns access by employee, manager team, department, or role, and can immediately revoke or narrow access. A person’s authority comes from their active ZaWolf role and IT-management assignment, never from a hard-coded employee code.

**Why this priority**: Central, dynamic access control is required before employees can safely use the system for all company data.

**Independent Test**: An authorized controller imports an existing department folder, grants editor access to one employee, changes the grant to view-only, then revokes it; each change takes effect on the next access attempt and is recorded.

**Acceptance Scenarios**:

1. **Given** an authorized controller, **When** they connect a root folder or import an existing hierarchy, **Then** its folders and files can be mapped into ZaWolf without exposing underlying Google credentials to employees.
2. **Given** a manager is reassigned away from IT management, **When** their ZaWolf role/profile changes, **Then** they lose workspace-controller capability without a code deployment while their past audit events remain visible to authorized auditors.
3. **Given** an access grant changes, **When** the affected employee next opens, refreshes, downloads, uploads, or edits a resource, **Then** the new permission is enforced before content is returned or modified.

---

### User Story 4 - Audit work and generate reports (Priority: P1)

Administrators and authorized HR users receive protected daily, weekly, and monthly Google Sheets reports in the company Reports folder. The reports summarize employee workspace activity and HR operational data for a chosen period, including attendance, requests, and deductions. The report makes a clear distinction between actions performed through ZaWolf and any externally detected file activity.

**Why this priority**: Management needs evidence of employee work without trusting unaudited direct access or manually compiling files.

**Independent Test**: Perform a representative set of employee actions through ZaWolf, generate a daily report, and verify it includes the correct actor, time, file/Sheet/range, action, outcome, and HR period data; rerunning the same period does not create duplicate official report rows.

**Acceptance Scenarios**:

1. **Given** an employee performs a permitted action through ZaWolf, **When** an authorized report is generated, **Then** the report identifies the actor, time, target, action, result, and permitted change summary.
2. **Given** HR selects a day, week, month, or custom period, **When** they generate an HR operational report, **Then** the report contains only attendance, request, and deduction records in that period and is saved in the HR reports area.
3. **Given** an automated reporting schedule and a manual retry occur for the same report period, **When** both complete, **Then** there is one official report version or a clearly versioned replacement—not duplicate untraceable reports.

---

### User Story 5 - Recover safely from unreliable connections (Priority: P2)

An employee who temporarily loses connection sees a clear Arabic status and can continue with queued safe actions where allowed. On recovery, ZaWolf either completes the action exactly once or asks the employee to resolve a conflict; it never shows raw provider errors, leaves a blank editor, or falsely says a change was saved.

**Why this priority**: Document work is frequent and must remain dependable on variable mobile and office networks.

**Independent Test**: Interrupt connectivity during an edit, upload, delete, and report request. Restore connectivity and verify each operation has one final, visible outcome with no duplicate content or opaque technical message.

**Acceptance Scenarios**:

1. **Given** a transient service interruption, **When** an employee submits an idempotent workspace action, **Then** they see an Arabic pending/retry/status-check state rather than a Google, Firebase, HTTP, or raw exception message.
2. **Given** a concurrent edit conflicts with a pending local change, **When** synchronization resumes, **Then** the employee is shown the affected item and a safe resolution path; neither version is silently overwritten.

### Edge Cases

- A direct Google-side change by a company owner or an integration must be marked as externally detected or unattributed unless ZaWolf has an authenticated, verifiable actor; it must never be attributed to an employee without evidence.
- If an employee has a direct Google share outside ZaWolf, the system cannot guarantee monitoring of that direct work. Launch controls must prevent or revoke such shares for employees covered by the controlled-workspace policy.
- A copied item must receive a new identity and audit history while retaining a safe link to its source; a retry must not produce multiple copies.
- A folder containing a very large hierarchy must display progress, allow a safe retry/resume, and avoid a blank or indefinitely loading screen.
- A report period with no data must still create a clearly marked empty report or clear empty-state result, not a failed export.
- Deletion must be recoverable where the company retention policy permits; permanent deletion requires explicit authorized confirmation and an audit event.
- A report must not expose files, employee details, formulas, or HR data outside the reader’s authorized scope.
- Unsupported advanced spreadsheet behavior must be identified before modification and protected from accidental loss; the user must receive a clear safe message and an approved alternative rather than a broken editor.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST provide a ZaWolf Company Files area as the controlled employee entry point for assigned company folders, files, and spreadsheets.
- **FR-002**: The system MUST enforce access for every browse, search, preview, open, download, upload, create, rename, move, copy, delete, and spreadsheet operation based on the current active ZaWolf identity and grant.
- **FR-003**: Only Super Admins and employees currently designated as IT Managers by their active role/profile MAY administer global workspace sources, folder structure, and access policy. This authority MUST be dynamic and MUST NOT depend on a fixed employee code.
- **FR-004**: The system MUST support employee-, team-, department-, role-, and resource-specific grants with at least view, download, comment, edit, manage-content, and manage-access capabilities, and must define which actions each capability permits.
- **FR-005**: The system MUST allow authorized controllers to connect and organize existing company folders and files, including employee resources within their department folder hierarchy, without requiring one manual source record per employee file.
- **FR-006**: The system MUST keep employees from receiving or seeing Google service credentials, root-folder identifiers, or unrestricted direct Google links.
- **FR-007**: The spreadsheet workspace MUST support direct in-cell editing, multi-cell selection, keyboard clipboard actions, find, formulas, multiple tabs, adding/renaming/removing tabs, adding/removing rows and columns, normal cell formatting, cell colors, labels, validation choices, checkboxes, notes, hyperlinks, sorting/filtering, and permitted range protection.
- **FR-008**: The spreadsheet workspace MUST render supported existing spreadsheet content, including values, formula results, formatting, labels, validation controls, notes, hyperlinks, merged cells, row/column dimensions, and tab names, without replacing these elements with plain unstructured text.
- **FR-009**: The system MUST make spreadsheet editing available on a full-page responsive workspace with horizontal and vertical navigation, readable row/column headers, and no unnecessary empty layout space. All Company Files screens MUST support normal browser text selection, copy, keyboard search, and accessible navigation unless a focused spreadsheet command legitimately owns that shortcut.
- **FR-010**: The system MUST record an append-only audit event for each Company Files action initiated through ZaWolf, including actor, Cairo timestamp, target, action type, outcome, affected file/folder/Sheet/range where relevant, and a safe before/after summary or tamper-evident value summary.
- **FR-011**: The audit model MUST distinguish view, search, preview, upload, download, create, rename, move, copy, delete, restore, comment, edit, format, formula, row/column change, tab change, access grant, access revocation, and report-generation actions.
- **FR-012**: The system MUST capture clipboard copy and paste actions that occur inside the ZaWolf spreadsheet workspace when technically available, while not claiming to monitor actions performed outside ZaWolf.
- **FR-013**: The system MUST reconcile externally detected file-level activity separately from ZaWolf-originated audit events and label it as external/unattributed until a verified actor is available.
- **FR-014**: The system MUST produce protected daily, weekly, monthly, and on-demand custom-period workspace-activity reports as Google Sheets in the company Reports folder. Reports MUST be readable by authorized administrators and may be granted to relevant managers only within their scope.
- **FR-015**: The system MUST produce protected daily, weekly, monthly, and custom-period HR reports for attendance, requests, and deductions as Google Sheets in the HR Reports folder. The period used for a request, attendance record, or deduction MUST follow its business-effective date rather than the report-generation date.
- **FR-016**: Report generation MUST be idempotent for a report type, scope, and period, and MUST retain version/audit information when an authorized regeneration is required.
- **FR-017**: The system MUST give authorized HR users period filters and report discovery inside ZaWolf; it MUST not require them to open Google Sheets in a separate browser session to find a report.
- **FR-018**: Every workspace operation MUST expose clear Arabic saved, pending-sync, retry, conflict, access-denied, or status-check feedback and MUST NOT expose raw Google, Firebase, network, HTTP, or server exception text to employees.
- **FR-019**: The system MUST use retry-safe operation identities and conflict-aware synchronization for mutations so an interrupted submission does not duplicate a file, row, report, audit event, or access grant.
- **FR-020**: The system MUST preserve existing Company Workspace access records and provide a staged migration, verification, feature switch, and rollback plan before the new controlled workspace becomes the default route.
- **FR-021**: The system MUST provide explicit loading, empty, error, retry, offline, pending-sync, conflict, Arabic RTL, desktop-web, and mobile-web acceptance states for each migrated workspace screen.
- **FR-022**: The system MUST not promise support for advanced capabilities that cannot preserve meaning and audit guarantees in the controlled workspace. Such capabilities must remain protected/read-only until a later approved compatibility slice supports them.

### Key Entities

- **Workspace Source**: A governed company root, department, HR, employee, or reports content source with owner, scope, synchronization state, and access policy.
- **Workspace Resource**: A folder, file, spreadsheet, tab, or report exposed through ZaWolf with parent relationship, content type, source link, lifecycle, and policy scope.
- **Workspace Access Grant**: A time-aware, revocable permission assignment to an employee, team, department, role, or resource.
- **Spreadsheet Operation**: One retry-safe user-initiated mutation or read action with intended target, operation type, state, conflict information, and final result.
- **Workspace Audit Event**: An append-only record of a ZaWolf-originated action or externally detected activity, including attribution confidence and safe change summary.
- **Workspace Activity Report**: A governed daily, weekly, monthly, or custom-period report covering permitted employee file and spreadsheet activity.
- **HR Operational Report**: A governed period report for attendance, requests, and deductions, retained in the HR reports area with its business-effective date scope.
- **Compatibility Capability**: A declared statement of which spreadsheet behavior is editable, read-only, unsupported, or pending migration so no document element is silently damaged.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of tested browse, download, upload, create, rename, move, copy, delete, access, and supported spreadsheet mutations performed through ZaWolf have exactly one corresponding attributable audit event.
- **SC-002**: In role-scope acceptance tests, employees cannot discover, preview, download, or edit another employee’s ungranted resource in 100% of tested direct-link, search, refresh, and stale-session cases.
- **SC-003**: A permitted editor can complete a representative spreadsheet task—add a tab, edit a multi-cell range, insert a row and column, apply a format, and save—in under five minutes without leaving ZaWolf.
- **SC-004**: Under normal connectivity, an authorized user receives either ready content, a valid empty state, or actionable retry guidance within 10 seconds for 95% of tested folder, file, and Sheet opens.
- **SC-005**: Repeating the same interrupted operation and retry sequence produces no duplicate files, tabs, rows, report contents, grants, or audit entries in 100% of tested cases.
- **SC-006**: Daily, weekly, monthly, and custom-period activity and HR reports are generated or safely marked for retry within 15 minutes of request/schedule completion, are discoverable inside ZaWolf, and contain the expected selected-scope records in acceptance tests.
- **SC-007**: In employee acceptance tests, no raw provider or technical error text is displayed for denied, temporary-unavailable, malformed, or conflict scenarios.
- **SC-008**: Before default rollout, all existing workspace resources have a documented migration result, accessible rollback path, and parity evidence for the supported capabilities they currently expose.

## Assumptions

- Existing ZaWolf authentication, active employee records, departments, manager relationships, Cairo time zone, and safe-error foundation remain the authoritative identity and policy inputs.
- The company retains a controlled Google account/service identity with access to the approved root folders and reporting destinations; its credentials remain server-side only.
- Company owners may retain direct Google access for recovery and source maintenance. Employees subject to this policy will not retain direct sharing that bypasses ZaWolf controls.
- The first delivery focuses on common operational spreadsheet and Drive work. Advanced native Google behavior such as third-party add-ons, scripts/macros, external data connectors, unrestricted real-time collaboration, or unsupported visual objects is not assumed editable until its compatibility behavior is separately approved.
- Existing attendance, request, payroll, and deduction rules remain authoritative. This phase exports governed reports; it does not change those business calculations or approval policies.
- Phase 005 remains deferred. This phase is an additive migration of the existing Company Workspace, not a rewrite of unrelated HR/ERP areas.
