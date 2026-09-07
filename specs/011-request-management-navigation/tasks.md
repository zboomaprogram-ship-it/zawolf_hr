# Tasks

## Phase 1 — Characterization

- [ ] T001 Map request collections, statuses, and timestamp fields in `lib/screens/manager/requests_mgmt.dart` and `lib/services/pending_requests_service.dart`.
- [ ] T002 Add sorting and deep-link characterization coverage in `test/screens/manager/requests_management_navigation_test.dart`.
- [X] T003 Add approval-route and idempotent-notification contract coverage in `scripts/test/request-approval-routing.test.js`.

## Phase 2 — Navigation foundations

- [ ] T004 Create category, subcategory, and request-target contracts in `lib/features/request_management/domain/`.
- [ ] T005 [P] Create target parsing and authorization-safe request lookup in `lib/features/request_management/data/`.
- [X] T006 Update route parsing in `lib/navigation/router.dart` and route construction in `lib/models/notification_route_policy.dart`.

## Phase 3 — User Story 1: categories and pending markers

- [ ] T007 [US1] Add category-container state in `lib/features/request_management/presentation/`.
- [ ] T008 [US1] Render RTL category/subcategory containers, red actionable markers, and newest-first request lists in `lib/screens/manager/requests_mgmt.dart`.
- [X] T009 [US1] Update bounded pending counts in `lib/services/pending_requests_service.dart`.

## Phase 4 — User Story 2: exact request navigation

- [ ] T010 [US2] Carry collection, request ID, and category in manager-request notifications in `lib/services/role_notification_service.dart` and relevant request services.
- [ ] T011 [US2] Open, focus, and highlight authorized targets from `lib/screens/shared/notifications_screen.dart`, `lib/screens/manager/manager_dashboard.dart`, and `lib/screens/manager/requests_mgmt.dart`.
- [ ] T012 [US2] Add unavailable, completed, unauthorized, and offline target states in `lib/screens/manager/requests_mgmt.dart`.

## Phase 5 — User Story 3: employee مأمورية

- [ ] T013 [US3] Add employee مأمورية form entry and validation in `lib/screens/employee/employee_requests.dart`.
- [X] T014 [US3] Add the ordered manager → CEO-100 → Accounting route to `scripts/request-approval-routing.js`.
- [X] T015 [US3] Add authenticated gateway methods in `lib/features/request_approval_routing/data/request_approval_routing_gateway.dart`.
- [X] T016 [US3] Integrate three-stage mission decisions and notifications in `lib/services/administrative_request_service.dart` and `scripts/notification-web.js`.

## Phase 6 — Verification and rollout

- [X] T017 Run `flutter analyze`, architecture/query guards, relevant Flutter tests, and `(cd scripts && npm test)`.
- [ ] T018 Verify Arabic RTL, desktop web, Android, iOS, stale links, unauthorized targets, duplicate approval retries, and notification idempotency before enabling the feature.
