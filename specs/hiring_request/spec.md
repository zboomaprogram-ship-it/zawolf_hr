# طلب التعيين — Hiring Request

## Goal

Allow HR to submit a hiring request before creating or activating a new employee. The request records the proposed employee name, job title, direct manager, monthly salary, currency, and assignment date. It follows a fixed, server-authoritative approval route:

1. CEO account with employee code `CEO-100`;
2. the active IT manager;
3. the active Accounts/Accounting manager.

Only after the third approval is the request final. The HR requester receives the final decision notification. If the proposed employee already has a system account, that account receives the final approved/rejected notification as well.

## Scope

- HR and super-admin may create and view hiring requests.
- Required fields: employee name, job title, direct manager, salary, currency, assignment date.
- Optional existing employee account: selected only from active accounts. This does **not** create an account.
- The fixed route is resolved on the server. A browser must never provide, reorder, or skip approvers.
- Each stage may approve or reject, with an optional decision comment.
- A rejection ends the route and notifies HR and the linked account, when present.
- The final approval records final approval metadata and notifies HR and the linked account. It does not automatically create a Firebase account or change payroll.
- HR, the current approver, and the linked employee may read the request history within their existing authorization scope.

## Route resolution

- CEO: exactly one active `users` document whose `employeeId` or `employeeCode` is `CEO-100`.
- IT: exactly one active manager in the IT department, resolved from explicit `isHiringItApprover: true` first; otherwise the single active manager-role IT account.
- Accounts: exactly one active accounting manager, resolved from explicit `isHiringAccountsApprover: true` first; otherwise the single active manager-role account in Accounting/Accounts.
- A missing or ambiguous required approver rejects submission with a clear Arabic configuration error. The system never selects an arbitrary approver or silently skips a stage.

## Data contract

New documents are stored in `hiringRequests/{requestId}`. They contain:

- `requestType: hiring_request`, `status`, requester identity, submitted timestamp;
- proposed employee details (`proposedEmployeeName`, `jobTitle`, `managerId`, `managerName`, `baseMonthlySalary`, `salaryCurrency`, `assignmentDate`, optional `existingEmployeeUid`);
- `approvalRoute`, `currentApprovalIndex`, `currentApproverId`, and append-only `approvalHistory`;
- final/rejection metadata and deterministic operation receipts in `hiringRequestOperations`.

## Safety and acceptance criteria

- Repeated taps/retries with the same operation ID must not create duplicate requests, decisions, audit records, or notifications.
- Only the current route approver can decide the request.
- Notifications are durable Firestore notification items with safe deep links to the exact request.
- Arabic RTL, web, mobile, loading, empty, configuration-error, and retry states are supported.
- Existing employee-account creation remains unchanged and separate.
- No Firestore rule change, account provisioning, salary change, or payroll mutation is included.
