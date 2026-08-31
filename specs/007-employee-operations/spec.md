# Feature Specification: Employee Operations and Operational Reliability

**Feature Branch**: `007-employee-operations`  
**Created**: 2026-08-23  
**Status**: Draft — awaiting owner review before planning  
**Input**: Improve employee deductions, attendance corrections, tasks/KPIs, notifications, help and chat; improve operational HR/manager/admin controls, sales indicators, request visibility, deep links, safe diagnostics, and Arabic RTL consistency.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understand deductions and correct attendance quickly (Priority: P1)

An employee can see every approved, pending, or cancelled deduction with its Arabic reason, attendance event, affected business period, approval status, and any linked correction request. From a late-arrival entry or discipline indicator, they can start a pre-filled attendance-time correction request without searching through unrelated screens.

**Why this priority**: Employees need a clear, fair explanation of salary-impacting events and a reliable way to contest attendance data.

**Independent Test**: Create late-arrival, absence, and manual deduction fixtures across two payroll periods; verify the employee sees only their details and can submit one correction request from the relevant late event.

**Acceptance Scenarios**:

1. **Given** an employee has a deduction, **When** they open the deduction details from the deductions page or discipline percentage card, **Then** they see a full Arabic explanation, source attendance/request evidence, business-effective period, status, and non-technical next action.
2. **Given** an employee has a late attendance event eligible for correction, **When** they choose the correction action beside that event, **Then** the correction form is pre-filled with the event date/time and submits through the existing approval chain exactly once.
3. **Given** a correction was approved after a payroll boundary, **When** it is reviewed, **Then** its financial treatment remains assigned to the event's business-effective period rather than silently changing the current period.

---

### User Story 2 - Work from one practical task and KPI workflow (Priority: P1)

An employee sees actionable work items and performance indicators together without an impractical forced split. Management can define measurable outcomes, evidence, due dates, and progress while preserving existing task and KPI history.

**Why this priority**: Work assignment must be usable daily; performance tracking must not create duplicate data entry.

**Independent Test**: Assign one measurable work item with a KPI target, update progress and evidence, and verify the employee, manager, and reports show a consistent result without duplicate tasks.

**Acceptance Scenarios**:

1. **Given** a task has an associated KPI, **When** an employee updates progress, **Then** the task and KPI views show the same attributable progress rather than separate conflicting records.
2. **Given** an existing standalone KPI or task, **When** the new workflow is enabled, **Then** existing history stays visible and no assignment is lost.

---

### User Story 3 - Receive reliable notifications, help, and governed communication (Priority: P1)

Employees can clear notification badges reliably, receive correct deep links based on their own role, use a safe Arabic assistant for system guidance and their authorized work context, and communicate with management in a governed conversation. File attachments are stored in the existing governed company Drive area rather than app-managed binary storage.

**Why this priority**: Communication must be useful without leaking data or creating an unmanaged storage system.

**Independent Test**: Mark all notifications read, open a request notification as an approver, ask the assistant a policy question, and send an attachment to a manager; verify badge, route, authorization, audit, and attachment ownership.

**Acceptance Scenarios**:

1. **Given** all notifications are marked read, **When** the notification state refreshes, **Then** the badge count becomes zero across all navigation surfaces.
2. **Given** a manager, HR user, or admin opens a request notification, **When** the route opens, **Then** it opens the managed request context—not the target employee's personal request screen.
3. **Given** an employee uses the assistant, **When** the answer concerns policy, deductions, tasks, or discipline, **Then** it uses only information the employee may see, answers in Arabic, and clearly distinguishes guidance from an HR decision.
4. **Given** a chat attachment is uploaded, **When** it is sent, **Then** it is stored in a governed Drive location, access is checked before every view/download, and the message/audit record contains no public Drive link.

---

### User Story 4 - Give operational leaders accurate, scoped control (Priority: P1)

HR, managers, and admins can hide designated non-operational/test accounts from daily attendance without deleting them, open one employee's attendance and requests for a chosen period, see all request and deduction states permitted by role, and find checkout policy controls under Attendance and Work Policy.

**Why this priority**: Operational decisions are unreliable when test accounts, missing historical records, or poorly placed controls distort the view.

**Independent Test**: Hide a test account, search an employee across a past period, verify approved/pending/cancelled requests and deductions appear in the authorized tabs, and confirm the account remains auditable and recoverable.

**Acceptance Scenarios**:

1. **Given** an authorized HR/admin user hides a test account from operational attendance, **When** daily attendance is opened, **Then** the account is excluded from default operational counts but remains available in an explicit administrative/audit view.
2. **Given** an authorized leader selects an employee and date range, **When** they view the employee timeline, **Then** attendance, leave, permissions, corrections, requests, and deductions use their business-effective dates and are role-scoped.
3. **Given** an old confirmed deduction or late-arrival decision exists, **When** an authorized approver opens the relevant management tab, **Then** it appears exactly once with the correct current state.
4. **Given** a user is not HR or an admin, **When** navigation is built, **Then** security-review functions are not displayed or reachable.

