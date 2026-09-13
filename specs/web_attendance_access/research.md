# Research: Web Attendance Access Grants

## Decision: enforce grants in the existing attendance gateway

**Rationale**: `scripts/attendance-gateway.js` performs the final Admin SDK write for attendance. Checking the grant immediately before that write makes grant expiry and revocation authoritative even if an old browser screen is open or the UI is modified.

**Alternatives considered**:
- Client-only visibility flag: rejected because a browser client can be changed or stale.
- Firestore security-rule-only write path: rejected because attendance already uses the authenticated server gateway and server-side policy is the existing authority.

## Decision: preserve the mobile-first default

**Rationale**: The existing web screen explicitly explains that attendance is mobile-only. A valid individual grant changes that one eligibility decision; employees without it retain the same screen and behavior.

**Alternatives considered**:
- Enable web attendance for whole roles or departments: rejected because the request is for named employees and would broaden the exception unnecessarily.

## Decision: one current grant document per employee plus append-only audit events

**Rationale**: A deterministic document permits one bounded read during attendance authorization. An independent audit collection preserves the administrative history when a grant is changed or revoked.

**Alternatives considered**:
- Query all historical grants at check-in: rejected because it grows with history and makes authorization read cost unbounded.

## Decision: Cairo civil dates and inclusive period bounds

**Rationale**: Attendance and leave policies already use `Africa/Cairo` as their business-day authority. A grant valid from 2026-09-13 through 2026-09-15 works on all three Cairo dates.

**Alternatives considered**:
- UTC instant timestamps alone: rejected because they create ambiguous dates around midnight and daylight-saving transitions.

## Decision: no offline replay for denied web actions

**Rationale**: A grant may be revoked between a browser action and a retry. A denied browser action must require a fresh authorization rather than later replay.

**Alternatives considered**:
- Queue the denied action for automatic retry: rejected because it can apply an action after the grant has expired or been revoked.
