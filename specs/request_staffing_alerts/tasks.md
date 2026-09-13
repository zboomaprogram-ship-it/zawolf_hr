# Tasks: Same-Title Absence and Permission Alert

**Input**: `spec.md` and `plan.md`.

## Phase 1: Foundation

- [ ] T001 Add job-title normalization and Cairo overlap characterization tests in `test/services/request_staffing_conflict_policy_test.dart`.
- [ ] T002 Create the domain conflict policy and DTO contract in `lib/features/request_staffing_alerts/domain/` and `lib/features/request_staffing_alerts/data/`.
- [ ] T003 Add a bounded, manager-authorized conflict resolver and deterministic notification key helper in `scripts/request-staffing-alerts.js`.
- [ ] T004 Add Node tests for same-title overlap, different title, different manager, blank title, multiple dates, and duplicate notification suppression in `scripts/test/request-staffing-alerts.test.js`.

## Phase 2: User Story 1 — Manager staffing warning (P1)

**Goal**: A manager sees the relevant same-title absence or permission conflict before approving.

**Independent test**: Two same-title employees with the same manager submit overlapping leave or permission requests; the manager sees an advisory warning and may still complete the standard approval.

- [ ] T005 [US1] Add an authenticated internal conflict-preview route and CORS registration in `scripts/notification-web.js`.
- [ ] T006 [US1] Add a focused conflict-preview Cubit in `lib/features/request_staffing_alerts/presentation/cubit/request_staffing_conflict_cubit.dart`.
- [ ] T007 [US1] Add an RTL advisory confirmation panel with employee, request type, job title, and Cairo date details in `lib/features/request_staffing_alerts/presentation/widgets/request_staffing_conflict_panel.dart`.
- [ ] T008 [US1] Integrate the panel before leave approval in `lib/screens/manager/requests_mgmt.dart` and `lib/services/leave_service.dart` without changing the approved update path.
- [ ] T009 [US1] Integrate the panel before permission approval in `lib/screens/manager/requests_mgmt.dart` and `lib/services/permission_service.dart` without changing the approved update path.
- [ ] T010 [US1] Queue the manager notification at the request’s manager-review stage with the deterministic alert key in `lib/services/leave_service.dart`, `lib/services/permission_service.dart`, and `scripts/request-staffing-alerts.js`.
- [ ] T011 [US1] Add widget/service tests for warning display, manager scope, continued approval, and no warning for unrelated staff in `test/features/request_staffing_alerts/`.

## Phase 3: Cross-cutting validation

- [ ] T012 Add architecture/query guard coverage for `lib/features/request_staffing_alerts/` in `test/architecture_guard_test.dart` and `test/firestore_query_guard_test.dart`.
- [ ] T013 Run Flutter analysis, targeted Flutter tests, `scripts/test/request-staffing-alerts.test.js`, full Node tests, and RTL mobile/web verification.

## Dependencies

T001–T004 establish the policy and bounded server result. T005–T011 deliver the advisory manager flow. T012–T013 validate the complete change.
