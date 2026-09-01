# Tasks — Configurable Request Approval Routing

- [ ] Characterize field-mission and advance approval state transitions,
  assignment creation, and notification deduplication.
- [ ] Create route domain entity, validation, transition service, and unit tests.
- [x] Define CEO resolution from organisational reporting data and the Accounts
  approver configuration contract; reject missing configuration safely.
- [x] Implement a transaction-based Hostinger request-routing gateway with
  stable operation IDs and audit records.
- [ ] Add bounded repository/client adapters and architecture guard coverage.
- [x] Add HR field-mission route builder with active employee/approver picker,
  ordered stages, route validation, and Arabic error/loading states.
- [x] Add advance HR → assigned CEO → Accounts route creation and approval UI.
- [x] Add route history component to employee, manager, and HR request details.
- [x] Add idempotent requester/current-approver notification events and deep
  links for every transition.
- [ ] Add Firestore rules/indexes only after owner approval and rollback plan;
  add rule/query tests before deployment.
- [ ] Release behind feature flag; verify legacy-request parity, mobile, web,
  RTL, offline/retry, and dispatcher behavior before enabling globally.
