# Implementation Plan — Request Management Navigation and Employee Mission Approval

1. Characterize the request collections, current tabs, pending counters, routes, and notification payloads. Add contract tests for timestamp sorting, category selection, target authorization, and route recovery.
2. Introduce a request-management navigation model and focused presentation state beside the legacy management screen. Map each existing request source to a category/subcategory and maintain bounded, reusable queries.
3. Extend notification payload construction and router parsing with optional request targets. Resolve targets only after the screen verifies reviewer authority; focus and highlight the exact row.
4. Add employee مأمورية submission as a server-owned three-stage route. Resolve manager, CEO-100, and Accounting at creation; persist route stages and idempotent notifications atomically.
5. Preserve legacy field-mission routes, validate desktop/mobile RTL behavior, query budgets, duplicate decisions, stale notifications, and complete Flutter/Node checks before feature enablement.

## Deployment order

Deploy additive Hostinger route and notification contract support first. Release clients that understand target links and mission stages next. Enable the new navigation after target-routing and authorization regression tests pass.
