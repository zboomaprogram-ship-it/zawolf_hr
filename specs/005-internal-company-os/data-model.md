# Data Model: Internal Company OS Foundation

All timestamps are server-authored and presented in `Africa/Cairo`. Mutable
aggregates carry `version`; synchronized client operations carry an
`operationId` and explicit sync state.

## OperationalRoleGrant

- `id`, `employeeUid`, `role`, `scopeType`, `scopeIds`
- `active`, `startsAt`, `expiresAt`, `grantedBy`, `createdAt`, `revokedAt`
- Roles: `employee`, `it_support`, `it_manager`, `finance`, `manager`,
  `admin`, `super_admin`
- A grant augments operational capability and does not change existing HR role
  meaning.

## ITTicket

- `id`, `requesterUid`, `departmentId`, `category`, `subject`, `description`
- `priority`, `status`, `assignedItUid`, `slaDueAt`, `resolvedAt`, `closedAt`
- `resolutionSummary`, `attachmentRefs`, `version`, timestamps
- Categories: laptop, internet, email, software, password, printer, network,
  server, access, other
- Priorities: low, medium, high, critical
- States: new -> assigned -> in_progress -> waiting_for_employee -> resolved ->
  closed. Authorized reopening creates an audit event and increments version.

## TicketPublicComment

- `id`, `ticketId`, `authorUid`, `body`, `attachmentRefs`, `createdAt`
- Visible to requester and authorized IT/management scope.

## TicketPrivateNote

- `id`, `ticketId`, `authorUid`, `body`, `createdAt`
- IT scope only. Never serialized into employee, search, export, notification,
  or diagnostic payloads.

## Asset

- `id`, `assetCode`, `name`, `type`, `brand`, `model`, `serialNumber`
- `purchaseDate`, `purchasePrice`, `warrantyExpiresAt`, `locationId`
- `status`, `currentEmployeeUid`, `version`, timestamps
- Statuses: available, assigned, maintenance, damaged, retired
- At most one active assignment. Retired assets cannot be assigned.

## AssetAssignment

- `id`, `assetId`, `employeeUid`, `assignedBy`, `assignedAt`
- `conditionAtHandover`, `returnedAt`, `returnedBy`, `returnReason`
- `conditionAtReturn`, `inspectionNotes`, `operationId`
- Immutable except completion fields for the same active assignment.

## AssetMaintenance

- `id`, `assetId`, `openedBy`, `openedAt`, `provider`, `problem`
- `cost`, `currency`, `costRequestId`, `completedAt`, `outcome`
- A non-zero cost requires a linked cost-bearing request.

## SoftwareLicense

- `id`, `name`, `vendor`, `licenseType`, `totalSeats`, `usedSeats`
- `renewalCost`, `currency`, `renewalAt`, `ownerUid`, `status`, `version`
- Seat assignment is rejected when active assignments reach capacity unless an
  authorized audited override policy exists.

## SoftwareAssignment

- `id`, `licenseId`, `employeeUid`, `assignedBy`, `assignedAt`, `revokedAt`
- Only one active assignment per employee/license pair.

## UnifiedOperationalRequest

- `id`, `requesterUid`, `requestType`, `specialistType`, `costBearing`
- `amount`, `currency`, `businessReason`, `attachmentRefs`
- `executionDate`, `status`, `approvalPolicyVersion`, `currentStageIndex`
- `paymentStatus`, `closureStatus`, `version`, timestamps
- Cost types include advance, reimbursement, custody, payment, asset purchase,
  repair/maintenance, software/license, and other expense.
- Execution/effective date is immutable for payroll/report allocation even when
  approval occurs in a later period.

## ApprovalPlan and ApprovalDecision

- Plan: `requestId`, `policyVersion`, ordered `stages`, `createdAt`
- Stage: `type`, `assigneeUid` or role/scope selector, `required`, `status`
- Decision: `id`, `requestId`, `stageIndex`, `actorUid`, `decision`, `reason`,
  `decidedAt`, `operationId`
- Cost-bearing order: manager -> relevant specialist -> finance -> owner ->
  payment/closure. Finance and owner are always required.
- The active owner policy is a versioned managed record, initially resolved
  from employee code `ceo-100`.

## FinancialLedgerEntry

- `id`, `employeeUid`, `entryType`, `sourceType`, `sourceId`
- `effectiveDate`, `amount`, `currency`, `direction`, `status`, `description`
- Read model only in this phase; it does not itself change payroll.

## KnowledgeArticle

- `id`, `title`, `category`, `content`, `visibilityScopes`
- `authorUid`, `revision`, `published`, timestamps
- Search index contains published, scope-safe fields only.

## OperationalAuditEvent

- `id`, `operationId`, `actorUid`, `actorRole`, `action`
- `targetType`, `targetId`, `safeBefore`, `safeAfter`, `createdAt`
- Append-only and role scoped. Secrets, private note text, raw tokens, and
  unrestricted attachment URLs are forbidden.

## LocalOutboxOperation

- `operationId`, `actorUid`, `operationType`, `targetId`, `payloadJson`
- `expectedVersion`, `state`, `attemptCount`, `nextAttemptAt`, `lastSafeCode`
- States: pending, syncing, synced, conflict, needs_status_check
- The same operation ID is never used for different payloads.

## OrganizationUnit

- `id`, `type`, `parentSectorId`, `name`, `normalizedName`, `order`
- `isActive`, `archivedAt`, `archivedBy`, `version`, timestamps
- Types: `sector`, `department`
- A sector has no parent. An active department has exactly one active sector
  parent. IDs are immutable; names and order are mutable.
- `normalizedName` is unique among active siblings and is used only for
  duplicate detection, never as a document identity.

## OrganizationManagerAssignment

- `id`, `unitId`, `managerUid`, `managerEmployeeIdSnapshot`
- `effectiveFrom`, `effectiveTo`, `assignedBy`, `endedBy`, `operationId`
- One current primary assignment per unit. Only an active employee may be the
  current manager. Closed assignments are immutable history.
- A unit may be temporarily vacant when policy permits; vacancy is explicit and
  future-request routing uses the approved fallback rather than a fake manager.

## OrganizationMembership

- `id`, `employeeUid`, `departmentId`, `directManagerUid`
- `effectiveFrom`, `effectiveTo`, `changedBy`, `operationId`, `version`
- One current membership per active employee. Historical closed memberships are
  immutable. The current employee department/direct-manager fields are a
  transactionally maintained compatibility projection.

## OrganizationChangeSet

- `id`, `operationId`, `actorUid`, `action`, `targetIds`, `expectedVersions`
- `requestedChanges`, `impactSummary`, `status`, `confirmedAt`, timestamps
- Actions: create, rename, reorder, move department, assign/remove manager,
  add/remove/transfer members, archive, restore.
- States: previewed, committed, conflict, rejected, needs_status_check
- A preview lists affected units/employees, routing effects, manager vacancies,
  and blocking constraints. A committed change set maps to exactly one audit
  event and one idempotent operation receipt.
