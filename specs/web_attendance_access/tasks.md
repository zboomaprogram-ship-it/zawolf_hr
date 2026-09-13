# Tasks: Web Attendance Access Grants

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/web-attendance-access.md`, and `quickstart.md`.

## Phase 1: Setup

- [ ] T001 Create `lib/features/web_attendance_access/{domain,data,presentation}` and `test/features/web_attendance_access/` according to `specs/web_attendance_access/plan.md`.
- [ ] T002 [P] Add Cairo-date grant validity characterization tests in `test/features/web_attendance_access/domain/web_attendance_access_grant_test.dart`.
- [ ] T003 [P] Add gateway characterization tests for existing mobile attendance idempotency and denial behavior in `scripts/test/attendance-web-access.test.js`.

## Phase 2: Foundational authorization

- [ ] T004 Create grant entities, scope/date validators, and repository contracts in `lib/features/web_attendance_access/domain/`.
- [ ] T005 [P] Add Firestore/HTTP DTO mapping and repository implementations in `lib/features/web_attendance_access/data/` without importing them from presentation.
- [ ] T006 Add authenticated Hostinger grant operations and deterministic audit/idempotency helpers in `scripts/notification-web.js` and a dedicated `scripts/web-attendance-access.js` module.
- [ ] T007 Extend route/CORS registration for the internal `/attendance/web-access/` operations in `scripts/notification-web.js`.
- [ ] T008 Extend `scripts/attendance-gateway.js` to authorize web-origin attendance from the one current grant before device binding or attendance mutation, preserving every existing policy check.
- [ ] T009 Add safe gateway logs and Arabic error mapping for missing, expired, revoked, inactive, and valid web grants in `scripts/notification-web.js` and `lib/services/attendance_gateway_service.dart`.
- [ ] T010 Add Node tests for grant transaction idempotency, Cairo inclusive dates, expiry, immediate revocation, inactive employees, and no duplicate attendance documents in `scripts/test/attendance-web-access.test.js`.

## Phase 3: User Story 1 — Grant web attendance access (P1)

**Goal**: HR/Super Admin can grant a dated or permanent exception to an active employee.

**Independent test**: Create a dated and permanent grant through the management surface and verify the server returns an effective employee eligibility receipt.

- [ ] T011 [US1] Create focused grant-management state and states in `lib/features/web_attendance_access/presentation/cubit/web_attendance_access_management_cubit.dart`.
- [ ] T012 [US1] Create RTL grant list/editor page with employee picker, period/permanent selector, date validation, loading, empty, error, and offline states in `lib/features/web_attendance_access/presentation/pages/web_attendance_access_management_page.dart`.
- [ ] T013 [US1] Compose Firebase Auth, HTTP, and the management repository at a new entry point in `lib/navigation/web_attendance_access_entry.dart`.
- [ ] T014 [US1] Add an HR/Super Admin-only navigation shortcut to the new entry point in the existing attendance/HR tool navigation file.
- [ ] T015 [US1] Add widget and Cubit tests for scope switching, date validation, and failed grant writes in `test/features/web_attendance_access/presentation/web_attendance_access_management_test.dart`.

## Phase 4: User Story 2 — Enforce web attendance (P1)

**Goal**: A granted employee can use the ordinary web attendance flow; anyone else remains mobile-only and the server always decides.

**Independent test**: Use one granted and one ungranted employee session against the same valid attendance conditions and confirm only the granted session can write a canonical attendance record.

- [ ] T016 [US2] Create employee eligibility state and Cubit in `lib/features/web_attendance_access/presentation/cubit/web_attendance_eligibility_cubit.dart`.
- [ ] T017 [US2] Add the employee eligibility repository method and contract mapping in `lib/features/web_attendance_access/data/` and `domain/`.
- [ ] T018 [US2] Extend the web attendance action payload with the contract’s web-origin marker in `lib/services/attendance_service.dart` while leaving native payloads unchanged.
- [ ] T019 [US2] Replace the unconditional web mobile-only card in `lib/screens/employee/employee_dashboard.dart` with the eligibility-driven RTL state, preserving mobile-only guidance for ungranted users.
- [ ] T020 [US2] Ensure denied web actions are not stored in pending offline sync in `lib/services/attendance_service.dart` and show the server’s Arabic eligibility error.
- [ ] T021 [US2] Add Flutter tests covering web-granted, web-ungranted, revoked-after-load, leave/day-off, invalid location, and repeated-tap states in `test/services/attendance_service_test.dart` and `test/features/web_attendance_access/presentation/web_attendance_eligibility_test.dart`.

## Phase 5: User Story 3 — Review and revoke grants (P2)

**Goal**: Authorized administrators can identify and immediately revoke an existing exception with a durable audit history.

**Independent test**: Revoke a permanent grant from the management page, verify the audit entry, and confirm the employee’s next open-browser request is denied.

- [ ] T022 [US3] Add current-grant status, revision, and audit-event models to `lib/features/web_attendance_access/domain/entities/`.
- [ ] T023 [US3] Add grant status, audit timeline, and revoke confirmation to `lib/features/web_attendance_access/presentation/pages/web_attendance_access_management_page.dart`.
- [ ] T024 [US3] Add revoke operation idempotency and audit assertions to `scripts/test/attendance-web-access.test.js`.
- [ ] T025 [US3] Add RTL widget tests for active, expired, revoked, permanent, and unauthorized management states in `test/features/web_attendance_access/presentation/web_attendance_access_management_test.dart`.

## Phase 6: Cross-cutting validation

- [ ] T026 Add architecture and bounded-query coverage for the new feature in `test/architecture_guard_test.dart` and `test/firestore_query_guard_test.dart`.
- [ ] T027 Run the scenarios in `specs/web_attendance_access/quickstart.md`, including web/mobile parity and Cairo date boundaries.
- [ ] T028 Run `flutter analyze`, architecture/query guards, the full Flutter suite, and `(cd scripts && npm test)`; fix only failures attributable to this feature.

## Dependencies

`T001–T010` block all user stories. US1 delivers management. US2 depends on the gateway foundation and can follow US1. US3 depends on management state and server grant operations. Cross-cutting validation follows all stories.
