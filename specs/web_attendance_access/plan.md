# Implementation Plan: Web Attendance Access Grants

**Date**: 2026-09-13  
**Spec**: [spec.md](spec.md)

## Summary

Add a narrow, employee-specific web check-in/check-out authorization. HR and Super Admin manage the grant through a new vertical slice; the Hostinger attendance gateway reads the deterministic current grant before accepting a web-originated attendance event. Existing attendance policy remains the source of every other decision.

## Technical Context

**Language/Version**: Dart/Flutter, Node.js CommonJS  
**Primary Dependencies**: Flutter BLoC/Cubit, Firebase Auth, Firestore, Firebase Admin SDK, existing authenticated HTTP client  
**Storage**: Firestore current-grant and audit collections  
**Testing**: Flutter unit/widget/architecture/query guard tests; Node gateway tests  
**Target Platform**: Flutter web plus existing Hostinger Node runtime; mobile behavior unchanged  
**Project Type**: Mobile/web application with authenticated integration gateway  
**Performance Goals**: One bounded grant read per web attendance attempt; no historical grant scan  
**Constraints**: Cairo dates; deterministic attendance IDs; existing attendance policy and device/location controls remain effective; no production Firestore-rule change in this increment  
**Scale/Scope**: One current authorization document and append-only audit events per managed employee

## Constitution Check

- New feature uses `lib/features/web_attendance_access/{data,domain,presentation}`.
- Presentation depends only on domain contracts and presentation-safe core helpers; Firebase and HTTP composition remain at the app edge.
- Focused Cubits split employee eligibility from HR grant management and stay below 300 lines.
- Attendance behavior receives characterization tests before gateway/UI changes.
- Gateway remains the authority for final attendance writes; no scheduler ownership changes.
- The plan is additive, keeps legacy mobile behavior intact, and avoids a Firestore-rule deployment.

**Result**: Pass, subject to characterization tests and the full required check suite before handoff.

## Design

1. Add domain value objects for grant scope, Cairo date validity, current grant, and immutable audit event; define repository contracts for employee eligibility and authorized grant management.
2. Add data adapters that call server-authorized operations and map response/error states without exposing Firebase or HTTP to presentation.
3. Add Hostinger operations to list, create/replace, and revoke grants. Use Firestore transactions for the current document and audit event, and operation IDs for retry idempotency.
4. Extend the attendance gateway’s web-origin path to load the target employee’s one current grant and reject absent, expired, revoked, or inactive-account grants before device binding and attendance mutation.
5. Add separate focused Cubits and RTL web views: employee eligibility state in attendance, plus HR/Super Admin grant management with employee selection, period/permanent toggle, validation, audit status, loading, empty, error, and offline views.
6. Wire the existing web attendance surface to the eligibility state. Ungranted users retain mobile-only guidance; granted users use the existing attendance flow and all normal local checks.
7. Add server-safe audit logging for grant authorizations and denials, including employee ID, actor ID, outcome code, scope/revision when available, and request correlation ID. Do not log precise location or tokens.
8. Keep feature rollout additive. If disabled, the web UI returns to mobile-only guidance and the gateway denies web-origin events; no attendance records, mobile paths, or grant history are deleted.

## Project Structure

```text
lib/features/web_attendance_access/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── services/
├── data/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── cubit/
    └── pages/

scripts/
├── attendance-gateway.js
└── notification-web.js

test/features/web_attendance_access/
test/services/attendance_service_test.dart
scripts/test/attendance-web-access.test.js
specs/web_attendance_access/
```

## Rollout and Rollback

Release the readers and server operations first, then expose the HR management entry and employee web eligibility. Existing mobile attendance continues unchanged throughout. Rollback disables the feature flag/server eligibility for web origin; the server then denies web attendance while preserving grants and audits for investigation. No production Firestore rules or historical attendance rows are modified.