---

### User Story 5 - Trust sales indicators, updates, and Arabic product behavior (Priority: P1)

Authorized leaders see sales indicators for all properly linked employees, with filters that apply to the selected period and linked employee. The system explains incomplete source matching without exposing secrets. Update requirements, errors, arrows, and all user-facing text are consistently Arabic and directionally correct.

**Why this priority**: Sales data and updates affect real management decisions; broken filters and mixed language undermine trust.

**Independent Test**: Use representative linked/unlinked sales identities and multiple filter combinations; verify matching results, Arabic source-health explanation, role access, forced-update recovery, and RTL navigation.

**Acceptance Scenarios**:

1. **Given** a sales source row lacks a stable employee match, **When** an authorized leader views indicators, **Then** it is excluded from employee attribution, counted in a safe reconciliation summary, and never assigned to the wrong employee.
2. **Given** a sales filter is applied, **When** the report refreshes, **Then** totals, charts, employee rows, and exports all use the same filter inputs.
3. **Given** an update is mandatory, **When** the app opens or resumes, **Then** the user sees a clear Arabic update screen with a working retry/update path and cannot become stuck in a loop.

---

### User Story 6 - Detect problems before employees report them (Priority: P2)

The system records privacy-safe operational errors and degradation events, groups them into actionable internal reports, and shows employees only concise Arabic recovery states. Authorized administrators can identify the affected feature, release, environment, and safe diagnostic reference without receiving sensitive employee content.

**Why this priority**: Support must be proactive while protecting employee and payroll data.

**Independent Test**: Simulate authorization failure, unavailable dependency, bad deep link, update check failure, and sales-source mismatch; verify a safe user state and one deduplicated internal diagnostic event for each case.

**Acceptance Scenarios**:

1. **Given** a recoverable failure, **When** it occurs, **Then** employees never see raw Firebase, HTTP, provider, token, stack-trace, or server-error text.
2. **Given** repeated identical failures occur, **When** diagnostics are reviewed, **Then** they are grouped by safe fingerprint and release rather than creating an uncontrolled event flood.

---

### User Story 7 - Give approved employees safe in-app developer tools (Priority: P2)

An authorized administrator can grant a named employee access to the application's
developer tools for diagnosis and controlled testing. The grant is reversible,
expires automatically, and is fully audited. It does not allow USB debugging,
mock location, bypassing device binding, bypassing location validation, or
bypassing attendance/approval authorization.

**Why this priority**: The company needs to diagnose selected employee devices
without weakening attendance anti-fraud controls for the workforce.

**Independent Test**: Grant a test employee the developer-tools entitlement,
verify only the in-app developer menu appears, simulate USB debugging and mock
location signals, and verify attendance remains blocked/reviewed according to
the existing policy; revoke/expire the grant and verify the menu disappears.

**Acceptance Scenarios**:

1. **Given** an authorized HR/admin grants developer tools to one employee,
   **When** that employee signs in, **Then** only the approved in-app developer
   diagnostics surface is available for the granted duration.
2. **Given** that employee tries attendance with USB debugging or mock location,
   **When** the attendance check executes, **Then** existing device and location
   safeguards continue unchanged and the developer grant does not override them.
3. **Given** the grant is revoked or expires, **When** the app refreshes its
   access state, **Then** the developer tools disappear and audit history remains.

### Edge Cases

- An account hidden from daily attendance must not be treated as inactive, absent, deleted, or exempt from access controls.
- A historical request/deduction that crosses a period boundary must preserve effective-date accounting and approval audit history.
- A notification deep link must fall back to the authorized management list when the exact item is no longer viewable.
- A sales row with multiple possible employee matches must remain unresolved until an authorized mapping is selected.
- The assistant must refuse or redirect requests outside the user's access, medical/disciplinary decision authority, or HR approval authority.
- Chat messages and attachments must remain accessible after a Drive synchronization delay, with pending/retry status and no duplicate upload on retry.
- Diagnostics must exclude message bodies, attachment content, salary values, tokens, passwords, and raw provider responses.
- An in-app developer-tools entitlement must never relax USB-debugging,
  mock-location, device-binding, geofence, payroll, or approval safeguards.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a detailed Arabic deduction view showing reason, source, dates, period allocation, decision trail, amount/day impact where authorized, and correction/request links.
