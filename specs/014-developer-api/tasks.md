# Tasks: External Developer API

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1 — Foundation

- [x] T001 Add server-only route and authorization-boundary expectations to Node tests.
- [x] T002 Create `scripts/developer-api/` modules for credential parsing, constant-time authentication, scope checks, safe errors, and audit redaction.
- [x] T003 Add HR/super-admin-only credential create/list/revoke routes with one-time secret issuance and auditable reasons.
- [x] T004 Add expiry, revocation, malformed secret, scope-denial, and log-redaction tests.
- [x] T005 Add per-client/IP bounded rate limiting and `429` tests.

## Phase 2 — Employee directory

- [x] T006 Define explicit `directory.read` user serializer and field-level redaction tests.
- [x] T007 Implement bounded directory list query with stable sort, `limit <= 100`, validated filters, and opaque cursor.
- [x] T008 Implement single-directory-record endpoint with the same scope and serializer.
- [x] T009 Publish generated/static OpenAPI 3.1 contract and integration examples that use environment variables for the secret.
- [x] T010 Add query-budget, pagination, authorization, and audit tests.

## Phase 3 — Release

- [x] T011 Run `flutter analyze`, Flutter guards/suite where changed, and `(cd scripts && npm test)`.
- [ ] T012 Deploy additive Hostinger support, create a short-lived directory-only integration, and record health/rollback evidence.
- [ ] T013 Add optional datasets only after a separate owner-approved contract for each data family.
