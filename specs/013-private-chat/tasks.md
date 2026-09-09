# Tasks: Governed Private Chat

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/private-chat.md](contracts/private-chat.md)

## Phase 1: Setup

- [ ] T001 Add direct-chat acceptance fixtures and policy cases to `scripts/test/rich-conversations.test.js`.
- [ ] T002 Add private-chat domain and presentation boundary expectations to `test/architecture_guard_test.dart`.

## Phase 2: Foundational authorization and data contracts

- [ ] T003 Implement pure active-user, IT, department, manager-chain, and role eligibility evaluation in `scripts/conversations/direct-policy.js`.
- [ ] T004 Add server tests for all employee, manager, super-admin, HR, and IT eligibility combinations in `scripts/test/rich-conversations.test.js`.
- [ ] T005 Extend `scripts/conversations/common.js` so `kind: direct` requires exactly the participant pair for reads, posts, actions, and protected downloads.
- [ ] T006 Add direct conversation DTO fields to `lib/features/conversations/domain/entities/rich_chat.dart`.
- [ ] T007 [P] Extend mapping and local persistence for direct kind, activity fields, and participant display data in `lib/features/conversations/data/chat_codec.dart` and `lib/features/conversations/data/local/chat_database.dart`.
- [ ] T008 Add repository contracts for departments, eligible contacts, and deterministic direct creation in `lib/features/conversations/domain/repositories/rich_chat_repository.dart`.

**Checkpoint**: Authorization is authoritative and direct-channel contracts exist before any user-facing picker is enabled.

## Phase 3: User Story 1 — Start an authorized private chat (Priority: P1)

**Goal**: An authorized actor chooses a department and an eligible person, then reaches exactly one direct chat.

**Independent Test**: Run direct-policy and direct-creation tests for ordinary employee, manager, super admin, HR, IT, inactive target, forged target, and simultaneous create.

- [ ] T009 [P] [US1] Implement deterministic pair identity, transactional direct creation, and operation replay in `scripts/conversations/direct.js`.
- [ ] T010 [US1] Route `POST /conversations/v2/direct` through `scripts/conversations/router.js` with safe error envelopes.
- [ ] T011 [P] [US1] Implement bounded active department and eligible-contact queries in `scripts/conversations/queries.js`.
- [ ] T012 [US1] Route department and eligible-contact endpoints in `scripts/conversations/router.js`.
- [ ] T013 [P] [US1] Implement authenticated transport methods in `lib/features/conversations/data/rich_chat_repository_impl.dart`.
- [ ] T014 [US1] Add a focused department-first picker Cubit in `lib/features/conversations/presentation/cubit/chat_direct_picker_cubit.dart`.
- [ ] T015 [US1] Build the Arabic RTL department and contact picker in `lib/features/conversations/presentation/pages/direct_chat_picker_page.dart`.
- [ ] T016 [US1] Add the private-chat entry action to `lib/features/conversations/presentation/pages/rich_chat_inbox_page.dart`.
- [ ] T017 [US1] Add Flutter regression tests for picker state, stale target denial, and direct-channel opening in `test/features/conversations/private_chat_picker_test.dart`.

## Phase 4: User Story 2 — Separate private chats and groups (Priority: P1)

**Goal**: Users can switch between private chats and groups without mixing their entries.

**Independent Test**: Create direct, department, manager, and custom conversations; refresh on web and mobile and verify each appears in exactly one section.

- [ ] T018 [P] [US2] Add section-aware bounded inbox query behavior to `scripts/conversations/queries.js`.
- [ ] T019 [US2] Preserve unqualified legacy channel responses while routing `section=direct|group` in `scripts/conversations/router.js`.
- [ ] T020 [P] [US2] Add section-aware page retrieval and local-cache mapping in `lib/features/conversations/data/rich_chat_repository_impl.dart` and `lib/features/conversations/data/local/chat_store.dart`.
- [ ] T021 [US2] Split focused inbox state by section without exceeding 300 lines in `lib/features/conversations/presentation/cubit/chat_inbox_cubit.dart`.
- [ ] T022 [US2] Render Arabic RTL Private chats and Groups sections, empty states, unread badges, and offline feedback in `lib/features/conversations/presentation/pages/rich_chat_inbox_page.dart`.
- [ ] T023 [US2] Add widget tests for section separation and empty/offline states in `test/features/conversations/private_chat_inbox_test.dart`.

## Phase 5: User Story 3 — Recent conversations appear first (Priority: P1)

**Goal**: Each inbox section stays ordered newest to oldest after messages, refreshes, and pagination.

**Independent Test**: Send controlled messages across pages, simulate equal timestamps and live updates, then verify stable newest-first order without duplicates.

- [ ] T024 [P] [US3] Update direct and group activity atomically for message, edit, deletion, reaction, and attachment events in `scripts/conversations/messages.js`.
- [ ] T025 [US3] Implement stable activity cursor pagination and direct/group order in `scripts/conversations/queries.js`.
- [ ] T026 [P] [US3] Add server tests for activity ordering, equal-time tie-breaking, pagination, and duplicate direct creation in `scripts/test/rich-conversations.test.js`.
- [ ] T027 [US3] Merge live and paged inbox updates by channel ID and activity order in `lib/features/conversations/presentation/cubit/chat_inbox_cubit.dart`.
- [ ] T028 [US3] Add Flutter tests for newest-first ordering and live movement in `test/features/conversations/private_chat_inbox_test.dart`.

## Phase 6: Polish and verification

- [ ] T029 Verify every private message, action, attachment upload, and download rechecks direct participant authorization in `scripts/conversations/common.js`, `scripts/conversations/messages.js`, and `scripts/conversations/uploads.js`.
- [ ] T030 [P] Verify RTL, mobile, desktop web, loading, error, offline, and empty states using `specs/013-private-chat/quickstart.md`.
- [ ] T031 [P] Run `flutter analyze`, architecture/query guards, full Flutter tests, and `(cd scripts && npm test)`.
- [ ] T032 Deploy additive Hostinger support before enabling the existing `conversations_rich_chat_v1` rollout and document monitoring/rollback evidence in `specs/013-private-chat/quickstart.md`.

## Dependencies and execution order

- Phase 2 blocks all user stories.
- User Story 1 is the MVP and must complete before the inbox can display direct chats.
- User Story 2 depends on the direct contract from User Story 1.
- User Story 3 depends on section-aware inbox records from User Story 2.
- Polish follows all selected stories.

## Parallel opportunities

- T004 and T007 can proceed after T003/T006 respectively.
- T009 and T011 can proceed after T003.
- T013 can proceed after T008; T014 can proceed after T008.
- T018 and T020 can proceed after the foundational contract.
- T024 and T026 can proceed once direct conversations exist.

## MVP scope

Complete T001–T017: server-authorized contact eligibility, deterministic direct creation, and the department-first picker. It delivers private chat safely before inbox separation and live ordering refinements.
