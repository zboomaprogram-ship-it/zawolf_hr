# Owner rollout handoff — Specs 001–009

This file records the remaining work after the implemented code changes. It is
an owner-run release checklist, not evidence that any live change has been
made. Phase 008 (multi-organization trees) is intentionally deferred.

## Safety boundary

- Do not publish Firestore rules, enable a pilot, rotate a secret, migrate
  data, or deploy a web/mobile build until the relevant owner approval is
  recorded.
- Retain the legacy route and the prior feature-flag value for every pilot.
- Run each pilot with non-production accounts, locations, devices, and
  request fixtures first.

## Remaining owner actions

| Scope | Required owner action | Evidence to record |
|---|---|---|
| 002 attendance reliability | Execute T042 non-production matrix with pilot disabled by default. | Result by scenario and separate pilot approval. |
| 003 check-out retirement | Execute T056 non-production acceptance. | Exceptions and outcome in its quickstart. |
| 004 attendance/request stability | Execute T039 and complete T040 release review. | Manual matrix, read-budget/error review, deployment instructions. |
| 005 Company OS | Execute T082/T114 matrix, then T083/T115 limited pilot. | Authorization, idempotency, privacy, rollback, and metrics. |
| 005 Company OS | Approve T084/T116 flag switch separately only after the pilot. | Approved flag values and rollback verification. |
| 006 Workspace | Execute T085 acceptance and T091 limited pilot. | Google account, Drive/Sheets audit, report, access and rollback evidence. |
| 006 Workspace | Approve T092 default-route switch separately. | Owner approval and retained legacy route. |
| 007 employee operations | Execute T064 pilot and rotate the former shared sales key in Hostinger secret storage. | Per-slice parity/rollback and secret rotation confirmation. |
| 009 multi-location attendance | Execute T031/T032/T042 non-production matrix and pilot. | Location, device, offline, exit/re-entry, break and duplicate-rate evidence. |
| 009 multi-location attendance | Approve T035 then run T036 deployment/monitoring. | Explicit approval, deployment ID, status-check and rollback metrics. |

## CEO-100 approval check

Before a release, create one request for an employee whose current `managerId`
is the UID of `CEO-100` and confirm that the CEO sees and receives the manager
stage for leave, permission, advance, administrative request, and resignation.

The current local application supports that routing. If `CEO-100` retains an
HR role, an advance manager-stage decision additionally requires an
owner-approved Firestore rule release. Keep the previous rules artifact for
immediate rollback; record one approved and one rejected advance decision.
