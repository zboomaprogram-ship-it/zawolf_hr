# Feature Specification: External Developer API

**Feature Branch**: `014-developer-api`  
**Created**: 2026-09-10  
**Status**: Draft — owner review required before implementation  
**Feature Boundary**: `scripts/developer-api/`, `specs/014-developer-api/`

## Purpose

Provide another developer with a documented, revocable HTTPS API to retrieve approved ZaWolf HR data. The API is server-owned: it never gives the developer Firebase credentials, Firebase ID tokens, Firestore access, passwords, device identifiers, or service-account material.

## User stories

### US1 — Issue a controlled integration credential (P1)

An HR/super-admin owner creates a named integration client with an expiry and selected scopes. The secret is displayed once; the server stores only a salted hash. The owner can revoke it immediately.

**Acceptance scenarios**

1. A newly issued secret can call only its selected scopes until its expiry.
2. A revoked, expired, malformed, or guessed secret receives the same safe `401` response.
3. The server writes an audit event for creation, use, scope denial, and revocation without storing the secret.

### US2 — Read a bounded employee directory (P1)

An authorized integration can list and retrieve active employee directory records with stable opaque IDs, cursor pagination, filters, and a documented field allowlist.

**Acceptance scenarios**

1. `GET /developer-api/v1/users` returns at most 100 records and a signed/opaque continuation cursor.
2. `GET /developer-api/v1/users/{id}` returns only the field allowlist for an authorized active or explicitly requested inactive record.
3. Salary, password/authentication fields, FCM/OneSignal tokens, biometric/device data, raw attendance location, private chat content, and internal Firebase metadata never appear.
4. Filter and cursor parameters are validated and do not produce unbounded Firestore scans.

### US3 — Add approved operational datasets safely (P2)

The owner can grant separate read-only scopes for approved datasets, such as departments, attendance summaries, requests, or payroll summaries. Each dataset has its own endpoint contract, field allowlist, pagination, retention policy, and audit classification.

**Acceptance scenarios**

1. A directory-only client cannot read any attendance, request, payroll, or chat data.
2. Every new dataset is denied by default until its dedicated scope and contract are deployed.
3. Scope denials do not disclose whether a target record exists.

## Functional requirements

- **FR-001**: All endpoints MUST be served by the authenticated Hostinger Node runtime under `/developer-api/v1/`; Firebase Admin remains server-only.
- **FR-002**: Each integration MUST use a unique secret with a public client ID, expiry, status, scopes, and owner label; only a slow salted hash of the secret may be stored.
- **FR-003**: Every request MUST be TLS-only, rate-limited per client and IP, bounded in body size, and audited with a request ID, client ID, route, outcome, and response count.
- **FR-004**: The first release MUST be read-only and expose only the approved employee-directory allowlist: opaque user ID, employee ID, display name, department, position, manager opaque ID, active state, and public work contact fields if explicitly enabled.
- **FR-005**: Endpoints MUST use bounded cursor pagination, maximum page size 100, validated filters, deterministic ordering, and a defined continuation response.
- **FR-006**: API responses MUST use a versioned JSON envelope with `requestId`, `data`, optional `nextCursor`, and documented machine-readable errors.
- **FR-007**: The API MUST reject browser cross-origin credential use by default. If a later browser client is approved, CORS origins must be an explicit integration setting.
- **FR-008**: Secrets, authorization headers, full request bodies, Firebase claims, and sensitive source fields MUST never be emitted in logs, audits, errors, or API responses.
- **FR-009**: Credential issuance/revocation MUST use the existing canonical HR/super-admin authorization helper and require an audit reason.
- **FR-010**: No Firestore rules change, direct Firebase client access, or destructive data migration is permitted.

## Non-goals

- Write/mutation endpoints.
- Giving a third party Firebase project credentials or Admin SDK access.
- Exporting private chat messages, payroll, raw location, biometric/device records, passwords, or notification tokens.
- An unrestricted “all Firebase data” endpoint.

## Success criteria

- A revoked credential is denied on its next request.
- Directory list queries stay within their documented read budget and return under two seconds for a page of 100 records at representative scale.
- Automated tests cover authentication, expiry, revocation, every scope boundary, redaction, pagination, rate limiting, audit redaction, and malformed inputs.

## Open owner decisions

1. Which additional datasets, if any, should this developer receive after the employee directory: attendance summaries, requests, departments, payroll summaries, or something else?
2. Which public work-contact fields are allowed: work email, work phone, both, or neither?
3. Who is the named owner of each integration credential and how long should it remain valid?
