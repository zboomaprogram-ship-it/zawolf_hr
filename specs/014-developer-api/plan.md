# Implementation Plan: External Developer API

**Date**: 2026-09-10 | **Spec**: [spec.md](spec.md)

## Summary

Add a small, read-only, versioned integration API beside the Hostinger runtime. It will authenticate a revocable integration credential at the server, enforce scopes before every query, redact data through explicit serializers, and provide the employee directory first. Firebase remains an internal persistence implementation.

## Technical design

### Credential model

Store `developerApiClients/{clientId}` with `name`, `ownerUid`, `status`, `scopeSet`, `expiresAt`, `secretHash`, `secretSalt`, `allowedOrigins`, timestamps, and last-use metadata. Generate a cryptographically random one-time secret. Authenticate `Authorization: Bearer zwh_<clientId>_<secret>` using constant-time hash comparison. The public client ID is not authorization.

Credential creation and revocation are HR/super-admin server routes that reuse the canonical authorization helper. The issuance response is never persisted or shown again.

### HTTP surface

```text
GET /developer-api/v1/users?limit=50&department=<opaque-or-normalized-filter>&cursor=<opaque>
GET /developer-api/v1/users/:userId
GET /developer-api/v1/openapi.json
```

Every response has `{ok, requestId, data, nextCursor?}`. Error status is `401` for credential failure, `403` for a scope failure, `400` for malformed input, `429` for rate limits, and `500` only for unexpected server failure. All endpoints are read-only.

### Data safety

A `userSerializer` maps only allowlisted fields. It must not spread Firestore documents. IDs for references use opaque stable IDs. Page queries have a fixed sort and `limit <= 100`; unsupported filters are rejected. The initial `directory.read` scope is required on both endpoints. Every future data family has its own serializer, scope, route, tests, and read-budget estimate.

### Operations

Add a bounded in-memory rate limiter as a first increment and a Firestore-backed audit record with hashed IP/network classification as appropriate. Health telemetry counts outcomes by client and route without secrets or personal data. Rollout is disabled until a client is explicitly created.

## Architecture check

- **Strangler Fig**: additive Hostinger route family; existing Firebase clients are unchanged.
- **Authority**: server uses Firebase Admin; the external developer never directly connects to Firebase.
- **Security**: least privilege, per-client scope, expiry/revocation, field allowlists, no data export-by-default.
- **Data/query limits**: 100 users/page, deterministic cursor, no unbounded scans.
- **Rules/migrations**: additive documents only; no Firestore rule change or destructive migration.

## Delivery increments

1. Credential issuance/revocation, authentication middleware, audit/redaction utilities, and tests.
2. Directory endpoints, OpenAPI document, pagination/rate-limit tests, and a manual client smoke test.
3. Separately reviewed optional datasets, one scope and contract at a time.

## Rollout and rollback

Deploy routes without credentials first. Create one short-lived directory-only client for the named developer. Monitor request outcomes and read counts. Revoke the client to stop access immediately; routes may remain deployed because no credential can use them.
