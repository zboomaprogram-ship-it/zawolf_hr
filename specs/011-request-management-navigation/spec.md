# Request Management Navigation and Employee Mission Approval

**Status:** Proposed for owner review  
**Created:** 2026-09-07

## User scenarios

### P1 — Find and action a new request

A manager opens Request Management and sees request categories as clear containers, each with subcategories and a red indicator when it contains a request that currently needs that manager's action. Requests within every list appear newest first by their submitted date.

### P2 — Open the exact request from a notification or dashboard

A manager taps a request notification, notification-center item, or pending-request dashboard card and lands in the correct category with the referenced request visible and highlighted. A missing, completed, or no-longer-authorized request shows an explanatory state without opening an unrelated first tab.

### P3 — Submit and approve an employee مأمورية

An employee submits a مأمورية request with date, time, place, and reason. The request proceeds in order to the employee's assigned manager, CEO-100, then Accounting. Each current approver receives one notification that opens the exact request. Approval or rejection is recorded once, and the employee receives the final decision.

## Functional requirements

- FR-001: Request Management shall organize every supported request type into named categories and subcategories using selectable containers that work in Arabic RTL, mobile, web, and desktop layouts.
- FR-002: Each container shall display the number of requests awaiting the current reviewer; a red dot shall appear at its top-right when that number is greater than zero.
- FR-003: Lists shall order records by their authoritative submission timestamp from newest to oldest. Missing timestamps shall sort after timestamped records using a stable request-ID tie break.
- FR-004: Every request notification and pending-dashboard link shall carry a request collection/type, request identifier, and category target when available.
- FR-005: Request Management shall select the supplied category and scroll the supplied authorized request into view. It shall highlight the request until the user takes an action or leaves the screen.
- FR-006: A deep link shall never expose a request outside the recipient's approval authority.
- FR-007: Employee مأمورية submission shall require an active employee, an assigned active manager, valid date/time interval, place, and reason.
- FR-008: Employee مأمورية approval order shall be assigned manager → CEO-100 → active Accounting approver. The server shall reject skipped, duplicate, stale, or unauthorized decisions.
- FR-009: Each stage transition shall atomically update the current approver, history, request state, and idempotent notification record. The final approved مأمورية shall create its attendance/field-assignment effect only once.
- FR-010: Existing HR-created field missions and historical administrative requests shall remain readable and actionable according to their existing routes.
- FR-011: The manager, CEO-100, Accounting approver, employee, and HR inspection views shall receive a clear pending, approved, rejected, unavailable, and offline state.

## Key entities

- **Request navigation target:** Authorized collection/type, request ID, category, and subcategory.
- **Request category:** A display grouping with an actionable pending count for the current reviewer.
- **Employee mission route:** Ordered reviewer stages, current stage, transition history, and deterministic notification keys.

## Assumptions

- “Accountant” means an active user in the existing Accounting approval role or department, resolved by the server; the selected reviewer is stored on the mission route.
- CEO-100 identifies the existing canonical CEO account, with the current super-admin alias behavior preserved.
- A red dot indicates a request awaiting the signed-in reviewer, not merely an unread historical record.
- Existing notification routes remain compatible while optional request-target query parameters are added.

## Success criteria

- A reviewer can reach an actionable request from a notification or pending dashboard card in one tap, with the correct request visible in under three seconds under normal connectivity.
- All lists with comparable request timestamps show newest requests before older requests.
- Every actionable category gives a visible pending indicator; categories with no actionable requests have none.
- A valid employee مأمورية reaches exactly three ordered approval stages and produces no duplicate final assignment or stage notification after retries.

## Boundaries

- This work does not change leave, permission, advance, payroll, attendance deduction, or existing HR-created field-mission approval rules except where required to render their category or deep link.
- This work does not grant a reviewer access beyond the existing authorization model.
