# Configurable Request Approval Routing

**Status:** Approved for staged implementation — not yet deployed

## Goal

Make request approval routing explicit, sequential, auditable, and notification
driven without changing the meaning of existing approved/rejected requests.

## User stories

### Field mission created by HR

An HR user creates a field mission for a selected employee, chooses one to four
named approvers from the active employee directory, and places them in order.
The mission starts as `pending_approval`; the employee is notified that it is
under review; only the current approver may approve or reject; each approved
stage notifies the next approver; final approval creates the existing active
field assignment and notifies the employee. Rejection notifies the employee
with the reviewer comment. HR and authorised reviewers can view the immutable
approval history.

### Advance route

An employee-submitted advance follows exactly: **HR → employee's assigned CEO
→ Accounts**. HR is the first stage. The assigned CEO is resolved from the
employee's organisational reporting chain, not hard-coded to `CEO-100`.
Accounts is resolved from a configured active Accounts approver directory. If a
required route member cannot be resolved, submission is rejected with a clear
Arabic configuration message; it must never silently skip a financial control.

The explicit directory is maintained on active user documents:

- `isAdvanceCeoApprover: true` for a CEO who is not already stored with the
  `manager` role.
- `isAdvanceAccountsApprover: true` for each authorised Accounts approver.

The system never infers financial authority from a translated department title.

### Notifications for every route

For every sequential request route, the service queues an idempotent notification
to the person whose turn begins. The requester receives submission, final
approval, and rejection notifications. Notification delivery failure never
rolls back the request state; the durable notification item is the source of
truth and is retried by the existing dispatcher.

## Data contract

New requests use an additive `approvalRoute` array, with one entry per stage:

```json
{
  "stageId": "field_mission:<requestId>:1",
  "order": 1,
  "approverId": "firebase-user-id",
  "approverName": "Display name",
  "approverRole": "manager",
  "labelAr": "مدير المشروع",
  "state": "pending|approved|rejected|skipped",
  "actedAt": null,
  "comment": null
}
```

The request also stores `approvalRouteVersion: 1`, `currentApprovalIndex`,
`currentApproverId`, `currentApproverName`, `approvalHistory`, and terminal
fields. Existing legacy manager/CEO/HR fields remain readable during the
migration and are not rewritten.

## Authorization and safety

- Only HR/super-admin can create a HR-originated field-mission route.
- A route contains 1–4 distinct active approvers; the requester cannot be an
  approver unless HR deliberately selects that account and the server accepts
  it under policy.
- Only `currentApproverId` can approve/reject the current stage.
- HR/super-admin can view and manage routes; they may not bypass a stage unless
  a recorded route-amendment action is introduced later.
- Every mutation uses a transaction and a client-supplied operation ID to make
  repeat taps/retries idempotent.
- Route history is append-only. Cancellation and route correction preserve the
  earlier decision history.
- No production Firestore rule is deployed until rule tests, a staged release,
  and an owner-approved rollback plan exist.

## Migration and rollback

1. Add new route fields and server-side gateway beside legacy routes.
2. Release readers that understand both formats; legacy requests keep their
   current service path and status semantics.
3. Enable the new route only for newly HR-created field missions and new
   advances after approval.
4. Roll back by disabling the route feature flag; requests already started on
   the new route remain readable and can be completed by the gateway, while no
   new routed requests are created.

## Out of scope

- Rewriting historical requests.
- Changing payroll deduction or field-assignment rules.
- Silent CEO/accounting fallbacks.
- Broadcasting notifications to approvers who are not currently responsible.
