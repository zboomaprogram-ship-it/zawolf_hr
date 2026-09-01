# Request Approval Routing

## Purpose

Provide deterministic, auditable approval routes for field missions and
employee advances in both the mobile app and web dashboard.

## Live behaviour

- HR creates a field mission with one to four selected approvers. Only active
  managers and authorised accounts users can be selected. The employee is
  notified when the mission enters review and again when it is approved,
  rejected, or returned.
- An advance follows the fixed route: HR, the employee's assigned authorised
  CEO approver, then an authorised accounts approver.
- Every route transition is idempotent, has a history record, and notifies the
  requester and the user whose approval turn is next.
- Historical and legacy requests remain viewable through the existing request
  screens.

## Source documents

The implementation plan and task checklist are retained in the original
working directory [`specs/request-approval-routing`](../request-approval-routing/)
for compatibility with the release hand-off. This directory is the canonical
feature-aligned specification location required by the application structure.
