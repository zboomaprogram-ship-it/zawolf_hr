# Plan — طلب التعيين

1. Add a `hiring_request` vertical slice with domain request/route entities and a focused Cubit for creation, list, detail, and decision state.
2. Add a Hostinger server module that resolves `CEO-100`, IT, and Accounts approvers from active user records; validates fields; owns transactions, idempotency receipts, audit entries, and notification delivery.
3. Add authenticated API endpoints for create, scoped list/detail, and current-stage decision. Route mutation stays server-owned.
4. Add the HR RTL request form, status/history detail, and manager approval action surface. Reuse existing request navigation/deep-link conventions.
5. Add notification routing for each stage, final approval, and rejection; send final notices to HR and optional linked employee account.
6. Add unit/contract tests for route resolution, duplicate operations, unauthorized decisions, notifications, and missing/ambiguous approvers; run Flutter and Node guards.

## Rollback

Disable the new hiring-request entry point. Existing records remain readable and can be completed through the server route; no user or payroll data requires rollback.
