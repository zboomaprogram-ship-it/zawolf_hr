# Implementation Plan — Configurable Request Approval Routing

## Architecture

Introduce a new `request_approval_routing` vertical slice. Domain owns route
validation and state transitions; data owns Firestore/Hostinger gateway calls;
presentation owns the HR route-builder and history view. Legacy services remain
in place until new-route parity is demonstrated.

## Steps

1. Add domain entities and a deterministic transition service for ordered
   approval routes; characterize legacy field mission and advance behavior.
2. Add a server-authoritative request route gateway that validates actor,
   active approver, operation ID, and route transition transactionally.
3. Add Firestore indexes/rules only for the new bounded reads and gateway
   documents, with explicit rule tests and an owner-approved deploy rollback.
4. Add HR field-mission creation UI with employee picker and 1–4 ordered active
   approvers. Remove employee field-mission creation only after parity review.
5. Route advances HR → reporting-chain CEO → configured Accounts approver.
   Add an HR configuration screen for the Accounts approver directory and
   clear errors when CEO/Accounts resolution is incomplete.
6. Add shared notification events for route opened, next stage, approved, and
   rejected; attach safe deep links for employee and approver contexts.
7. Render the durable route history on employee, HR, and approver request
   detail surfaces.
8. Gate the new flow behind a feature flag; complete read-budget, transaction,
   notification idempotency, Arabic RTL, mobile, and web acceptance tests.

## Rollback

Disable the feature flag. New-route records keep their route data and are
completed through the server gateway; legacy requests continue unchanged. Do
not remove fields, rules, indexes, notifications, or assignments in rollback.