- **FR-002**: The system MUST provide a fast pre-filled attendance-correction entry point from eligible late attendance and discipline surfaces.
- **FR-003**: The system MUST preserve payroll-cycle, approval-date, execution-date, and business-effective-date semantics for all correction and deduction views.
- **FR-004**: The system MUST provide a unified task-performance workflow that links work progress to measurable outcomes without duplicating task or KPI history.
- **FR-005**: The system MUST keep notification badge state synchronized after individual and bulk read actions.
- **FR-006**: The system MUST route every notification to a role-authorized target screen; approvers MUST be routed to the management context.
- **FR-007**: The system MUST provide an Arabic employee assistant limited to authorized system guidance and the employee's permitted task/discipline context; it MUST not make HR, payroll, disciplinary, or management decisions.
- **FR-008**: The system MUST provide authorized employee-to-management conversations with membership checks, Arabic safe states, and governed attachment storage in Company Drive; it MUST not expose raw Drive links or credentials.
- **FR-009**: Authorized HR/admin users MUST be able to hide and restore non-operational accounts from default attendance analytics while retaining audit visibility.
- **FR-010**: Authorized leaders MUST be able to view one employee's attendance, requests, corrections, leave/permissions, and deductions for a selected business-effective period.
- **FR-011**: Request and deduction management screens MUST return all role-authorized records across pending, approved, rejected, cancelled, confirmed, and historical states without duplicate rows or indefinite loaders.
- **FR-012**: Checkout policy controls MUST appear under Attendance and Work Policy and leave-permission flows MUST remain independent of whether checkout is enabled.
- **FR-013**: Sales indicators MUST use a deterministic employee mapping, expose unresolved source rows only to authorized administrators, and apply one consistent filter contract to all visual and export outputs.
- **FR-014**: Security-review features MUST be visible and reachable only to HR and authorized admins.
- **FR-015**: Mandatory-update checks MUST have Arabic, accessible, recoverable UI and must not cause repeated app/session resets during normal resume.
- **FR-016**: The system MUST record privacy-safe diagnostic events, apply deduplication/rate limits, and provide authorized internal diagnostic reports.
- **FR-017**: All new or migrated Phase 007 interfaces MUST be Arabic RTL by default, use correct back/forward directionality, retain normal browser selection/copy behavior, and avoid unnecessary empty desktop/mobile space.
- **FR-018**: All changes MUST preserve server-authoritative authorization, idempotency, offline/pending/retry behavior, and safe user-facing error messages.
- **FR-019**: Authorized HR/admin users MUST be able to grant, revoke, and set
  an expiry for an employee-specific in-app developer-tools entitlement, with a
  complete audit trail.
- **FR-020**: The developer-tools entitlement MUST expose only approved
  diagnostic/testing surfaces and MUST NOT bypass or weaken USB debugging,
  mock location, geofence, device binding, attendance, payroll, request, or
  approval checks.

### Key Entities

- **Deduction Explanation**: Employee-visible, role-scoped explanation of a payroll deduction and its underlying attendance/request/approval evidence.
- **Attendance Correction Shortcut**: An eligible attendance event paired with a pre-filled correction draft and idempotent submission identity.
- **Work Outcome**: A unified representation of task progress, evidence, target, and KPI contribution.
- **Conversation**: A role-scoped employee/management discussion with membership, retention state, and audit metadata.
- **Governed Attachment**: A chat attachment stored in the controlled company workspace with resource identity and access policy.
- **Operational Visibility Setting**: A reversible, audited setting that excludes an account from default operational reporting without deleting the account.
- **Sales Identity Mapping**: A reviewed mapping between an external sales identity and one ZaWolf employee, including unresolved/conflict state.
- **Diagnostic Event**: A sanitized, deduplicated internal error/degradation record with feature, release, safe fingerprint, and recovery outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance tests, 100% of employee deduction records expose a clear Arabic reason and business-effective period to the affected employee without revealing another employee's data.
- **SC-002**: An eligible employee can open and submit a correction draft from a late-attendance item in under 60 seconds, with no duplicate request in 100% of retry tests.
- **SC-003**: Marking all notifications read reduces every visible badge to zero within five seconds in 95% of normal-connectivity tests.
- **SC-004**: Authorized request/deduction management queries return the expected historical and current records within ten seconds in 95% of representative test cases and never show an indefinite loader.
- **SC-005**: All tested sales dashboards, charts, lists, and exports agree with the selected filters and never attribute an unresolved external row to an employee.
- **SC-006**: In simulated failures, 100% of employee-facing messages are Arabic safe recovery states with no raw technical message; corresponding diagnostic records are available to authorized administrators.
- **SC-007**: All Phase 007 acceptance screens pass RTL, keyboard/back navigation, mobile, and desktop layout checks.
- **SC-008**: In entitlement tests, 100% of grants/revocations/expirations are
  audited and 100% of mock-location and USB-debugging attendance protections
  remain unchanged while the entitlement is active.

## Assumptions

- The existing attendance and payroll specifications remain authoritative and must be read before changing correction, period, deduction, or attendance logic.
- Existing Firebase authentication and server-side authorization remain the identity authority; client role checks are only presentation convenience.
- Phase 007 begins with a governed assistant that does not transmit confidential employee data to an external AI service. Selecting and approving any external AI provider, retention policy, and budget is a separate owner decision.
- Chat attachments use the existing controlled Company Drive integration; message metadata requires a durable governed record and must not rely on an employee's personal Drive.
- The supplied sales API credential is treated as a server secret, is not embedded in Flutter/web code, and will be rotated because it was shared in chat.
- Phase 006 controlled Workspace remains separate and deployable; its unresolved live acceptance gates are not implicitly completed by Phase 007.
